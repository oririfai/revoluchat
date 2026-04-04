defmodule RevoluchatWeb.ConversationController do
  use RevoluchatWeb, :controller

  alias Revoluchat.Chat
  alias Revoluchat.Accounts

  action_fallback(RevoluchatWeb.FallbackController)

  # GET /api/v1/conversations
  def index(conn, params) do
    user_id = conn.assigns.current_user_id
    app_id = conn.assigns.current_app_id
    search_term = Map.get(params, "search")

    conversations = Chat.list_user_conversations(app_id, user_id, search: search_term)

    # Fetch user details via gRPC
    user_ids =
      conversations
      |> Enum.flat_map(fn c -> [c.user_a_id, c.user_b_id] end)
      |> Enum.uniq()

    users_data = Revoluchat.Accounts.list_registered_users_by_ids(app_id, user_ids)
    users_map = Map.new(users_data, fn u -> {u.id, u} end)

    json(conn, %{conversations: Enum.map(conversations, &format_conversation(&1, users_map))})
  end

  # GET /api/v1/conversations/:id
  def show(conn, %{"id" => id}) do
    user_id = conn.assigns.current_user_id
    app_id = conn.assigns.current_app_id

    with {:ok, conversation} <- Chat.get_conversation_for_user(app_id, id, user_id) do
      # Fetch user details for this specific conversation
      user_ids = Enum.uniq([conversation.user_a_id, conversation.user_b_id])
      users_data = Revoluchat.Accounts.list_registered_users_by_ids(app_id, user_ids)
      users_map = Map.new(users_data, fn u -> {u.id, u} end)

      json(conn, %{conversation: format_conversation(conversation, users_map)})
    end
  end

  # POST /api/v1/conversations
  def create(conn, %{"user_id" => other_user_id}) do
    user_id = conn.assigns.current_user_id
    app_id = conn.assigns.current_app_id

    # other_user_id might be string from params
    other_user_id =
      if is_binary(other_user_id), do: String.to_integer(other_user_id), else: other_user_id

    IO.inspect({app_id, user_id, other_user_id}, label: "ConversationController.create params")
    is_cont = Accounts.is_contact?(app_id, user_id, other_user_id)
    IO.inspect(is_cont, label: "is_contact? result")

    with true <- is_cont || {:error, :not_a_contact},
         {:ok, conversation} <- Chat.get_or_create_conversation(app_id, user_id, other_user_id) do
      # Fetch user details for the new/existing conversation
      user_ids = Enum.uniq([conversation.user_a_id, conversation.user_b_id])
      users_data = Accounts.list_registered_users_by_ids(app_id, user_ids)
      users_map = Map.new(users_data, fn u -> {u.id, u} end)

      conn
      |> put_status(:created)
      |> json(%{conversation: format_conversation(conversation, users_map)})
    else
      {:error, :not_a_contact} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden", message: "Anda harus menambahkan user ini ke kontak sebelum memulai chat"})

      error ->
        error
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "user_id wajib diisi"})
  end

  # ─── Private ─────────────────────────────────────────────────────────────────

  defp format_conversation(c, users_map) do
    %{
      id: c.id,
      user_a_id: c.user_a_id,
      user_b_id: c.user_b_id,
      user_a: Map.get(users_map, c.user_a_id) |> format_user(),
      user_b: Map.get(users_map, c.user_b_id) |> format_user(),
      last_message: format_last_message(c.last_message),
      last_activity_at: c.last_activity_at,
      inserted_at: c.inserted_at,
      unread_count: c.unread_count
    }
  end

  defp format_last_message(%Ecto.Association.NotLoaded{}), do: nil
  defp format_last_message(nil), do: nil

  defp format_last_message(m) do
    %{
      id: m.id,
      body: m.body,
      type: m.type,
      inserted_at: m.inserted_at
    }
  end

  defp format_user(nil), do: nil

  defp format_user(user) do
    %{
      id: (user && user.id) || nil,
      name: (user && user.name) || "Unknown",
      phone: (user && user.phone),
      avatar_url: (user && user.avatar_url),
      chat_id: (user && Map.get(user, :chat_id))
    }
  end
end
