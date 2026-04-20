defmodule RevoluchatWeb.ChatChannel do
  use Phoenix.Channel

  alias Revoluchat.{Chat, Calls, Accounts, Repo}
  alias RevoluchatWeb.{Presence, Plugs.RateLimiter}
  import Ecto.Query

  require Logger

  # ─── JOIN ───────────────────────────────────────────────────────────────────

  @impl true
  def join(topic, _params, socket) do
    Logger.info("ChatChannel: ENTRY join/3 topic=#{topic}")
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id

    Logger.info("ChatChannel: START join topic=#{topic} user_id=#{user_id} app_id=#{app_id}")

    try do
      case String.split(topic, ":") do
        ["tenant", topic_app_id, "room", conversation_id] ->
          if topic_app_id != app_id do
            Logger.warning(
              "ChatChannel: Tenant mismatch. Socket app_id=#{app_id}, Topic app_id=#{topic_app_id}"
            )

            {:error, %{reason: "tenant_mismatch"}}
          else
            case Chat.get_conversation_for_user(app_id, conversation_id, user_id) do
              {:ok, _conversation} ->
                socket = assign(socket, :conversation_id, conversation_id)

                # Fetch 50 messages history
                messages = Chat.list_messages(app_id, conversation_id, limit: 50)

                # Fetch user details for history from local DB (Cache)
                sender_ids = Enum.map(messages, & &1.sender_id) |> Enum.uniq()
                users_data = Revoluchat.Accounts.list_registered_users_by_ids(app_id, sender_ids)
                users_map = Map.new(users_data, fn u -> {u.id, u} end)

                # Bulk fetch all attachments to avoid N+1
                all_attachment_ids =
                  messages
                  |> Enum.flat_map(&(&1.attachment_ids || []))
                  |> Enum.concat(Enum.map(messages, & &1.attachment_id))
                  |> Enum.reject(&is_nil/1)
                  |> Enum.uniq()

                attachments_map =
                  if all_attachment_ids != [] do
                    Chat.Attachment
                    |> where([a], a.id in ^all_attachment_ids)
                    |> Repo.all()
                    |> Map.new(fn a -> {a.id, a} end)
                  else
                    %{}
                  end

                # Schedule presence tracking
                send(self(), :after_join)

                Logger.info(
                  "ChatChannel: User #{user_id} successfully joined room #{conversation_id}"
                )

                reply = %{
                  messages:
                    Enum.map(messages, fn m ->
                      # Extract attachments for this specific message from the map
                      m_atts =
                        (m.attachment_ids || [])
                        |> Enum.map(&Map.get(attachments_map, &1))
                        |> Enum.concat([Map.get(attachments_map, m.attachment_id)])
                        |> Enum.reject(&is_nil/1)
                        |> Enum.uniq_by(& &1.id)

                      format_message_with_user(m, users_map, m_atts)
                    end)
                }

                {:ok, reply, socket}

              {:error, :not_found} ->
                Logger.warning(
                  "ChatChannel: User #{user_id} unauthorized for room #{conversation_id}"
                )

                {:error, %{reason: "unauthorized"}}
            end
          end

        _ ->
          Logger.warning("ChatChannel: Invalid topic format: #{topic}")
          {:error, %{reason: "invalid_topic_format"}}
      end
    rescue
      e ->
        Logger.error(
          "ChatChannel: CRASH during join/3 for User #{user_id} on topic #{topic}. Error: #{inspect(e)}"
        )

        {:error, %{reason: "internal_server_error"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    user_id = socket.assigns.user_id

    case Presence.track(socket, user_id, %{
           online_at: DateTime.utc_now() |> DateTime.to_iso8601(),
           typing: false
         }) do
      {:ok, _} ->
        Logger.info("ChatChannel: Presence tracked for User #{user_id}")
        push(socket, "presence_state", Presence.list(socket))

      {:error, reason} ->
        Logger.error(
          "ChatChannel: Failed to track presence for User #{user_id}: #{inspect(reason)}"
        )
    end

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
      user_id = socket.assigns.user_id

      Presence.update(socket, user_id, fn meta ->
        Map.put(meta, :typing, true)
      end)

      broadcast_from!(socket, "user_typing", %{
        user_id: user_id,
        typing: true
      })

      {:noreply, socket}
    end)
  end

  @impl true
  def handle_in("typing_stop", _payload, socket) do
    if_authorized(socket, fn ->
      user_id = socket.assigns.user_id

      Presence.update(socket, user_id, fn meta ->
        Map.put(meta, :typing, false)
      end)

      broadcast_from!(socket, "user_typing", %{
        user_id: user_id,
        typing: false
      })

      {:noreply, socket}
    end)
  end

  @impl true
  def handle_in("mark_read", %{"message_id" => message_id}, socket) do
    if_authorized(socket, fn ->
      user_id = socket.assigns.user_id
      app_id = socket.assigns.app_id

      case Chat.mark_read(app_id, message_id, user_id) do
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

  @impl true
  def handle_in("delete_message", %{"message_id" => message_id}, socket) do
    if_authorized(socket, fn ->
      user_id = socket.assigns.user_id
      app_id = socket.assigns.app_id

      Logger.info("ChatChannel: User #{user_id} requesting delete for message #{message_id}")

      case Chat.soft_delete_message(app_id, message_id, user_id) do
        {:ok, message} ->
          Logger.info("ChatChannel: Message #{message_id} soft deleted successfully")
          broadcast!(socket, "message_deleted", %{
            message_id: message_id,
            deleted_at: DateTime.to_iso8601(message.deleted_at)
          })

          {:reply, :ok, socket}

        {:error, :unauthorized} ->
          Logger.warning("ChatChannel: Unauthorized delete attempt by User #{user_id} for message #{message_id}")
          {:reply, {:error, %{reason: "unauthorized"}}, socket}

        {:error, reason} ->
          Logger.error("ChatChannel: Failed to delete message #{message_id}. Reason: #{inspect(reason)}")
          {:reply, {:error, %{reason: "not_found"}}, socket}
      end
    end)
  end

  @impl true
  def handle_in("delete_messages", %{"message_ids" => message_ids}, socket) do
    if_authorized(socket, fn ->
      user_id = socket.assigns.user_id
      app_id = socket.assigns.app_id

      Logger.info("ChatChannel: User #{user_id} requesting bulk delete for #{length(message_ids)} messages")

      case Chat.soft_delete_messages(app_id, message_ids, user_id) do
        {:ok, count} ->
          Logger.info("ChatChannel: #{count} messages soft deleted successfully")

          # Broadcast the deletion to all participants
          broadcast!(socket, "messages_deleted", %{
            message_ids: message_ids,
            deleted_at: DateTime.utc_now() |> DateTime.to_iso8601()
          })

          {:reply, :ok, socket}

        {:error, reason} ->
          Logger.error("ChatChannel: Bulk delete failed: #{inspect(reason)}")
          {:reply, {:error, %{reason: "delete_failed"}}, socket}
      end
    end)
  end

  # ─── CALL SIGNALING (WebRTC) ────────────────────────────────────────────────

  @impl true
  def handle_in("call:request", %{"type" => call_type, "receiver_id" => receiver_id}, socket) do
    if_authorized(socket, fn ->
      user_id = socket.assigns.user_id
      app_id = socket.assigns.app_id
      conversation_id = socket.assigns.conversation_id

      # Enforce integer ID for safety
      receiver_id =
        if is_binary(receiver_id), do: String.to_integer(receiver_id), else: receiver_id

      # Security: Verify membership via get_conversation_for_user
      case Chat.get_conversation_for_user(app_id, conversation_id, user_id) do
        {:ok, conversation} ->
          is_valid_receiver =
            receiver_id == conversation.user_a_id || receiver_id == conversation.user_b_id

          if not is_valid_receiver do
            Logger.warning(
              "User #{user_id} attempted to call non-member #{receiver_id} in conversation #{conversation_id}"
            )

            {:reply, {:error, %{reason: "invalid_receiver"}}, socket}
          else
            case Calls.initiate_call(app_id, conversation_id, user_id, receiver_id, call_type) do
              {:ok, call, caller_identity} ->
                caller_display_name =
                  if is_nil(caller_identity.name) or caller_identity.name == "",
                    do: caller_identity.phone,
                    else: caller_identity.name

                # Payload enrichment: Foto, Nama, No HP
                payload = %{
                  "call_id" => call.id,
                  "type" => call_type,
                  "caller_id" => user_id,
                  "caller_name" => caller_display_name,
                  "caller_photo" => caller_identity.photo,
                  "phone_number" => caller_identity.phone,
                  "conversation_id" => conversation_id
                }

                # 1. Broadcast to participants within the room (existing)
                broadcast_from!(socket, "call:incoming", payload)

                # 2. Broadcast to receiver specifically via their private user topic
                # This is CRUCIAL for global signaling (receiving calls outside the room)
                RevoluchatWeb.Endpoint.broadcast("user:#{receiver_id}", "call:incoming", payload)

                # --- Background Push Notification if offline ---
                topic_name = "tenant:#{app_id}:room:#{conversation_id}"
                presence_list = Presence.list(topic_name)

                # Check for receiver (integer or string key)
                is_receiver_online =
                  Map.has_key?(presence_list, receiver_id) ||
                    Map.has_key?(presence_list, to_string(receiver_id))

                if not is_receiver_online do
                  Logger.info("ChatChannel: User #{receiver_id} offline. Sending Call VoIP Push.")

                  %{
                    "app_id" => app_id,
                    "user_id" => receiver_id,
                    "call" => payload
                  }
                  |> Revoluchat.Workers.FcmPushWorker.new()
                  |> Oban.insert()
                end

                {:reply, {:ok, %{call_id: call.id}}, socket}

              {:error, reason} ->
                Logger.error("Failed to initiate call: #{inspect(reason)}")
                {:reply, {:error, %{reason: "failed_to_initiate"}}, socket}
            end
          end

        {:error, :not_found} ->
          {:reply, {:error, %{reason: "unauthorized"}}, socket}
      end
    end)
  end

  @impl true
  def handle_in("call:ringing", %{"call_id" => call_id}, socket) do
    with_call_auth(socket, call_id, fn ->
      Calls.set_ringing(call_id)
      broadcast_from!(socket, "call:ringing", %{call_id: call_id})
      {:reply, :ok, socket}
    end)
  end

  @impl true
  def handle_in("call:respond", %{"call_id" => call_id, "response" => action}, socket) do
    with_call_auth(socket, call_id, fn ->
      case action do
        "accept" ->
          case Calls.accept_call(call_id) do
            {:ok, call} ->
              app_id = socket.assigns.app_id
              # Fetch identities from local cache safely
              caller = Accounts.get_registered_user(app_id, call.caller_id)
              receiver = Accounts.get_registered_user(app_id, call.receiver_id)

              caller_display_name =
                if(caller && caller.name && caller.name != "",
                  do: caller.name,
                  else: (caller && caller.phone) || "User"
                )

              receiver_display_name =
                if(receiver && receiver.name && receiver.name != "",
                  do: receiver.name,
                  else: (receiver && receiver.phone) || "User"
                )

              # Generate LiveKit Tokens
              livekit_url = Application.get_env(:revoluchat, :livekit)[:url] || System.get_env("LIVEKIT_URL") || "ws://localhost:7880"
              {:ok, caller_token} = Revoluchat.LiveKit.Token.generate(call_id, call.caller_id, caller_display_name)
              {:ok, receiver_token} = Revoluchat.LiveKit.Token.generate(call_id, call.receiver_id, receiver_display_name)

              payload = %{
                "call_id" => call_id,
                "status" => "connected",
                "caller_id" => call.caller_id,
                "caller_name" => caller_display_name,
                "receiver_id" => call.receiver_id,
                "receiver_name" => receiver_display_name,
                "livekit_url" => livekit_url,
                "livekit_token_caller" => caller_token,
                "livekit_token_receiver" => receiver_token
              }

              # 1. Broadast to Room (for everyone in conversation)
              _payload_with_event = Map.put(payload, "event", "call:accepted")
              broadcast!(socket, "call:accepted", payload)

              # 2. Force broadcast to Caller's Private Channel (for global UI update)
              caller_topic = "user:#{call.caller_id}"

              Logger.info(
                "ChatChannel: Force broadcasting call:accepted to caller at #{caller_topic}"
              )

              RevoluchatWeb.Endpoint.broadcast!(caller_topic, "call:accepted", payload)

              # 3. Force broadcast to Receiver's Private Channel (for consistency)
              receiver_topic = "user:#{call.receiver_id}"
              RevoluchatWeb.Endpoint.broadcast!(receiver_topic, "call:accepted", payload)

              {:reply, :ok, socket}

            {:error, :invalid_status} ->
              {:reply, {:error, %{reason: "invalid_state"}}, socket}

            error ->
              Logger.error("ChatChannel: Failed to accept call #{call_id}: #{inspect(error)}")
              {:reply, {:error, %{reason: "failed"}}, socket}
          end

        "reject" ->
          case Calls.reject_call(call_id) do
            {:ok, call} ->
              payload = %{
                "call_id" => call_id,
                "caller_id" => call.caller_id,
                "receiver_id" => call.receiver_id
              }

              # 1. Broadcast to Room
              broadcast_from!(socket, "call:rejected", payload)

              # 2. Force broadcast to Caller's Private Channel (for UI updates)
              target_topic = "user:#{call.caller_id}"
              Logger.info("ChatChannel: Broadcasting call:rejected to #{target_topic}")
              RevoluchatWeb.Endpoint.broadcast!(target_topic, "call:rejected", payload)

              # Emit summary message for rejected call
              insert_call_summary(call, socket)

              {:reply, :ok, socket}

            _ ->
              {:reply, {:error, %{reason: "failed"}}, socket}
          end
      end
    end)
  end


  @impl true
  def handle_in("call:hangup", %{"call_id" => call_id} = params, socket) do
    # Duration is no longer passed to complete_call
    _duration = Map.get(params, "duration", 0)

    with_call_auth(socket, call_id, fn ->
      case Calls.complete_call(call_id) do
        {:ok, call} ->
          # 1. Broadcast to Room
          broadcast_from!(socket, "call:hangup", %{call_id: call_id})

          # 2. Force broadcast to both caller and receiver private channels
          RevoluchatWeb.Endpoint.broadcast!("user:#{call.caller_id}", "call:hangup", %{
            "call_id" => call_id
          })

          RevoluchatWeb.Endpoint.broadcast!("user:#{call.receiver_id}", "call:hangup", %{
            "call_id" => call_id
          })

          # Emit summary message for completed call
          insert_call_summary(call, socket)

          {:reply, :ok, socket}

        _ ->
          {:reply, :ok, socket}
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

    # Extract attachment_ids as a list
    attachment_ids =
      (Map.get(payload, "attachment_ids") || [])
      |> List.wrap()
      |> Enum.reject(&is_nil/1)

    # Legacy support: if singular id provided but plural empty
    attachment_ids =
      if attachment_ids == [] and Map.has_key?(payload, "attachment_id") do
        [Map.get(payload, "attachment_id")]
      else
        attachment_ids
      end

    attachment_id = List.first(attachment_ids)

    # Auto-detect type if not provided but attachment exists
    type = Map.get(payload, "type")
    type = if is_nil(type) && attachment_ids != [], do: "attachment", else: type || "text"

    attrs = %{
      app_id: app_id,
      conversation_id: conversation_id,
      sender_id: user_id,
      type: type,
      body: Map.get(payload, "body"),
      is_encrypted: Map.get(payload, "is_encrypted", false),
      attachment_id: attachment_id,
      attachment_ids: attachment_ids,
      reply_to_id: Map.get(payload, "reply_to_id"),
      client_id: Map.get(payload, "client_id")
    }

    Logger.debug("ChatChannel: Processing new message with attrs: #{inspect(attrs)}")

    Logger.info("ChatChannel: Processing new_message payload: #{inspect(payload)}")

    case Chat.insert_message(attrs) do
      {:ok, message, attachments} ->
        Logger.info("ChatChannel: Successfully inserted message #{message.id}")
        Logger.debug("ChatChannel: Message inserted. Attachments count: #{length(attachments)}")
        # Fetch sender info for broadcast from local DB (cache)
        user = Revoluchat.Accounts.get_registered_user(app_id, message.sender_id)

        formatted_message =
          message
          |> format_message(attachments)
          |> Map.put(:user, %{
            id: if(user, do: user.user_id, else: message.sender_id),
            name: (user && user.name) || "Unknown",
            phone: if(user, do: user.phone, else: nil),
            avatar_url: if(user, do: user.avatar_url, else: nil)
          })

        # Broadcast ke semua (termasuk sender untuk konfirmasi visual real-time)
        broadcast!(socket, "new_message", formatted_message)

        # 3. Broadcast conversation_updated to user topics for real-time list updates
        # Fetch conversation to get participants
        {:ok, conversation} = Chat.get_conversation_for_user(app_id, conversation_id, user_id)

        update_payload = %{
          conversation_id: conversation_id,
          last_message: formatted_message,
          # Increment for receiver
          unread_count_update: 1
        }

        # Broadcast to user_a and user_b (this covers both sender and receiver in direct chat)
        RevoluchatWeb.Endpoint.broadcast(
          "user:#{conversation.user_a_id}",
          "conversation_updated",
          update_payload
        )

        RevoluchatWeb.Endpoint.broadcast(
          "user:#{conversation.user_b_id}",
          "conversation_updated",
          update_payload
        )

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

        # Better: just fetch conversation ONCE and use it
        case Chat.get_conversation_for_user(app_id, conversation_id, user_id) do
          {:ok, conversation} ->
            receiver_id =
              if message.sender_id == conversation.user_a_id,
                do: conversation.user_b_id,
                else: conversation.user_a_id

            # Cek apakah receiver sedang aktif di topic ini via Tracker
            topic_name = "tenant:#{app_id}:room:#{conversation_id}"
            presence_list = Presence.list(topic_name)

            # Keys in Presence.list are strings, so we check both integer and string
            is_receiver_online =
              Map.has_key?(presence_list, receiver_id) ||
                Map.has_key?(presence_list, to_string(receiver_id))

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

          {:error, _} ->
            Logger.warning(
              "ChatChannel: Could not find conversation #{conversation_id} for push logic. app_id: #{app_id}"
            )
        end

        {:reply, {:ok, %{message_id: message.id}}, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_errors(changeset)
        {:reply, {:error, %{reason: "validation_failed", errors: errors}}, socket}
    end
  end

  defp format_message_with_user(message, users_map, attachments) do
    user = Map.get(users_map, message.sender_id)

    message
    |> format_message(attachments)
    |> Map.put(:user, %{
      id: if(user, do: user.id, else: message.sender_id),
      name: if(user, do: user.name, else: "Unknown"),
      phone: if(user, do: user.phone, else: nil),
      avatar_url: if(user, do: user.avatar_url, else: nil)
    })
  end

  defp format_message(message, attachments) do
    status =
      cond do
        not is_nil(message.read_at) -> "read"
        not is_nil(message.delivered_at) -> "delivered"
        true -> "sent"
      end

    # If attachments list not provided, try to use singular or fetch plural
    attachments_list =
      cond do
        is_list(attachments) ->
          attachments

        not is_nil(message.attachment) ->
          [message.attachment]

        is_list(message.attachment_ids) and message.attachment_ids != [] ->
          # Fallback fetch (slow, but should be preloaded by caller)
          Revoluchat.Repo.all(
            from(a in Revoluchat.Chat.Attachment, where: a.id in ^message.attachment_ids)
          )

        true ->
          []
      end

    %{
      id: message.id,
      type: message.type,
      body: message.body,
      status: status,
      is_encrypted: message.is_encrypted,
      sender_id: message.sender_id,
      conversation_id: message.conversation_id,
      reply_to_id: message.reply_to_id,
      client_id: message.client_id,
      attachment: attachments_list |> List.first() |> format_attachment(),
      attachments: Enum.map(attachments_list, &format_attachment/1),
      delivered_at: format_dt(message.delivered_at),
      read_at: format_dt(message.read_at),
      deleted_at: format_dt(message.deleted_at),
      inserted_at: format_dt(message.inserted_at)
    }
  end

  defp format_attachment(%Ecto.Association.NotLoaded{}), do: nil
  defp format_attachment(nil), do: nil

  defp format_attachment(att) do
    # Use stable proxy URL instead of slow/fragile presigned URLs during broadcast.
    # The SDK knows how to prefix this with baseUrl and add Authorization headers.
    url = "/api/v1/attachments/#{att.id}/show"

    %{
      id: att.id,
      url: url,
      mime_type: att.mime_type,
      size: att.size,
      metadata: att.metadata
    }
  end

  defp with_call_auth(socket, call_id, callback) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id

    try do
      if Calls.is_participant?(app_id, call_id, user_id) do
        callback.()
      else
        Logger.warning("Unauthorized signaling attempt by User #{user_id} for Call #{call_id}")
        {:reply, {:error, %{reason: "unauthorized_signaling"}}, socket}
      end
    rescue
      e ->
        Logger.error("Signaling internal error for Call #{call_id}: #{inspect(e)}")
        {:reply, {:error, %{reason: "internal_error"}}, socket}
    end
  end

  defp insert_call_summary(call, socket) do
    payload = Calls.generate_summary_payload(call)

    case Chat.insert_message(payload) do
      {:ok, message, attachments} ->
        broadcast!(socket, "new_message", format_message(message, attachments))

      _ ->
        Logger.error("Failed to insert call summary message for Call #{call.id}")
    end
  end

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
