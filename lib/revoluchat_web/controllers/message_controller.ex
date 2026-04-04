defmodule RevoluchatWeb.MessageController do
  use RevoluchatWeb, :controller

  alias Revoluchat.Chat

  action_fallback(RevoluchatWeb.FallbackController)

  # GET /api/v1/conversations/:conversation_id/messages
  def index(conn, %{"conversation_id" => conv_id} = params) do
    user_id = conn.assigns.current_user_id
    app_id = conn.assigns.current_app_id
    before_id = Map.get(params, "before_id")
    limit = min(Map.get(params, "limit", "50") |> String.to_integer(), 100)

    with {:ok, _conv} <- Chat.get_conversation_for_user(app_id, conv_id, user_id) do
      messages = Chat.list_messages(app_id, conv_id, limit: limit, before_id: before_id)

      # Fetch user details (senders) from local cache
      sender_ids = messages |> Enum.map(& &1.sender_id) |> Enum.uniq()
      users_data = Revoluchat.Accounts.list_registered_users_by_ids(app_id, sender_ids)
      users_map = Map.new(users_data, fn u -> {u.id, u} end)

      json(conn, %{
        messages: Enum.map(messages, &format_message(&1, users_map)),
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
      attrs = %{
        app_id: app_id,
        conversation_id: conv_id,
        sender_id: user_id,
        type: Map.get(params, "type", "text"),
        body: Map.get(params, "body"),
        attachment_id: Map.get(params, "attachment_id"),
        reply_to_id: Map.get(params, "reply_to_id"),
        client_id: Map.get(params, "client_id")
      }

      with {:ok, message} <- Chat.insert_message(attrs) do
        # Fetch sender info from local cache
        user = Revoluchat.Accounts.get_registered_user(app_id, message.sender_id)
        users_map = if(user, do: %{user.user_id => user}, else: %{})

        conn
        |> put_status(:created)
        |> json(%{message: format_message(message, users_map)})
      end
    end
  end

  # ─── Private ─────────────────────────────────────────────────────────────────

  defp format_message(m, users_map) do
    status =
      cond do
        not is_nil(m.read_at) -> "read"
        not is_nil(m.delivered_at) -> "delivered"
        true -> "sent"
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
      reply_to_id: m.reply_to_id,
      client_id: m.client_id,
      delivered_at: format_dt(m.delivered_at),
      read_at: format_dt(m.read_at),
      inserted_at: format_dt(m.inserted_at)
    }
  end

  defp format_user(nil), do: nil

  defp format_user(user) do
    %{
      id: (user && (Map.get(user, :user_id) || Map.get(user, :id))) || nil,
      name: (user && (Map.get(user, :name) || "Unknown")) || "Unknown",
      phone: (user && Map.get(user, :phone)),
      avatar_url: (user && Map.get(user, :avatar_url))
    }
  end

  defp format_dt(nil), do: nil
  defp format_dt(dt), do: DateTime.to_iso8601(dt)
end
