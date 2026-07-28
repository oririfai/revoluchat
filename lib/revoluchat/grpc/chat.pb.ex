defmodule Revoluchat.V1.DeleteConversationRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.DeleteConversationRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :user_id, 2, type: :string, json_name: "userId"
  field :ids, 3, repeated: true, type: :string
end

defmodule Revoluchat.V1.ArchiveConversationRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.ArchiveConversationRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :user_id, 2, type: :string, json_name: "userId"
  field :ids, 3, repeated: true, type: :string
end

defmodule Revoluchat.V1.UnarchiveConversationRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.UnarchiveConversationRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :user_id, 2, type: :string, json_name: "userId"
  field :ids, 3, repeated: true, type: :string
end

defmodule Revoluchat.V1.CreateConversationRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.CreateConversationRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :user_a_id, 1, type: :string, json_name: "userAId"
  field :user_b_id, 2, type: :string, json_name: "userBId"
  field :app_id, 3, type: :string, json_name: "appId"
end

defmodule Revoluchat.V1.CreateConversationResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.CreateConversationResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :conversation_id, 1, type: :string, json_name: "conversationId"
  field :is_new, 2, type: :bool, json_name: "isNew"
  field :conversation, 3, type: Revoluchat.V1.Conversation
end

defmodule Revoluchat.V1.ListConversationsRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.ListConversationsRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :user_id, 1, type: :string, json_name: "userId"
  field :app_id, 2, type: :string, json_name: "appId"
  field :search, 3, type: :string
end

defmodule Revoluchat.V1.ListConversationsResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.ListConversationsResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :conversations, 1, repeated: true, type: Revoluchat.V1.Conversation
end

defmodule Revoluchat.V1.GetConversationRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.GetConversationRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :conversation_id, 2, type: :string, json_name: "conversationId"
end

defmodule Revoluchat.V1.GetConversationResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.GetConversationResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :conversation, 1, type: Revoluchat.V1.Conversation
end

defmodule Revoluchat.V1.Conversation do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.Conversation",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :id, 1, type: :string
  field :app_id, 2, type: :string, json_name: "appId"
  field :user_a_id, 3, type: :string, json_name: "userAId"
  field :user_b_id, 4, type: :string, json_name: "userBId"
  field :last_activity_at, 5, type: :string, json_name: "lastActivityAt"
  field :last_message, 6, type: Revoluchat.V1.Message, json_name: "lastMessage"
  field :unread_count, 7, type: :uint32, json_name: "unreadCount"
  field :type, 8, type: :string
  field :group, 9, type: Revoluchat.V1.Group
  field :archived_at, 10, type: :string, json_name: "archivedAt"
end

defmodule Revoluchat.V1.Group do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.Group",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :id, 1, type: :string
  field :app_id, 2, type: :string, json_name: "appId"
  field :name, 3, type: :string
  field :description, 4, type: :string
  field :avatar_url, 5, type: :string, json_name: "avatarUrl"
  field :is_locked, 6, type: :bool, json_name: "isLocked"
  field :creator_id, 7, type: :string, json_name: "creatorId"
  field :inserted_at, 8, type: :string, json_name: "insertedAt"
  field :updated_at, 9, type: :string, json_name: "updatedAt"
  field :members, 10, repeated: true, type: Revoluchat.V1.GroupMember
  field :unread_count, 11, type: :uint32, json_name: "unreadCount"
  field :my_status, 12, type: :string, json_name: "myStatus"
  field :last_message, 13, type: Revoluchat.V1.Message, json_name: "lastMessage"
end

defmodule Revoluchat.V1.GroupMember do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.GroupMember",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :user_id, 1, type: :string, json_name: "userId"
  field :role, 2, type: :string
  field :is_muted, 3, type: :bool, json_name: "isMuted"
  field :joined_at, 4, type: :string, json_name: "joinedAt"
  field :status, 5, type: :string
  field :archived_at, 6, type: :string, json_name: "archivedAt"
end

