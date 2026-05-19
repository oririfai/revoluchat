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
    archived = Map.get(params, "archived") == "true"
    
    require Logger
    Logger.info("[ConversationController] index - Archived: #{archived}, Params: #{inspect(params)}")

    conversations = Chat.list_user_conversations(app_id, user_id, search: search_term, archived: archived)

    # Fetch user details via gRPC
    user_ids =
      conversations
      |> Enum.flat_map(fn c -> [c.user_a_id, c.user_b_id] end)
      |> Enum.uniq()

    users_data = Revoluchat.Accounts.list_registered_users_by_ids(app_id, user_ids)
    users_map = Map.new(users_data, fn u -> {u.id, u} end)

    formatted_conversations = Enum.map(conversations, &format_conversation(&1, users_map, user_id, app_id))

    filtered_conversations =
      if search_term && search_term != "" do
        downcased_term = String.downcase(search_term)
        Enum.filter(formatted_conversations, fn c ->
          name =
            if c[:type] == "group" do
              c[:name]
            else
              other_user = if c[:user_a_id] == user_id, do: c[:user_b], else: c[:user_a]
              (other_user && other_user[:name]) || ""
            end
          String.contains?(String.downcase(name || ""), downcased_term)
        end)
      else
        formatted_conversations
      end

    json(conn, %{conversations: filtered_conversations})
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

      json(conn, %{conversation: format_conversation(conversation, users_map, user_id, app_id)})
    end
  end

  # DELETE /api/v1/conversations/:id
  def delete(conn, params) do
    user_id = conn.assigns.current_user_id
    app_id = conn.assigns.current_app_id

    ids =
      cond do
        is_list(params["ids"]) -> params["ids"]
        is_binary(params["ids"]) and params["ids"] != "" -> String.split(params["ids"], ",")
        params["id"] -> [params["id"]]
        true -> []
      end

    if Enum.empty?(ids) do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "No conversation IDs provided"})
    else
      with :ok <- Chat.delete_conversation(app_id, ids, user_id) do
        json(conn, %{success: true, message: "Conversations deleted"})
      end
    end
  end

  # POST /api/v1/conversations/archive
  def archive(conn, params) do
    user_id = conn.assigns.current_user_id
    app_id = conn.assigns.current_app_id

    ids =
      cond do
        is_list(params["ids"]) -> params["ids"]
        is_binary(params["ids"]) and params["ids"] != "" -> String.split(params["ids"], ",")
        params["id"] -> [params["id"]]
        true -> []
      end

    if Enum.empty?(ids) do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "No conversation IDs provided"})
    else
      with :ok <- Chat.archive_conversation(app_id, ids, user_id) do
        json(conn, %{success: true, message: "Conversations archived"})
      end
    end
  end

  # POST /api/v1/conversations/unarchive
  def unarchive(conn, params) do
    user_id = conn.assigns.current_user_id
    app_id = conn.assigns.current_app_id

    ids =
      cond do
        is_list(params["ids"]) -> params["ids"]
        is_binary(params["ids"]) and params["ids"] != "" -> String.split(params["ids"], ",")
        params["id"] -> [params["id"]]
        true -> []
      end

    if Enum.empty?(ids) do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "No conversation IDs provided"})
    else
      with :ok <- Chat.unarchive_conversation(app_id, ids, user_id) do
        json(conn, %{success: true, message: "Conversations unarchived"})
      end
    end
  end

  # POST /api/v1/conversations
  def create(conn, %{"user_id" => other_user_id}) do
    user_id = conn.assigns.current_user_id
    app_id = conn.assigns.current_app_id

    # other_user_id should be a string (UUID)
    other_user_id = to_string(other_user_id)

    IO.inspect({app_id, user_id, other_user_id}, label: "ConversationController.create params")
    
    # We allow starting a chat if the target user is already a contact 
    # OR if they are a registered user (to support sync discovery)
    is_cont = Accounts.is_contact?(app_id, user_id, other_user_id)
    
    can_chat = 
      if is_cont do
        true
      else
        # If not a contact, check if registered in User Service
        case Accounts.get_user(other_user_id) do
          {:ok, _user} -> 
            # Auto-add to contact list for convenience
            Accounts.perform_add_contact(app_id, user_id, other_user_id)
            true
          _ -> false
        end
      end

    if can_chat do
      with {:ok, conversation} <- Chat.get_or_create_conversation(app_id, user_id, other_user_id) do
        # Fetch user details for the new/existing conversation
        user_ids = Enum.uniq([conversation.user_a_id, conversation.user_b_id])
        users_data = Accounts.list_registered_users_by_ids(app_id, user_ids)
        users_map = Map.new(users_data, fn u -> {u.id, u} end)

        conn
        |> put_status(:created)
        |> json(%{conversation: format_conversation(conversation, users_map, user_id, app_id)})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "forbidden", message: "User tidak ditemukan atau tidak terdaftar"})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "user_id wajib diisi"})
  end

  # ─── Private ─────────────────────────────────────────────────────────────────

  defp format_conversation(c, users_map, current_user_id, app_id) do
    # Handle missing timestamps in gRPC response
    inserted_at = Map.get(c, :inserted_at) || Map.get(c, :last_activity_at) || DateTime.utc_now()
    last_activity_at = Map.get(c, :last_activity_at) || inserted_at

    id = if (Map.get(c, :type) == "group" or not is_nil(Map.get(c, :group))) and not String.starts_with?(c.id, "group_"), do: "group_#{c.id}", else: c.id
    
    type = if (is_nil(Map.get(c, :type)) || Map.get(c, :type) == ""), do: "direct", else: c.type

    base = %{
      id: id,
      type: type,
      last_message: format_last_message(c.last_message),
      last_activity_at: last_activity_at,
      inserted_at: inserted_at,
      unread_count: Map.get(c, :unread_count) || 0,
      archived_at: Map.get(c, :archived_at)
    }

    if Map.get(c, :type) == "group" or not is_nil(Map.get(c, :group)) do
      group = c.group
      formatted_group = if group, do: RevoluchatWeb.GroupController.format_group(group, app_id, current_user_id), else: nil
      
      Map.merge(base, %{
        type: "group",
        name: (formatted_group && formatted_group.name) || (group && group.name) || "Grup Tanpa Nama",
        avatar_url: (formatted_group && formatted_group.avatar_url) || (group && group.avatar_url),
        group: formatted_group
      })
    else
      Map.merge(base, %{
        user_a_id: c.user_a_id,
        user_b_id: c.user_b_id,
        user_a: Map.get(users_map, c.user_a_id) |> format_user(),
        user_b: Map.get(users_map, c.user_b_id) |> format_user()
      })
    end
  end

  defp format_last_message(%Ecto.Association.NotLoaded{}), do: nil
  defp format_last_message(nil), do: nil

  defp format_last_message(m) do
    %{
      id: m.id,
      body: m.body,
      type: m.type,
      user_id: m.sender_id,
      sender_id: m.sender_id,
      deleted_at: m.deleted_at,
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
