defmodule RevoluchatWeb.MessageController do
  use RevoluchatWeb, :controller

  alias Revoluchat.Chat

  action_fallback(RevoluchatWeb.FallbackController)

  # GET /api/v1/conversations/:conversation_id/messages
  def index(conn, %{"conversation_id" => conv_id} = params) do
    user_id = conn.assigns.current_user_id
    app_id = conn.assigns.current_app_id
    before_id = Map.get(params, "before_id")
    search = Map.get(params, "search")
    limit = min(Map.get(params, "limit", "50") |> String.to_integer(), 100)

    with {:ok, _conv} <- Chat.get_conversation_for_user(app_id, conv_id, user_id) do
      messages =
        Chat.list_messages(app_id, conv_id, limit: limit, before_id: before_id, search: search)

      # Fetch user details (senders) from local cache
      sender_ids = messages |> Enum.map(& &1.sender_id) |> Enum.uniq()
      users_data = Revoluchat.Accounts.list_registered_users_by_ids(app_id, sender_ids)
      users_map = Map.new(users_data, fn u -> {u.id, u} end)

      # Bulk fetch attachments to avoid N+1
      import Ecto.Query

      all_attachment_ids =
        messages
        |> Enum.flat_map(&(&1.attachment_ids || []))
        |> Enum.concat(Enum.map(messages, & &1.attachment_id))
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      attachments_map =
        if all_attachment_ids != [] do
          from(a in Chat.Attachment, where: a.id in ^all_attachment_ids)
          |> Revoluchat.Repo.all()
          |> Map.new(fn a -> {a.id, a} end)
        else
          %{}
        end

      # Bulk fetch reply_to messages to include nested object (avoids N+1)
      reply_to_ids =
        messages
        |> Enum.map(& &1.reply_to_id)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      reply_messages_map =
        if reply_to_ids != [] do
          from(msg in Chat.Message,
            where: msg.id in ^reply_to_ids,
            preload: [:attachment]
          )
          |> Revoluchat.Repo.all()
          |> Map.new(fn msg -> {msg.id, msg} end)
        else
          %{}
        end

      json(conn, %{
        messages:
          Enum.map(messages, fn m ->
            m_atts =
              (m.attachment_ids || [])
              |> Enum.map(&Map.get(attachments_map, &1))
              |> Enum.concat([Map.get(attachments_map, m.attachment_id)])
              |> Enum.reject(&is_nil/1)
              |> Enum.uniq_by(& &1.id)

            format_message(m, users_map, m_atts, reply_messages_map)
          end),
        has_more: length(messages) == limit,
        next_cursor: List.last(messages) && List.last(messages).id
      })
    end
  end

  # POST /api/v1/conversations/:conversation_id/messages
  # (HTTP fallback — primary path via WebSocket)
  def create(conn, %{"conversation_id" => conv_id} = params) do
    user_id = conn.assigns.current_user_id
    app_id = conn.assigns.current_app_id

    with {:ok, _conv} <- Chat.get_conversation_for_user(app_id, conv_id, user_id) do
      # Support both Singular and Plural attachment keys
      attachment_ids =
        (Map.get(params, "attachment_ids") || [])
        |> List.wrap()

      attachment_id =
        Map.get(params, "attachment_id") || List.first(attachment_ids)

      attrs = %{
        app_id: app_id,
        conversation_id: conv_id,
        sender_id: user_id,
        type: Map.get(params, "type", if(attachment_id, do: "attachment", else: "text")),
        body: Map.get(params, "body"),
        attachment_id: attachment_id,
        attachment_ids: attachment_ids,
        reply_to_id: Map.get(params, "reply_to_id"),
        client_id: Map.get(params, "client_id")
      }

      with {:ok, message, attachments} <- Chat.insert_message(attrs) do
        # Fetch sender info from local cache
        user = Revoluchat.Accounts.get_registered_user(app_id, message.sender_id)
        users_map = if(user, do: %{user.user_id => user}, else: %{})

        conn
        |> put_status(:created)
        |> json(%{message: format_message(message, users_map, attachments)})
      end
    end
  end

  # ─── Private ─────────────────────────────────────────────────────────────────

  defp format_message(m, users_map, attachments \\ nil, reply_messages_map \\ %{}) do
    status =
      cond do
        not is_nil(m.read_at) -> "read"
        not is_nil(m.delivered_at) -> "delivered"
        true -> "sent"
      end

    import Ecto.Query

    # Fetch all attachments from attachment_ids if preloaded didn't happen
    attachments_list =
      cond do
        is_list(attachments) ->
          attachments

        Ecto.assoc_loaded?(m.attachment) and not is_nil(m.attachment) ->
          [m.attachment]

        is_list(m.attachment_ids) and m.attachment_ids != [] ->
          Revoluchat.Repo.all(
            from(a in Revoluchat.Chat.Attachment, where: a.id in ^m.attachment_ids)
          )

        true ->
          []
      end

    # Build nested reply_to object if available
    reply_to =
      case Map.get(reply_messages_map, m.reply_to_id) do
        nil -> nil
        ref_msg ->
          ref_user = Map.get(users_map, ref_msg.sender_id)
          %{
            id: ref_msg.id,
            body: ref_msg.body,
            type: ref_msg.type,
            user: format_user(ref_user),
            inserted_at: format_dt(ref_msg.inserted_at)
          }
      end

    %{
      id: m.id,
      type: m.type,
      body: m.body,
      status: status,
      sender_id: m.sender_id,
      user: Map.get(users_map, m.sender_id) |> format_user(),
      conversation_id: m.conversation_id,
      attachment_id: m.attachment_id,
      attachment: attachments_list |> List.first() |> format_attachment(),
      attachments: Enum.map(attachments_list, &format_attachment/1),
      reply_to_id: m.reply_to_id,
      reply_to: reply_to,
      client_id: m.client_id,
      delivered_at: format_dt(m.delivered_at),
      read_at: format_dt(m.read_at),
      updated_at: format_dt(m.updated_at),
      deleted_at: format_dt(m.deleted_at),
      inserted_at: format_dt(m.inserted_at)
    }
  end

  defp format_attachment(%Ecto.Association.NotLoaded{}), do: nil
  defp format_attachment(nil), do: nil

  defp format_attachment(att) do
    url =
      case Revoluchat.Storage.presigned_get_url(att.storage_key) do
        {:ok, url} -> url
        _ -> nil
      end

    %{
      id: att.id,
      url: url,
      mime_type: att.mime_type,
      size: att.size,
      metadata: att.metadata
    }
  end

  defp format_user(nil), do: nil

  defp format_user(user) do
    %{
      id: (user && (Map.get(user, :user_id) || Map.get(user, :id))) || nil,
      name: (user && (Map.get(user, :name) || "Unknown")) || "Unknown",
      phone: user && Map.get(user, :phone),
      avatar_url: user && Map.get(user, :avatar_url)
    }
  end

  defp format_dt(nil), do: nil
  defp format_dt(dt), do: DateTime.to_iso8601(dt)
end