defmodule Revoluchat.V1.CreateGroupRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.CreateGroupRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :name, 2, type: :string
  field :description, 3, type: :string
  field :member_ids, 4, repeated: true, type: :string, json_name: "memberIds"
  field :admin_ids, 5, repeated: true, type: :string, json_name: "adminIds"
  field :avatar_url, 6, type: :string, json_name: "avatarUrl"
end

defmodule Revoluchat.V1.CreateGroupResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.CreateGroupResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :group, 1, type: Revoluchat.V1.Group
end

defmodule Revoluchat.V1.GetGroupRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.GetGroupRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :group_id, 2, type: :string, json_name: "groupId"
end

defmodule Revoluchat.V1.GetGroupResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.GetGroupResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :group, 1, type: Revoluchat.V1.Group
end

defmodule Revoluchat.V1.AddMembersRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.AddMembersRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :group_id, 2, type: :string, json_name: "groupId"
  field :user_ids, 3, repeated: true, type: :string, json_name: "userIds"
  field :role, 4, type: :string
end

defmodule Revoluchat.V1.RemoveMemberRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.RemoveMemberRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :group_id, 2, type: :string, json_name: "groupId"
  field :user_id, 3, type: :string, json_name: "userId"
end

defmodule Revoluchat.V1.UpdateGroupRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.UpdateGroupRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :group_id, 2, type: :string, json_name: "groupId"
  field :name, 3, type: :string
  field :description, 4, type: :string
  field :avatar_url, 5, type: :string, json_name: "avatarUrl"
  field :is_locked, 6, type: :bool, json_name: "isLocked"
end

defmodule Revoluchat.V1.UpdateGroupResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.UpdateGroupResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :group, 1, type: Revoluchat.V1.Group
end

defmodule Revoluchat.V1.LeaveGroupRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.LeaveGroupRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :group_id, 2, type: :string, json_name: "groupId"
end

defmodule Revoluchat.V1.AcceptGroupInvitationRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.AcceptGroupInvitationRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :group_id, 2, type: :string, json_name: "groupId"
end

defmodule Revoluchat.V1.DeleteGroupRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.DeleteGroupRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :group_id, 2, type: :string, json_name: "groupId"
end

defmodule Revoluchat.V1.MuteGroupRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.MuteGroupRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :group_id, 2, type: :string, json_name: "groupId"
  field :mute, 3, type: :bool
end

defmodule Revoluchat.V1.ActionResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.ActionResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :success, 1, type: :bool
  field :message, 2, type: :string
end

defmodule Revoluchat.V1.Attachment do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.Attachment",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :id, 1, type: :string
  field :app_id, 2, type: :string, json_name: "appId"
  field :uploader_id, 3, type: :string, json_name: "uploaderId"
  field :storage_key, 4, type: :string, json_name: "storageKey"
  field :mime_type, 5, type: :string, json_name: "mimeType"
  field :size, 6, type: :uint64
  field :checksum, 7, type: :string
  field :status, 8, type: :string
  field :metadata, 9, type: :string
  field :inserted_at, 10, type: :string, json_name: "insertedAt"
  field :updated_at, 11, type: :string, json_name: "updatedAt"
end

defmodule Revoluchat.V1.RegisterAttachmentRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.RegisterAttachmentRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :id, 1, type: :string
  field :app_id, 2, type: :string, json_name: "appId"
  field :uploader_id, 3, type: :string, json_name: "uploaderId"
  field :storage_key, 4, type: :string, json_name: "storageKey"
  field :mime_type, 5, type: :string, json_name: "mimeType"
  field :size, 6, type: :uint64
  field :checksum, 7, type: :string
  field :status, 8, type: :string
  field :metadata, 9, type: :string
end

defmodule Revoluchat.V1.RegisterAttachmentResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.RegisterAttachmentResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :attachment, 1, type: Revoluchat.V1.Attachment
end

defmodule Revoluchat.V1.ListAttachmentsByIdsRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.ListAttachmentsByIdsRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :ids, 2, repeated: true, type: :string
end

defmodule Revoluchat.V1.ListAttachmentsByIdsResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.ListAttachmentsByIdsResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :attachments, 1, repeated: true, type: Revoluchat.V1.Attachment
end

