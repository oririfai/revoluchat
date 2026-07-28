defmodule RevoluchatWeb.GroupController do
  use RevoluchatWeb, :controller
  require Logger

  alias Revoluchat.Chat
  alias Revoluchat.Accounts

  action_fallback(RevoluchatWeb.FallbackController)

  # GET /api/v1/groups/:id
  def show(conn, %{"id" => id}) do
    app_id = conn.assigns.current_app_id
    with {:ok, group} <- Chat.get_group(app_id, id) do
      group = preload_group_last_message(group, app_id)
      json(conn, %{data: format_group(group, app_id, conn.assigns.current_user_id, %{}, conn.assigns.token, conn.assigns.api_key)})
    end
  end

  # POST /api/v1/groups
  def create(conn, params) do
    app_id = conn.assigns.current_app_id
    user_id = conn.assigns.current_user_id
    
    # Proactively sync members to Go backend synchronously to ensure they exist for group membership
    all_uuids = [user_id | (params["members"] || params["member_ids"] || [])]
    Enum.each(all_uuids, fn uuid -> 
      Revoluchat.Accounts.sync_user_profile_to_advance_tier_sync(app_id, uuid)
    end)

    params = params
    |> Map.put(:creator_id, user_id)
    |> Map.put(:member_ids, params["members"] || params["member_ids"] || [])
    |> Map.put(:name, params["name"])
    |> Map.put(:description, params["description"])
    
    with {:ok, created_group} <- Chat.create_group(app_id, params),
         {:ok, group} <- Chat.get_group(app_id, created_group.id) do
      
      group_preloaded = preload_group_last_message(group, app_id)

      # Notify all members about the new group
      Enum.each(group.members, fn member ->
        formatted_for_member = format_group(group_preloaded, app_id, member.user_id, %{}, conn.assigns.token, conn.assigns.api_key)
        RevoluchatWeb.Endpoint.broadcast("user:#{member.user_id}", "conversation_updated", %{
          conversation_id: "group_#{group.id}",
          type: "group",
          group: formatted_for_member
        })
      end)

      conn
      |> put_status(:created)
      |> json(%{data: format_group(group_preloaded, app_id, user_id, %{}, conn.assigns.token, conn.assigns.api_key)})
    end
  end

  # PUT /api/v1/groups/:id
  def update(conn, %{"id" => id} = params) do
    app_id = conn.assigns.current_app_id
    user_id = conn.assigns.current_user_id

    with {:ok, group} <- Chat.get_group(app_id, id) do
      if is_member?(group, user_id) do
        params = Map.put_new(params, "is_locked", Map.get(group, :is_locked, false))
        with {:ok, updated_group} <- Chat.update_group(app_id, id, params, user_id) do
          updated_group = preload_group_last_message(updated_group, app_id)
          json(conn, %{data: format_group(updated_group, app_id, user_id, %{}, conn.assigns.token, conn.assigns.api_key)})
        end
      else
        conn |> put_status(:forbidden) |> json(%{error: "forbidden", message: "You are not a member of this group"})
      end
    end
  end

  # POST /api/v1/groups/:id/members
  def add_members(conn, %{"id" => id, "user_ids" => user_ids}) do
    app_id = conn.assigns.current_app_id
    user_id = conn.assigns.current_user_id

    with {:ok, group} <- Chat.get_group(app_id, id) do
      if is_member?(group, user_id) do
        with :ok <- Chat.add_members(app_id, id, user_ids, "member", user_id) do
          json(conn, %{success: true})
        end
      else
        conn |> put_status(:forbidden) |> json(%{error: "forbidden", message: "You are not authorized to add members to this group"})
      end
    end
  end

  # DELETE /api/v1/groups/:id/members/:user_id
  def remove_member(conn, %{"id" => id, "user_id" => target_user_id}) do
    app_id = conn.assigns.current_app_id
    user_id = conn.assigns.current_user_id

    with {:ok, group} <- Chat.get_group(app_id, id) do
      # Allow if user is group creator OR user is removing themselves OR user is an admin member
      if to_string(group.creator_id) == to_string(user_id) or to_string(target_user_id) == to_string(user_id) or is_admin_member?(group, user_id) do
        with :ok <- Chat.remove_member(app_id, id, target_user_id, user_id) do
          json(conn, %{success: true})
        end
      else
        conn |> put_status(:forbidden) |> json(%{error: "forbidden", message: "You are not authorized to remove this member"})
      end
    end
  end

  # POST /api/v1/groups/:id/leave
  def leave(conn, %{"id" => id}) do
    app_id = conn.assigns.current_app_id
    user_id = conn.assigns.current_user_id
    with :ok <- Chat.leave_group(app_id, id, user_id) do
      json(conn, %{success: true})
    end
  end

  # POST /api/v1/groups/:id/mute
  def mute(conn, %{"id" => id, "mute" => mute}) do
    app_id = conn.assigns.current_app_id
    user_id = conn.assigns.current_user_id
    with :ok <- Chat.mute_group(app_id, id, user_id, mute) do
      json(conn, %{success: true})
    end
  end

  # POST /api/v1/groups/:id/accept
  def accept(conn, %{"id" => id}) do
    app_id = conn.assigns.current_app_id
    user_id = conn.assigns.current_user_id
    with :ok <- Chat.accept_group_invitation(app_id, id, user_id) do
      json(conn, %{success: true})
    end
  end

  # ─── Private ─────────────────────────────────────────────────────────────────

  defp preload_group_last_message(nil, _app_id), do: nil
  defp preload_group_last_message(group, app_id) do
    case Map.get(group, :last_message) do
      %{id: id} = lm when not is_nil(id) ->
        if Map.get(lm, :type) == "attachment" do
          case Chat.list_messages_by_ids(app_id, [id]) do
            [full_msg | _] -> %{group | last_message: full_msg}
            _ -> group
          end
        else
          group
        end
      _ ->
        group
    end
  end

  def format_group(group, app_id, current_user_id, attachments_map \\ %{}, token \\ nil, api_key \\ nil) do
    # Fetch member details for better FE display
    user_ids = Enum.map(group.members, & &1.user_id)
    users_data = Accounts.list_registered_users_by_ids(app_id, user_ids)
    users_map = Accounts.build_users_map(users_data)

    %{
      id: "group_#{group.id}",
      name: group.name,
      description: group.description,
      avatar_url: resolve_avatar_url(group.avatar_url, token, api_key),
      is_locked: group.is_locked,
      creator_id: group.creator_id,
      inserted_at: group.inserted_at,
      updated_at: group.updated_at,
      unread_count: group.unread_count,
      members: Enum.map(group.members || [], fn m ->
        user = Map.get(users_map, m.user_id)
        is_self = to_string(m.user_id) == to_string(current_user_id)

        target_privacy = (user && (Map.get(user, :privacy_settings) || Map.get(user, "privacy_settings"))) || %{}
        current_user = Map.get(users_map, to_string(current_user_id)) || Map.get(users_map, current_user_id)
        current_privacy = (current_user && (Map.get(current_user, :privacy_settings) || Map.get(current_user, "privacy_settings"))) || %{}

        target_photo = Map.get(target_privacy, "profile_photo") || Map.get(target_privacy, :profile_photo)
        current_photo = Map.get(current_privacy, "profile_photo") || Map.get(current_privacy, :profile_photo)

        target_photo_disabled = target_photo == 3
        current_photo_disabled = current_photo == 3

        hide_photo = not is_self and (target_photo_disabled or current_photo_disabled)
        member_avatar = if hide_photo, do: nil, else: (user && resolve_avatar_url(user.avatar_url, token, api_key))

        %{
          user_id: m.user_id,
          role: m.role,
          status: m.status,
          is_muted: m.is_muted,
          joined_at: m.joined_at,
          user: %{
            id: (user && user.id) || m.user_id,
            name: (user && user.name) || "Unknown",
            avatar_url: member_avatar
          }
        }
      end),
      last_message: format_last_message(Map.get(group, :last_message), attachments_map, app_id, token, api_key),
      my_status: (Enum.find_value(group.members || [], fn m -> 
        if to_string(m.user_id) == to_string(current_user_id) do
          m.status
        end
      end) || Map.get(group, :my_status))
    }
    |> tap(fn result -> 
      last_msg_inserted_at = if result[:last_message], do: result[:last_message].inserted_at, else: "N/A"
      Logger.debug("[GroupController] Formatted group #{group.id} for user #{current_user_id}. last_message: #{last_msg_inserted_at}")
    end)
  end

  defp format_last_message(%Ecto.Association.NotLoaded{}), do: nil
  defp format_last_message(%Ecto.Association.NotLoaded{}, _), do: nil
  defp format_last_message(%Ecto.Association.NotLoaded{}, _, _), do: nil
  defp format_last_message(%Ecto.Association.NotLoaded{}, _, _, _, _), do: nil
  defp format_last_message(nil), do: nil
  defp format_last_message(nil, _), do: nil
  defp format_last_message(nil, _, _), do: nil
  defp format_last_message(nil, _, _, _, _), do: nil

  defp format_last_message(m, attachments_map) do
    format_last_message(m, attachments_map, nil)
  end

  defp format_last_message(m, attachments_map, app_id, token \\ nil, api_key \\ nil) do
    app_id = app_id || Map.get(m, :app_id)
    # Get attachment IDs for this message
    attachment_ids = 
      (m.attachment_ids || [])
      |> Enum.concat([m.attachment_id])
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    attachments_list =
      cond do
        # 1. Plural virtual field (e.g. from gRPC / Advance Tier)
        is_list(Map.get(m, :attachments)) and Map.get(m, :attachments) != [] ->
          Map.get(m, :attachments)

        # 2. Singular Ecto association (e.g. from Postgres Tier preloads)
        not is_nil(Map.get(m, :attachment)) and not match?(%Ecto.Association.NotLoaded{}, Map.get(m, :attachment)) ->
          [Map.get(m, :attachment)]

        # 3. Use bulk-fetched map
        Enum.all?(attachment_ids, &Map.has_key?(attachments_map, &1)) ->
          Enum.map(attachment_ids, &Map.get(attachments_map, &1))

        # 4. Fallback to database query (passing app_id as fallback in case m.app_id is nil)
        attachment_ids != [] and app_id ->
          Chat.list_attachments_by_ids(app_id, attachment_ids)

        true ->
          []
      end

    formatted_attachments = Enum.map(attachments_list, &format_attachment(&1, token, api_key))
    first_attachment = List.first(formatted_attachments)

    %{
      id: m.id,
      body: m.body,
      type: m.type,
      sender_id: m.sender_id,
      inserted_at: m.inserted_at,
      attachment_id: m.attachment_id,
      attachment: first_attachment,
      attachments: formatted_attachments
    }
  end

  defp format_attachment(nil, _, _), do: nil
  defp format_attachment(att, token, api_key) do
    url = if token && api_key do
      "/api/a/v1/attachments/#{att.id}/show?token=#{token}&api_key=#{api_key}"
    else
      "/api/a/v1/attachments/#{att.id}/show"
    end

    type = 
      cond do
        String.starts_with?(att.mime_type || "", "image/") -> "image"
        String.starts_with?(att.mime_type || "", "video/") -> "video"
        String.starts_with?(att.mime_type || "", "audio/") -> "audio"
        true -> "file"
      end

    %{
      id: att.id,
      url: url,
      mime_type: att.mime_type,
      type: type,
      filename: Map.get(att.metadata || %{}, "filename") || "file",
      size: att.size,
      metadata: att.metadata
    }
  end

  defp resolve_avatar_url(nil, _, _), do: nil
  defp resolve_avatar_url("", _, _), do: nil
  defp resolve_avatar_url(url, token, api_key) do
    # If it's a UUID (36 chars with dashes), treat as attachment ID
    if String.match?(url, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i) do
      if to_string(Application.get_env(:revoluchat, :tier_type)) == "advance" do
        "/api/d/attachments/view/#{url}"
      else
        if token && api_key do
          "/api/a/v1/attachments/#{url}/show?token=#{token}&api_key=#{api_key}"
        else
          "/api/a/v1/attachments/#{url}/show"
        end
      end
    else
      url
    end
  end

  defp is_member?(group, user_id) do
    Enum.any?(group.members || [], fn m -> to_string(m.user_id) == to_string(user_id) end)
  end

  defp is_admin_member?(group, user_id) do
    Enum.any?(group.members || [], fn m ->
      to_string(m.user_id) == to_string(user_id) and Map.get(m, :role) in ["admin", "creator", "owner"]
    end)
  end
end
