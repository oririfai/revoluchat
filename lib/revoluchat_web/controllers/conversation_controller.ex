defmodule RevoluchatWeb.ConversationController do
  use RevoluchatWeb, :controller

  alias Revoluchat.Chat

  action_fallback RevoluchatWeb.FallbackController

  # GET /api/v1/conversations
  def index(conn, _params) do
    user_id = conn.assigns.current_user_id
    app_id = conn.assigns.current_app_id
    conversations = Chat.list_user_conversations(app_id, user_id)

    json(conn, %{conversations: Enum.map(conversations, &format_conversation/1)})
  end

  # GET /api/v1/conversations/:id
  def show(conn, %{"id" => id}) do
    user_id = conn.assigns.current_user_id
    app_id = conn.assigns.current_app_id

    with {:ok, conversation} <- Chat.get_conversation_for_user(app_id, id, user_id) do
      json(conn, %{conversation: format_conversation(conversation)})
    end
  end

  # POST /api/v1/conversations
  def create(conn, %{"user_id" => other_user_id}) do
    user_id = conn.assigns.current_user_id
    app_id = conn.assigns.current_app_id

    with {:ok, conversation} <- Chat.get_or_create_conversation(app_id, user_id, other_user_id) do
      conn
      |> put_status(:created)
      |> json(%{conversation: format_conversation(conversation)})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "user_id wajib diisi"})
  end

  # ─── Private ─────────────────────────────────────────────────────────────────

  defp format_conversation(c) do
    %{
      id: c.id,
      user_a_id: c.user_a_id,
      user_b_id: c.user_b_id,
      user_a: format_user(c.user_a),
      user_b: format_user(c.user_b),
      last_activity_at: c.last_activity_at,
      inserted_at: c.inserted_at
    }
  end

  defp format_user(nil), do: nil

  defp format_user(user) do
    %{
      id: user.id,
      name: user.name,
      phone: user.phone,
      uuid: user.uuid,
      status: user.status
    }
  end
end