defmodule Revoluchat.V1.Message do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.Message",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :id, 1, type: :string
  field :app_id, 2, type: :string, json_name: "appId"
  field :conversation_id, 3, type: :string, json_name: "conversationId"
  field :group_id, 16, type: :string, json_name: "groupId"
  field :sender_id, 4, type: :string, json_name: "senderId"
  field :type, 5, type: :string
  field :body, 6, type: :string
  field :is_encrypted, 7, type: :bool, json_name: "isEncrypted"
  field :client_id, 8, type: :string, json_name: "clientId"
  field :reply_to_id, 9, type: :string, json_name: "replyToId"
  field :attachment_ids, 10, repeated: true, type: :string, json_name: "attachmentIds"
  field :attachment_id, 11, type: :string, json_name: "attachmentId"
  field :inserted_at, 12, type: :string, json_name: "insertedAt"
  field :delivered_at, 13, type: :string, json_name: "deliveredAt"
  field :read_at, 14, type: :string, json_name: "readAt"
  field :deleted_at, 15, type: :string, json_name: "deletedAt"
  field :attachments, 17, repeated: true, type: Revoluchat.V1.Attachment
end

defmodule Revoluchat.V1.InsertMessageRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.InsertMessageRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :conversation_id, 2, type: :string, json_name: "conversationId"
  field :group_id, 11, type: :string, json_name: "groupId"
  field :sender_id, 3, type: :string, json_name: "senderId"
  field :type, 4, type: :string
  field :body, 5, type: :string
  field :is_encrypted, 6, type: :bool, json_name: "isEncrypted"
  field :client_id, 7, type: :string, json_name: "clientId"
  field :reply_to_id, 8, type: :string, json_name: "replyToId"
  field :attachment_ids, 9, repeated: true, type: :string, json_name: "attachmentIds"
  field :attachment_id, 10, type: :string, json_name: "attachmentId"
end

defmodule Revoluchat.V1.InsertMessageResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.InsertMessageResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :message, 1, type: Revoluchat.V1.Message
end

defmodule Revoluchat.V1.ListMessagesRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.ListMessagesRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :conversation_id, 2, type: :string, json_name: "conversationId"
  field :group_id, 6, type: :string, json_name: "groupId"
  field :limit, 3, type: :uint32
  field :before_id, 4, type: :string, json_name: "beforeId"
  field :search, 5, type: :string
  field :message_ids, 7, repeated: true, type: :string, json_name: "messageIds"
end

defmodule Revoluchat.V1.ListMessagesResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.ListMessagesResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :messages, 1, repeated: true, type: Revoluchat.V1.Message
end

defmodule Revoluchat.V1.MarkReadRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.MarkReadRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :message_id, 2, type: :string, json_name: "messageId"
  field :user_id, 3, type: :string, json_name: "userId"
end

defmodule Revoluchat.V1.MarkReadResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.MarkReadResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :message, 1, type: Revoluchat.V1.Message
end

defmodule Revoluchat.V1.MarkDeliveredRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.MarkDeliveredRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :message_id, 2, type: :string, json_name: "messageId"
  field :user_id, 3, type: :string, json_name: "userId"
end

defmodule Revoluchat.V1.MarkDeliveredResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.MarkDeliveredResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :message, 1, type: Revoluchat.V1.Message
end

defmodule Revoluchat.V1.DeleteMessageRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.DeleteMessageRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :message_id, 2, type: :string, json_name: "messageId"
  field :user_id, 3, type: :string, json_name: "userId"
end

defmodule Revoluchat.V1.DeleteMessageResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.DeleteMessageResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :message, 1, type: Revoluchat.V1.Message
end

defmodule Revoluchat.V1.BulkDeleteMessagesRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.BulkDeleteMessagesRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :message_ids, 2, repeated: true, type: :string, json_name: "messageIds"
  field :user_id, 3, type: :string, json_name: "userId"
end

defmodule Revoluchat.V1.BulkDeleteMessagesResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.BulkDeleteMessagesResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :count, 1, type: :uint32
end

