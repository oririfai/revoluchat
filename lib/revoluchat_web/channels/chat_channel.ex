defmodule RevoluchatWeb.ChatChannel do
  use Phoenix.Channel

  alias Revoluchat.Chat
  alias RevoluchatWeb.{Presence, Plugs.RateLimiter}

  require Logger

  # ─── JOIN ───────────────────────────────────────────────────────────────────

  @impl true
  def join(topic, _params, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id

    case String.split(topic, ":") do
      ["tenant", topic_app_id, "room", conversation_id] ->
        # Strictly enforce that the requested topic's tenant matches the socket's authenticated tenant
        if topic_app_id != app_id do
          {:error, %{reason: "tenant_mismatch"}}
        else
          # Verify membership — user harus peserta conversation
          case Chat.get_conversation_for_user(app_id, conversation_id, user_id) do
            {:ok, _conversation} ->
              socket = assign(socket, :conversation_id, conversation_id)

              # Kirim 50 pesan terakhir
              messages = Chat.list_messages(app_id, conversation_id, limit: 50)

              # Track presence setelah join sukses
              send(self(), :after_join)

              {:ok, %{messages: format_messages(messages)}, socket}

            {:error, :not_found} ->
              {:error, %{reason: "unauthorized"}}
          end
        end

      _ ->
        {:error, %{reason: "invalid_topic_format"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(socket, socket.assigns.user_id, %{
        online_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        typing: false
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  # ─── INBOUND EVENTS ──────────────────────────────────────────────────────────

  @impl true
  def handle_in("new_message", payload, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id
    conversation_id = socket.assigns.conversation_id

    # 1. Re-validate membership (defense against stale sockets/hijack)
    case Chat.get_conversation_for_user(app_id, conversation_id, user_id) do
      {:ok, _} ->
        # 2. Rate limiting check
        case RateLimiter.check_message_rate(user_id) do
          {:error, :rate_limited} ->
            {:reply, {:error, %{reason: "rate_limited", retry_after: 10}}, socket}

          :ok ->
            process_new_message(payload, conversation_id, user_id, socket)
        end

      {:error, :not_found} ->
        {:reply, {:error, %{reason: "unauthorized"}}, socket}
    end
  end

  @impl true
  def handle_in("typing_start", _payload, socket) do
    if_authorized(socket, fn ->
      Presence.update(socket, socket.assigns.user_id, fn meta ->
        Map.put(meta, :typing, true)
      end)

      {:noreply, socket}
    end)
  end

  @impl true
  def handle_in("typing_stop", _payload, socket) do
    if_authorized(socket, fn ->
      Presence.update(socket, socket.assigns.user_id, fn meta ->
        Map.put(meta, :typing, false)
      end)

      {:noreply, socket}
    end)
  end

  @impl true
  def handle_in("mark_read", %{"message_id" => message_id}, socket) do
    if_authorized(socket, fn ->
      user_id = socket.assigns.user_id

      case Chat.mark_read(message_id, user_id) do
        {:ok, message} ->
          broadcast!(socket, "message_read", %{
            message_id: message_id,
            read_by: user_id,
            read_at: DateTime.to_iso8601(message.read_at)
          })

          {:reply, :ok, socket}

        {:error, _} ->
          {:reply, {:error, %{reason: "not_found"}}, socket}
      end
    end)
  end

  # ─── PRIVATE HELPERS ─────────────────────────────────────────────────────────

  defp if_authorized(socket, callback) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id
    conversation_id = socket.assigns.conversation_id

    case Chat.get_conversation_for_user(app_id, conversation_id, user_id) do
      {:ok, _} -> callback.()
      {:error, :not_found} -> {:reply, {:error, %{reason: "unauthorized"}}, socket}
    end
  end

  defp process_new_message(payload, conversation_id, user_id, socket) do
    app_id = socket.assigns.app_id

    attrs = %{
      app_id: app_id,
      conversation_id: conversation_id,
      sender_id: user_id,
      type: Map.get(payload, "type", "text"),
      body: Map.get(payload, "body"),
      is_encrypted: Map.get(payload, "is_encrypted", false),
      attachment_id: Map.get(payload, "attachment_id"),
      reply_to_id: Map.get(payload, "reply_to_id"),
      client_id: Map.get(payload, "client_id")
    }

    case Chat.insert_message(attrs) do
      {:ok, message} ->
        formatted_message = format_message(message)

        # Broadcast ke semua (termasuk sender untuk konfirmasi visual real-time)
        broadcast!(socket, "new_message", formatted_message)

        # --- Observability: Track delivered messages & latency ---
        latency_ms = DateTime.diff(DateTime.utc_now(), message.inserted_at, :millisecond)

        :telemetry.execute(
          [:revoluchat, :messages, :delivered],
          %{count: 1},
          %{app_id: app_id}
        )

        :telemetry.execute(
          [:revoluchat, :messages, :latency],
          %{ms: latency_ms},
          %{app_id: app_id}
        )

        # Push Notification Logic (Smart Dispatching)
        conversation = Chat.get_conversation!(app_id, conversation_id)

        receiver_id =
          if message.sender_id == conversation.user_a_id,
            do: conversation.user_b_id,
            else: conversation.user_a_id

        # Cek apakah receiver sedang aktif di topic ini via Tracker
        topic_name = "tenant:#{app_id}:room:#{conversation_id}"
        is_receiver_online = Map.has_key?(Presence.list(topic_name), receiver_id)

        if not is_receiver_online do
          Logger.info(
            "ChatChannel: User #{receiver_id} offline in topic. Enqueueing FCM Push Worker."
          )

          %{
            "app_id" => app_id,
            "user_id" => receiver_id,
            "message" => formatted_message
          }
          |> Revoluchat.Workers.FcmPushWorker.new()
          |> Oban.insert()
        else
          Logger.debug(
            "ChatChannel: User #{receiver_id} is online via WebSocket. Skipping FCM Push."
          )
        end

        {:reply, {:ok, %{message_id: message.id}}, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_errors(changeset)
        {:reply, {:error, %{reason: "validation_failed", errors: errors}}, socket}
    end
  end

  defp format_messages(messages), do: Enum.map(messages, &format_message/1)

  defp format_message(message) do
    %{
      id: message.id,
      type: message.type,
      body: message.body,
      is_encrypted: message.is_encrypted,
      sender_id: message.sender_id,
      conversation_id: message.conversation_id,
      reply_to_id: message.reply_to_id,
      client_id: message.client_id,
      attachment: format_attachment(message.attachment),
      delivered_at: format_dt(message.delivered_at),
      read_at: format_dt(message.read_at),
      inserted_at: format_dt(message.inserted_at)
    }
  end

  defp format_attachment(nil), do: nil

  defp format_attachment(att) do
    %{
      id: url(att.id),
      mime_type: att.mime_type,
      size: att.size
    }
  end

  defp url(id), do: "/api/v1/attachments/#{id}"

  defp format_dt(nil), do: nil
  defp format_dt(dt), do: DateTime.to_iso8601(dt)

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
