defmodule Revoluchat.Grpc.ChatClient do
  @moduledoc """
  gRPC Client for Chat operations in Advance Tier.
  """
  require Logger
  alias Revoluchat.Grpc.Interceptors.AuthClient
  alias Revoluchat.V1.ConversationService.Stub, as: ConvStub
  alias Revoluchat.V1.MessageService.Stub, as: MsgStub
  alias Revoluchat.V1.GroupService.Stub, as: GroupStub
  alias Revoluchat.V1.AttachmentService.Stub, as: AttStub
  alias Revoluchat.V1.StatusService.Stub, as: StatusStub

  alias Revoluchat.V1.{
    CreateConversationRequest,
    ListConversationsRequest,
    InsertMessageRequest,
    ListMessagesRequest,
    MarkReadRequest,
    DeleteMessageRequest,
    BulkDeleteMessagesRequest,
    MarkDeliveredRequest,
    CreateGroupRequest,
    GetGroupRequest,
    AddMembersRequest,
    RemoveMemberRequest,
    UpdateGroupRequest,
    LeaveGroupRequest,
    DeleteGroupRequest,
    MuteGroupRequest,
    AcceptGroupInvitationRequest,
    RegisterAttachmentRequest,
    ListAttachmentsByIdsRequest,
    DeleteConversationRequest,
    ArchiveConversationRequest,
    UnarchiveConversationRequest,
    CreateStatusRequest,
    ListStatusesRequest,
    ViewStatusRequest,
    DeleteStatusRequest
  }

  defp endpoint, do: System.get_env("CHAT_SERVICE_GRPC_ENDPOINT", "localhost:50051")

  defp connect do
    target = endpoint()
    Logger.debug("[gRPC] Connecting to Chat Service at #{target}")

    case GRPC.Stub.connect(target) do
      {:ok, channel} ->
        {:ok, channel}

      {:error, reason} ->
        Logger.error("[gRPC] Failed to connect to Chat Service: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp metadata(user_id \\ nil, app_id \\ nil) do
    AuthClient.get_auth_metadata(user_id, app_id)
  end

  # ─── Conversations ────────────────────────────────────────────────────────────

  def get_or_create_conversation(app_id, user_a_id, user_b_id) do
    request = %CreateConversationRequest{
      app_id: app_id,
      user_a_id: ensure_string(user_a_id),
      user_b_id: ensure_string(user_b_id)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           ConvStub.create_conversation(channel, request, metadata: metadata(user_a_id, app_id)) do
      {:ok, response.conversation}
    else
      {:error, reason} ->
        Logger.error("[gRPC] ConversationService.create_conversation error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_conversation_for_user(app_id, conversation_id, user_id) do
    request = %Revoluchat.V1.GetConversationRequest{
      app_id: app_id,
      conversation_id: clean_id(conversation_id)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           ConvStub.get_conversation(channel, request, metadata: metadata(user_id, app_id)) do
      {:ok, response.conversation}
    else
      {:error, reason} ->
        Logger.error("[gRPC] ConversationService.get_conversation error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_conversation(app_id, conversation_id) do
    get_conversation_for_user(app_id, conversation_id, nil)
  end

  def list_user_conversations(app_id, user_id, opts \\ []) do
    request = %ListConversationsRequest{app_id: app_id, user_id: ensure_string(user_id)}

    Logger.debug(
      "[gRPC] list_user_conversations - AppID: #{app_id}, UserID: #{user_id}, Archived: #{opts[:archived]}"
    )

    with {:ok, channel} <- connect() do
      rpc_func =
        if opts[:archived],
          do: &ConvStub.list_archived_conversations/3,
          else: &ConvStub.list_conversations/3

      case rpc_func.(channel, request, metadata: metadata(user_id, app_id)) do
        {:ok, response} ->
          Logger.debug("[gRPC] Received #{length(response.conversations)} conversations")
          response.conversations

        {:error, reason} ->
          Logger.error("[gRPC] list_user_conversations failed: #{inspect(reason)}")
          []

        _ ->
          []
      end
    else
      _ -> []
    end
  end

  def delete_conversation(app_id, ids, user_id) do
    request = %DeleteConversationRequest{
      app_id: app_id,
      user_id: ensure_string(user_id),
      ids: List.wrap(ids)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           ConvStub.delete_conversation(channel, request, metadata: metadata(user_id, app_id)) do
      if response.success, do: :ok, else: {:error, response.message}
    else
      {:error, reason} ->
        Logger.error("[gRPC] ConversationService.delete_conversation error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def archive_conversation(app_id, ids, user_id) do
    request = %ArchiveConversationRequest{
      app_id: app_id,
      user_id: ensure_string(user_id),
      ids: List.wrap(ids)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           ConvStub.archive_conversation(channel, request, metadata: metadata(user_id, app_id)) do
      if response.success, do: :ok, else: {:error, response.message}
    else
      {:error, reason} ->
        Logger.error("[gRPC] ConversationService.archive_conversation error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def unarchive_conversation(app_id, ids, user_id) do
    request = %UnarchiveConversationRequest{
      app_id: app_id,
      user_id: ensure_string(user_id),
      ids: List.wrap(ids)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           ConvStub.unarchive_conversation(channel, request, metadata: metadata(user_id, app_id)) do
      if response.success, do: :ok, else: {:error, response.message}
    else
      {:error, reason} ->
        Logger.error(
          "[gRPC] ConversationService.unarchive_conversation error: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # ─── Messages ─────────────────────────────────────────────────────────────────

  def insert_message(attrs) do
    request = %InsertMessageRequest{
      app_id: attrs[:app_id],
      conversation_id: clean_id(attrs[:conversation_id]),
      sender_id: ensure_string(attrs[:sender_id]),
      body: attrs[:body],
      type: attrs[:type] || "text",
      client_id: attrs[:client_id],
      is_encrypted: attrs[:is_encrypted] || false,
      group_id: clean_id(attrs[:group_id]),
      attachment_id: attrs[:attachment_id],
      attachment_ids: attrs[:attachment_ids] || [],
      reply_to_id: attrs[:reply_to_id]
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           MsgStub.insert_message(channel, request,
             metadata: metadata(attrs[:sender_id], attrs[:app_id])
           ) do
      {:ok, response.message, response.message.attachments || []}
    else
      {:error, reason} ->
        Logger.error("[gRPC] MessageService.insert_message error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def mark_read(app_id, message_id, user_id) do
    request = %MarkReadRequest{
      app_id: app_id,
      message_id: message_id,
      user_id: ensure_string(user_id)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           MsgStub.mark_read(channel, request, metadata: metadata(user_id, app_id)) do
      {:ok, response.message}
    else
      {:error, reason} ->
        Logger.error("[gRPC] MessageService.mark_read error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def mark_delivered(app_id, message_id, user_id) do
    request = %MarkDeliveredRequest{
      app_id: app_id,
      message_id: message_id,
      user_id: ensure_string(user_id)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           MsgStub.mark_delivered(channel, request, metadata: metadata(user_id, app_id)) do
      {:ok, response.message}
    else
      {:error, reason} ->
        Logger.error("[gRPC] MessageService.mark_delivered error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def list_messages(app_id, conversation_id, user_id, opts) do
    request = %ListMessagesRequest{
      app_id: app_id,
      conversation_id: clean_id(conversation_id),
      group_id: clean_id(opts[:group_id]),
      limit: opts[:limit] || 50,
      before_id: opts[:before_id],
      search: opts[:search]
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           MsgStub.list_messages(channel, request, metadata: metadata(user_id, app_id)) do
      response.messages
    else
      _ -> []
    end
  end

  def soft_delete_message(app_id, message_id, user_id) do
    request = %DeleteMessageRequest{
      app_id: app_id,
      message_id: message_id,
      user_id: ensure_string(user_id)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           MsgStub.delete_message(channel, request, metadata: metadata(user_id, app_id)) do
      {:ok, response.message}
    else
      {:error, reason} ->
        Logger.error("[gRPC] MessageService.delete_message error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def soft_delete_messages(app_id, message_ids, user_id) do
    request = %BulkDeleteMessagesRequest{
      app_id: app_id,
      message_ids: message_ids,
      user_id: ensure_string(user_id)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           MsgStub.bulk_delete_messages(channel, request, metadata: metadata(user_id, app_id)) do
      {:ok, response.count}
    else
      {:error, reason} ->
        Logger.error("[gRPC] MessageService.bulk_delete_messages error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # --- GROUPS (ADVANCE TIER) ---

  def create_group(app_id, params) do
    creator_id = params[:creator_id]

    request = %CreateGroupRequest{
      app_id: app_id,
      name: params["name"] || params[:name],
      description: params["description"] || params[:description],
      avatar_url: params["avatar_url"] || params[:avatar_url],
      member_ids: Enum.map(params["member_ids"] || params[:member_ids] || [], &ensure_string/1),
      admin_ids: Enum.map(params["admin_ids"] || params[:admin_ids] || [], &ensure_string/1)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           GroupStub.create_group(channel, request, metadata: metadata(creator_id, app_id)) do
      {:ok, response.group}
    else
      {:error, reason} ->
        Logger.error("[gRPC] GroupService.create_group error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_group(app_id, group_id) do
    request = %GetGroupRequest{app_id: app_id, group_id: clean_id(group_id)}

    with {:ok, channel} <- connect(),
         {:ok, response} <- GroupStub.get_group(channel, request, metadata: metadata(nil, app_id)) do
      {:ok, response.group}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def add_members(app_id, group_id, user_ids, role) do
    request = %AddMembersRequest{
      app_id: app_id,
      group_id: clean_id(group_id),
      user_ids: Enum.map(user_ids, &ensure_string/1),
      role: role
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           GroupStub.add_members(channel, request, metadata: metadata(nil, app_id)) do
      if response.success, do: :ok, else: {:error, response.message}
    end
  end

  def remove_member(app_id, group_id, user_id) do
    request = %RemoveMemberRequest{
      app_id: app_id,
      group_id: clean_id(group_id),
      user_id: ensure_string(user_id)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           GroupStub.remove_member(channel, request, metadata: metadata(nil, app_id)) do
      if response.success, do: :ok, else: {:error, response.message}
    end
  end

  def update_group(app_id, group_id, params) do
    request = %UpdateGroupRequest{
      app_id: app_id,
      group_id: clean_id(group_id),
      name: params["name"] || params[:name],
      description: params["description"] || params[:description],
      avatar_url: params["avatar_url"] || params[:avatar_url],
      is_locked:
        if(is_nil(params["is_locked"]), do: params[:is_locked], else: params["is_locked"]) ||
          false
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           GroupStub.update_group(channel, request, metadata: metadata(nil, app_id)) do
      {:ok, response.group}
    end
  end

  def leave_group(app_id, group_id, user_id) do
    request = %LeaveGroupRequest{
      app_id: app_id,
      group_id: clean_id(group_id)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           GroupStub.leave_group(channel, request, metadata: metadata(user_id, app_id)) do
      if response.success, do: :ok, else: {:error, response.message}
    end
  end

  def delete_group(app_id, group_id) do
    request = %DeleteGroupRequest{
      app_id: app_id,
      group_id: clean_id(group_id)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           GroupStub.delete_group(channel, request, metadata: metadata(nil, app_id)) do
      if response.success, do: :ok, else: {:error, response.message}
    end
  end

  def mute_group(app_id, group_id, user_id, mute) do
    request = %MuteGroupRequest{
      app_id: app_id,
      group_id: clean_id(group_id),
      mute: mute
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           GroupStub.mute_group(channel, request, metadata: metadata(user_id, app_id)) do
      if response.success, do: :ok, else: {:error, response.message}
    end
  end

  def accept_group_invitation(app_id, group_id, user_id) do
    request = %AcceptGroupInvitationRequest{
      app_id: app_id,
      group_id: clean_id(group_id)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           GroupStub.accept_group_invitation(channel, request,
             metadata: metadata(user_id, app_id)
           ) do
      if response.success, do: :ok, else: {:error, response.message}
    end
  end

  # --- ATTACHMENTS (ADVANCE TIER) ---

  def register_attachment(attrs) do
    request = %RegisterAttachmentRequest{
      id: attrs.id,
      app_id: attrs.app_id,
      uploader_id: ensure_string(attrs.uploader_id),
      storage_key: attrs.storage_key,
      mime_type: attrs.mime_type,
      size: attrs.size,
      checksum: attrs.checksum,
      status: attrs.status,
      metadata: Jason.encode!(attrs.metadata || %{})
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           AttStub.register_attachment(channel, request,
             metadata: metadata(attrs.uploader_id, attrs.app_id)
           ) do
      {:ok, response.attachment}
    else
      {:error, reason} ->
        Logger.error("[gRPC] AttachmentService.register_attachment error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def list_attachments_by_ids(app_id, ids) do
    request = %ListAttachmentsByIdsRequest{app_id: app_id, ids: ids}

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           AttStub.list_attachments_by_ids(channel, request, metadata: metadata(nil, app_id)) do
      response.attachments
    else
      _ -> []
    end
  end

  def list_messages_by_ids(app_id, ids) do
    request = %ListMessagesRequest{
      app_id: app_id,
      message_ids: ids,
      limit: length(ids)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           MsgStub.list_messages(channel, request, metadata: metadata(nil, app_id)) do
      response.messages
    else
      _ -> []
    end
  end

  # ─── Status ───────────────────────────────────────────────────────────────────

  def create_status(attrs) do
    request = %CreateStatusRequest{
      app_id: attrs.app_id,
      user_id: ensure_string(attrs.user_id),
      type: attrs.type,
      content: attrs.content || "",
      attachment_id: attrs.attachment_id || "",
      background_color: attrs.background_color || "",
      font_style: attrs.font_style || "",
      ttl_seconds: attrs.ttl_seconds || 86400
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           StatusStub.create_status(channel, request, metadata: metadata(attrs.user_id, attrs.app_id)) do
      {:ok, response.status}
    else
      {:error, reason} ->
        Logger.error("[gRPC] StatusService.create_status error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def list_statuses(app_id, requestor_id, contact_ids) do
    request = %ListStatusesRequest{
      app_id: app_id,
      requestor_id: ensure_string(requestor_id),
      contact_ids: Enum.map(contact_ids, &ensure_string/1)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           StatusStub.list_statuses(channel, request, metadata: metadata(requestor_id, app_id)) do
      response.statuses
    else
      _ -> []
    end
  end

  def view_status(app_id, status_id, viewer_id) do
    request = %ViewStatusRequest{
      status_id: ensure_string(status_id),
      viewer_id: ensure_string(viewer_id)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           StatusStub.view_status(channel, request, metadata: metadata(viewer_id, app_id)) do
      {:ok, response}
    else
      {:error, reason} ->
        Logger.error("[gRPC] StatusService.view_status error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def delete_status(app_id, status_id, user_id) do
    request = %DeleteStatusRequest{
      app_id: app_id,
      status_id: ensure_string(status_id)
    }

    with {:ok, channel} <- connect(),
         {:ok, response} <-
           StatusStub.delete_status(channel, request, metadata: metadata(user_id, app_id)) do
      {:ok, response}
    else
      {:error, reason} ->
        Logger.error("[gRPC] StatusService.delete_status error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ─── Analytics ────────────────────────────────────────────────────────────────

  # The get_global_stats function was moved to AdminClient using gRPC instead of HTTP.
  # Fallback for other methods - will be implemented as needed
  def method_missing(name, _args) do
    Logger.warning("[gRPC] ChatClient: Method #{name} not implemented yet.")
    {:error, :unimplemented}
  end

  defp clean_id(nil), do: ""

  defp clean_id(id) do
    id |> to_string() |> String.replace(~r/^(group_|room_)/, "")
  end

  defp ensure_string(id) when is_binary(id), do: id
  defp ensure_string(id) when is_integer(id), do: Integer.to_string(id)
  defp ensure_string(_), do: ""
end