defmodule Revoluchat.V1.GetCallRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.GetCallRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :call_id, 2, type: :string, json_name: "callId"
end

defmodule Revoluchat.V1.GetCallResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.GetCallResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :call, 1, type: Revoluchat.V1.Call
end

defmodule Revoluchat.V1.Call do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.Call",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :id, 1, type: :string
  field :app_id, 2, type: :string, json_name: "appId"
  field :conversation_id, 3, type: :string, json_name: "conversationId"
  field :group_id, 11, type: :string, json_name: "groupId"
  field :caller_id, 4, type: :string, json_name: "callerId"
  field :receiver_id, 5, type: :string, json_name: "receiverId"
  field :type, 6, type: :string
  field :status, 7, type: :string
  field :duration_seconds, 8, type: :uint32, json_name: "durationSeconds"
  field :started_at, 9, type: :string, json_name: "startedAt"
  field :ended_at, 10, type: :string, json_name: "endedAt"
end

defmodule Revoluchat.V1.InitiateCallRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.InitiateCallRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :conversation_id, 2, type: :string, json_name: "conversationId"
  field :group_id, 6, type: :string, json_name: "groupId"
  field :caller_id, 3, type: :string, json_name: "callerId"
  field :receiver_id, 4, type: :string, json_name: "receiverId"
  field :type, 5, type: :string
end

defmodule Revoluchat.V1.InitiateCallResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.InitiateCallResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :call, 1, type: Revoluchat.V1.Call
end

defmodule Revoluchat.V1.UpdateCallStatusRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.UpdateCallStatusRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :call_id, 2, type: :string, json_name: "callId"
  field :status, 3, type: :string
end

defmodule Revoluchat.V1.UpdateCallStatusResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.UpdateCallStatusResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :call, 1, type: Revoluchat.V1.Call
end

defmodule Revoluchat.V1.ListCallHistoryRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.ListCallHistoryRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :user_id, 2, type: :string, json_name: "userId"
  field :limit, 3, type: :uint32
  field :other_party_id, 4, type: :string, json_name: "otherPartyId"
end

defmodule Revoluchat.V1.ListCallHistoryResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.ListCallHistoryResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :records, 1, repeated: true, type: Revoluchat.V1.CallHistoryRecord
end

defmodule Revoluchat.V1.CallHistoryRecord do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.CallHistoryRecord",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :id, 1, type: :string
  field :app_id, 2, type: :string, json_name: "appId"
  field :user_id, 3, type: :string, json_name: "userId"
  field :other_party_id, 4, type: :string, json_name: "otherPartyId"
  field :direction, 5, type: :string
  field :type, 6, type: :string
  field :status, 7, type: :string
  field :duration_seconds, 8, type: :uint32, json_name: "durationSeconds"
  field :started_at, 9, type: :string, json_name: "startedAt"
  field :conversation_id, 10, type: :string, json_name: "conversationId"
  field :group_id, 13, type: :string, json_name: "groupId"
  field :inserted_at, 11, type: :string, json_name: "insertedAt"
  field :updated_at, 12, type: :string, json_name: "updatedAt"
end

defmodule Revoluchat.V1.DeleteCallHistoryRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.DeleteCallHistoryRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :user_id, 2, type: :string, json_name: "userId"
  field :ids, 3, repeated: true, type: :string
end

defmodule Revoluchat.V1.DeleteCallHistoryResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.DeleteCallHistoryResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :count, 1, type: :uint32
end

defmodule Revoluchat.V1.Status do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.Status",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :id, 1, type: :string
  field :app_id, 2, type: :string, json_name: "appId"
  field :user_id, 3, type: :string, json_name: "userId"
  field :type, 4, type: :string
  field :content, 5, type: :string
  field :attachment_id, 6, type: :string, json_name: "attachmentId"
  field :background_color, 7, type: :string, json_name: "backgroundColor"
  field :font_style, 8, type: :string, json_name: "fontStyle"
  field :expires_at, 9, type: :string, json_name: "expiresAt"
  field :created_at, 10, type: :string, json_name: "createdAt"
  field :views, 11, repeated: true, type: Revoluchat.V1.StatusView
