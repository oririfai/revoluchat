defmodule Revoluchat.Chat.Adapters.Grpc do
  @moduledoc """
  gRPC implementation of the Chat Adapter.
  Delegates all calls to the Go backend via Revoluchat.Grpc.ChatClient.
  """
  @behaviour Revoluchat.Chat.Adapter

  alias Revoluchat.Grpc.ChatClient

  # ─── Conversations ────────────────────────────────────────────────────────────

  def get_or_create_conversation(app_id, user_a_id, user_b_id) do
    case ChatClient.get_or_create_conversation(app_id, user_a_id, user_b_id) do
      {:ok, conv} -> {:ok, normalize_conversation(conv)}
      error -> error
    end
  end

  def get_conversation_for_user(app_id, conversation_id, user_id) do
    case ChatClient.get_conversation_for_user(app_id, conversation_id, user_id) do
      {:ok, conv} -> {:ok, normalize_conversation(conv)}
      error -> error
    end
  end

  def list_user_conversations(app_id, user_id, opts) do
    ChatClient.list_user_conversations(app_id, user_id, opts)
    |> Enum.map(&normalize_conversation/1)
  end

  def get_conversation!(app_id, id) do
    case ChatClient.get_conversation(app_id, id) do
      {:ok, conv} -> normalize_conversation(conv)
      {:error, _} -> raise "Conversation not found"
    end
  end

  def delete_conversation(app_id, ids, user_id) do
    ChatClient.delete_conversation(app_id, ids, user_id)
  end

  def archive_conversation(app_id, ids, user_id) do
    ChatClient.archive_conversation(app_id, ids, user_id)
  end

  def unarchive_conversation(app_id, ids, user_id) do
    ChatClient.unarchive_conversation(app_id, ids, user_id)
  end

  # ─── Status ───────────────────────────────────────────────────────────────────

  def create_status(attrs) do
    case ChatClient.create_status(attrs) do
      {:ok, status} -> {:ok, normalize_status(status)}
      error -> error
    end
  end

  def list_statuses(app_id, requestor_id, contact_ids) do
    ChatClient.list_statuses(app_id, requestor_id, contact_ids)
    |> Enum.map(&normalize_status/1)
  end

  def view_status(app_id, status_id, viewer_id) do
    ChatClient.view_status(app_id, status_id, viewer_id)
  end

  def delete_status(app_id, status_id, user_id) do
    ChatClient.delete_status(app_id, status_id, user_id)
  end


  # ─── Messages ─────────────────────────────────────────────────────────────────

  def insert_message(attrs) do
    case ChatClient.insert_message(attrs) do
      {:ok, msg, _grpc_atts} ->
        normalized_msg = normalize_message(msg)
        # Return the already normalized attachments from inside the message
        {:ok, normalized_msg, normalized_msg.attachments}
      error -> error
    end
  end

  def list_messages(app_id, conversation_id, user_id, opts) do
    ChatClient.list_messages(app_id, conversation_id, user_id, opts)
    |> Enum.map(&normalize_message/1)
  end

  def list_messages_by_ids(app_id, ids) do
    ChatClient.list_messages_by_ids(app_id, ids)
    |> Enum.map(&normalize_message/1)
  end

  def get_message!(id) do
    case ChatClient.get_message(id) do
      {:ok, msg} -> normalize_message(msg)
      {:error, _} -> raise "Message not found"
    end
  end

  def get_message_with_conversation!(message_id) do
    case ChatClient.get_message_with_conversation(message_id) do
      {:ok, msg} -> normalize_message(msg)
      error -> error
    end
  end

  def mark_read(app_id, message_id, user_id) do
    case ChatClient.mark_read(app_id, message_id, user_id) do
      {:ok, msg} -> {:ok, normalize_message(msg)}
      error -> error
    end
  end

  def mark_delivered(app_id, message_id, user_id) do
    case ChatClient.mark_delivered(app_id, message_id, user_id) do
      {:ok, msg} -> {:ok, normalize_message(msg)}
      error -> error
    end
  end

  def soft_delete_message(app_id, message_id, user_id) do
    case ChatClient.soft_delete_message(app_id, message_id, user_id) do
      {:ok, msg} -> {:ok, normalize_message(msg)}
      error -> error
    end
  end

  def soft_delete_messages(app_id, message_ids, user_id) do
    ChatClient.soft_delete_messages(app_id, message_ids, user_id)
  end

  # ─── Attachments ──────────────────────────────────────────────────────────────

  # For Advance Tier, Go handles attachment persistence, but Elixir still provides URLs
  def get_attachment!(id) do
    ChatClient.get_attachment(id)
  end

  def create_attachment_init(attrs) do
    ChatClient.create_attachment_init(attrs)
  end

  def confirm_attachment(app_id, id, uploader_id) do
    ChatClient.confirm_attachment(app_id, id, uploader_id)
  end

  def get_attachment_download_url(app_id, attachment_id, user_id) do
    ChatClient.get_attachment_download_url(app_id, attachment_id, user_id)
  end

  def list_attachments_by_ids(app_id, ids) do
    ChatClient.list_attachments_by_ids(app_id, ids)
  end

  # ─── Analytics ──────────────────────────────────────────────────────────────

  def count_messages_for_app(app_id) do
    ChatClient.count_messages_for_app(app_id)
  end

  def count_active_conversations(app_id) do
    ChatClient.count_active_conversations(app_id)
  end

  # --- GROUPS (ADVANCE TIER) ---

  def create_group(app_id, params) do
    ChatClient.create_group(app_id, params)
  end

  def get_group(app_id, group_id) do
    ChatClient.get_group(app_id, group_id)
  end

  def add_members(app_id, group_id, user_ids, role) do
    ChatClient.add_members(app_id, group_id, user_ids, role)
  end

  def remove_member(app_id, group_id, user_id) do
    ChatClient.remove_member(app_id, group_id, user_id)
  end

  def update_group(app_id, group_id, params) do
    ChatClient.update_group(app_id, group_id, params)
  end

  def leave_group(app_id, group_id, user_id) do
    ChatClient.leave_group(app_id, group_id, user_id)
  end

  def delete_group(app_id, group_id) do
    ChatClient.delete_group(app_id, group_id)
  end

  def mute_group(app_id, group_id, user_id, mute) do
    ChatClient.mute_group(app_id, group_id, user_id, mute)
  end

  def accept_group_invitation(app_id, group_id, user_id) do
    ChatClient.accept_group_invitation(app_id, group_id, user_id)
  end

  # ─── Private Helpers ─────────────────────────────────────────────────────────

  # ─── Normalizers ──────────────────────────────────────────────────────────────

  defp normalize_status(nil), do: nil
  defp normalize_status(status) do
    %{
      id: status.id,
      app_id: status.app_id,
      user_id: status.user_id,
      type: status.type,
      content: status.content,
      attachment_id: status.attachment_id,
      background_color: status.background_color,
      font_style: status.font_style,
      expires_at: parse_dt(status.expires_at),
      created_at: parse_dt(status.created_at),
      views: normalize_status_views(Map.get(status, :views) || [])
    }
  end

  defp normalize_status_views(views) when is_list(views) do
    Enum.map(views, fn v ->
      %{
        viewer_id: to_string(Map.get(v, :viewer_id) || Map.get(v, "viewer_id") || ""),
        viewed_at: to_string(Map.get(v, :viewed_at) || Map.get(v, "viewed_at") || "")
      }
    end)
  end
  defp normalize_status_views(_), do: []

  defp normalize_conversation(nil), do: nil
  defp normalize_conversation(conv) do
    %{conv |
      last_activity_at: parse_dt(conv.last_activity_at),
      last_message: normalize_message(conv.last_message),
      archived_at: conv.archived_at,
      group: normalize_group(conv.group)
    }
  end

  defp normalize_message(nil), do: nil
  defp normalize_message(msg) do
    atts = (msg.attachments || []) |> Enum.map(&normalize_attachment/1)

    %Revoluchat.Chat.Message{
      id: msg.id,
      app_id: msg.app_id,
      conversation_id: empty_to_nil(msg.conversation_id),
      group_id: empty_to_nil(msg.group_id),
      sender_id: msg.sender_id,
      type: msg.type,
      body: msg.body,
      is_encrypted: msg.is_encrypted,
      client_id: msg.client_id,
      reply_to_id: empty_to_nil(msg.reply_to_id),
      attachment_id: empty_to_nil(msg.attachment_id),
      attachment_ids: msg.attachment_ids || [],
      # Use a virtual field or just put it in the struct
      # We'll put it in a virtual field if it exists, otherwise just map it
      inserted_at: parse_dt(msg.inserted_at),
      delivered_at: parse_dt(msg.delivered_at),
      read_at: parse_dt(msg.read_at),
      deleted_at: parse_dt(msg.deleted_at)
    }
    |> Map.put(:attachments, atts)
  end

  defp normalize_group(nil), do: nil
  defp normalize_group(g) do
    %{g |
      inserted_at: parse_dt(g.inserted_at),
      updated_at: parse_dt(g.updated_at),
      members: Enum.map(g.members || [], fn m ->
        %{m | joined_at: parse_dt(m.joined_at)}
      end)
    }
  end

  def normalize_attachment(nil), do: nil
  def normalize_attachment(att) do
    metadata =
      case Jason.decode(att.metadata || "{}") do
        {:ok, map} -> map
        _ -> %{}
      end

    %Revoluchat.Chat.Attachment{
      id: att.id,
      app_id: att.app_id,
      uploader_id: att.uploader_id,
      storage_key: att.storage_key,
      mime_type: att.mime_type,
      size: att.size,
      checksum: att.checksum,
      status: att.status,
      metadata: metadata,
      inserted_at: parse_dt(att.inserted_at),
      updated_at: parse_dt(att.updated_at)
    }
  end

  defp parse_dt(nil), do: nil
  defp parse_dt(""), do: nil
  defp parse_dt(%{seconds: seconds, nanos: nanos}) when is_integer(seconds) and is_integer(nanos) do
    DateTime.from_unix!(seconds * 1_000_000_000 + nanos, :nanosecond)
  end
  defp parse_dt(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
  defp parse_dt(dt), do: dt

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(val), do: val
end