end

defmodule Revoluchat.V1.StatusView do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.StatusView",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :viewer_id, 1, type: :string, json_name: "viewerId"
  field :viewed_at, 2, type: :string, json_name: "viewedAt"
end

defmodule Revoluchat.V1.CreateStatusRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.CreateStatusRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :user_id, 2, type: :string, json_name: "userId"
  field :type, 3, type: :string
  field :content, 4, type: :string
  field :attachment_id, 5, type: :string, json_name: "attachmentId"
  field :background_color, 6, type: :string, json_name: "backgroundColor"
  field :font_style, 7, type: :string, json_name: "fontStyle"
  field :ttl_seconds, 8, type: :uint32, json_name: "ttlSeconds"
end

defmodule Revoluchat.V1.CreateStatusResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.CreateStatusResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :status, 1, type: Revoluchat.V1.Status
end

defmodule Revoluchat.V1.ListStatusesRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.ListStatusesRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :requestor_id, 2, type: :string, json_name: "requestorId"
  field :contact_ids, 3, repeated: true, type: :string, json_name: "contactIds"
end

defmodule Revoluchat.V1.ListStatusesResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.ListStatusesResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :statuses, 1, repeated: true, type: Revoluchat.V1.Status
end

defmodule Revoluchat.V1.ViewStatusRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.ViewStatusRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :status_id, 2, type: :string, json_name: "statusId"
  field :viewer_id, 3, type: :string, json_name: "viewerId"
end

defmodule Revoluchat.V1.DeleteStatusRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.DeleteStatusRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :status_id, 2, type: :string, json_name: "statusId"
  field :user_id, 3, type: :string, json_name: "userId"
end

defmodule Revoluchat.V1.ConversationService.Service do
  @moduledoc false

  use GRPC.Service, name: "revoluchat.v1.ConversationService", protoc_gen_elixir_version: "0.17.0"

  rpc :CreateConversation,
      Revoluchat.V1.CreateConversationRequest,
      Revoluchat.V1.CreateConversationResponse

  rpc :ListConversations,
      Revoluchat.V1.ListConversationsRequest,
      Revoluchat.V1.ListConversationsResponse

  rpc :GetConversation,
      Revoluchat.V1.GetConversationRequest,
      Revoluchat.V1.GetConversationResponse

  rpc :DeleteConversation, Revoluchat.V1.DeleteConversationRequest, Revoluchat.V1.ActionResponse

  rpc :ArchiveConversation, Revoluchat.V1.ArchiveConversationRequest, Revoluchat.V1.ActionResponse

  rpc :UnarchiveConversation,
      Revoluchat.V1.UnarchiveConversationRequest,
      Revoluchat.V1.ActionResponse

  rpc :ListArchivedConversations,
      Revoluchat.V1.ListConversationsRequest,
      Revoluchat.V1.ListConversationsResponse
end

defmodule Revoluchat.V1.ConversationService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Revoluchat.V1.ConversationService.Service
end

defmodule Revoluchat.V1.GroupService.Service do
  @moduledoc false

  use GRPC.Service, name: "revoluchat.v1.GroupService", protoc_gen_elixir_version: "0.17.0"

  rpc :CreateGroup, Revoluchat.V1.CreateGroupRequest, Revoluchat.V1.CreateGroupResponse

  rpc :GetGroup, Revoluchat.V1.GetGroupRequest, Revoluchat.V1.GetGroupResponse

  rpc :AddMembers, Revoluchat.V1.AddMembersRequest, Revoluchat.V1.ActionResponse

  rpc :RemoveMember, Revoluchat.V1.RemoveMemberRequest, Revoluchat.V1.ActionResponse

  rpc :UpdateGroup, Revoluchat.V1.UpdateGroupRequest, Revoluchat.V1.UpdateGroupResponse

  rpc :LeaveGroup, Revoluchat.V1.LeaveGroupRequest, Revoluchat.V1.ActionResponse

  rpc :DeleteGroup, Revoluchat.V1.DeleteGroupRequest, Revoluchat.V1.ActionResponse

  rpc :MuteGroup, Revoluchat.V1.MuteGroupRequest, Revoluchat.V1.ActionResponse

  rpc :AcceptGroupInvitation,
      Revoluchat.V1.AcceptGroupInvitationRequest,
      Revoluchat.V1.ActionResponse
end

defmodule Revoluchat.V1.GroupService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Revoluchat.V1.GroupService.Service
end

defmodule Revoluchat.V1.AttachmentService.Service do
  @moduledoc false

  use GRPC.Service, name: "revoluchat.v1.AttachmentService", protoc_gen_elixir_version: "0.17.0"

  rpc :RegisterAttachment,
      Revoluchat.V1.RegisterAttachmentRequest,
      Revoluchat.V1.RegisterAttachmentResponse

  rpc :ListAttachmentsByIds,
      Revoluchat.V1.ListAttachmentsByIdsRequest,
      Revoluchat.V1.ListAttachmentsByIdsResponse
end

defmodule Revoluchat.V1.AttachmentService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Revoluchat.V1.AttachmentService.Service
end

defmodule Revoluchat.V1.MessageService.Service do
  @moduledoc false

  use GRPC.Service, name: "revoluchat.v1.MessageService", protoc_gen_elixir_version: "0.17.0"

  rpc :InsertMessage, Revoluchat.V1.InsertMessageRequest, Revoluchat.V1.InsertMessageResponse

  rpc :ListMessages, Revoluchat.V1.ListMessagesRequest, Revoluchat.V1.ListMessagesResponse

  rpc :MarkRead, Revoluchat.V1.MarkReadRequest, Revoluchat.V1.MarkReadResponse

  rpc :MarkDelivered, Revoluchat.V1.MarkDeliveredRequest, Revoluchat.V1.MarkDeliveredResponse

  rpc :DeleteMessage, Revoluchat.V1.DeleteMessageRequest, Revoluchat.V1.DeleteMessageResponse

  rpc :BulkDeleteMessages,
      Revoluchat.V1.BulkDeleteMessagesRequest,
      Revoluchat.V1.BulkDeleteMessagesResponse
end

defmodule Revoluchat.V1.MessageService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Revoluchat.V1.MessageService.Service
end

defmodule Revoluchat.V1.CallService.Service do
  @moduledoc false

  use GRPC.Service, name: "revoluchat.v1.CallService", protoc_gen_elixir_version: "0.17.0"

  rpc :InitiateCall, Revoluchat.V1.InitiateCallRequest, Revoluchat.V1.InitiateCallResponse

  rpc :UpdateCallStatus,
      Revoluchat.V1.UpdateCallStatusRequest,
      Revoluchat.V1.UpdateCallStatusResponse

  rpc :GetCall, Revoluchat.V1.GetCallRequest, Revoluchat.V1.GetCallResponse

  rpc :ListCallHistory,
      Revoluchat.V1.ListCallHistoryRequest,
      Revoluchat.V1.ListCallHistoryResponse

  rpc :DeleteCallHistory,
      Revoluchat.V1.DeleteCallHistoryRequest,
      Revoluchat.V1.DeleteCallHistoryResponse
end

defmodule Revoluchat.V1.CallService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Revoluchat.V1.CallService.Service
end

defmodule Revoluchat.V1.StatusService.Service do
  @moduledoc false

  use GRPC.Service, name: "revoluchat.v1.StatusService", protoc_gen_elixir_version: "0.17.0"

  rpc :CreateStatus, Revoluchat.V1.CreateStatusRequest, Revoluchat.V1.CreateStatusResponse

  rpc :ListStatuses, Revoluchat.V1.ListStatusesRequest, Revoluchat.V1.ListStatusesResponse

  rpc :ViewStatus, Revoluchat.V1.ViewStatusRequest, Revoluchat.V1.ActionResponse

  rpc :DeleteStatus, Revoluchat.V1.DeleteStatusRequest, Revoluchat.V1.ActionResponse
end

defmodule Revoluchat.V1.StatusService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Revoluchat.V1.StatusService.Service
end
