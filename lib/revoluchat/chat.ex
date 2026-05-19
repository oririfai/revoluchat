defmodule Revoluchat.Chat do
  @moduledoc """
  Context for conversation and message management.
  Acts as a dispatcher between Postgres and gRPC storage adapters.
  """
  require Logger

  @doc """
  Returns the active storage adapter based on TIER_TYPE.
  """
  def adapter do
    tier = Application.get_env(:revoluchat, :tier_type)
    Logger.info("[Chat] Active Tier: #{tier}")
    case tier do
      "advance" -> Revoluchat.Chat.Adapters.Grpc
      _ -> Revoluchat.Chat.Adapters.Postgres
    end
  end

  # ─── Conversations ────────────────────────────────────────────────────────────

  def get_or_create_conversation(app_id, user_a_id, user_b_id), do: adapter().get_or_create_conversation(app_id, user_a_id, user_b_id)
  def get_conversation_for_user(app_id, conversation_id, user_id), do: adapter().get_conversation_for_user(app_id, conversation_id, user_id)
  def list_user_conversations(app_id, user_id, opts \\ []), do: adapter().list_user_conversations(app_id, user_id, opts)
  def get_conversation!(app_id, id), do: adapter().get_conversation!(app_id, id)
  def delete_conversation(app_id, ids, user_id), do: adapter().delete_conversation(app_id, ids, user_id)
  def archive_conversation(app_id, ids, user_id), do: adapter().archive_conversation(app_id, ids, user_id)
  def unarchive_conversation(app_id, ids, user_id), do: adapter().unarchive_conversation(app_id, ids, user_id)

  # ─── Messages ─────────────────────────────────────────────────────────────────

  def insert_message(attrs), do: adapter().insert_message(attrs)
  def list_messages(app_id, conversation_id, user_id, opts \\ []), do: adapter().list_messages(app_id, conversation_id, user_id, opts)
  def list_messages_by_ids(app_id, ids), do: adapter().list_messages_by_ids(app_id, ids)
  def get_message!(id), do: adapter().get_message!(id)
  def get_message_with_conversation!(message_id), do: adapter().get_message_with_conversation!(message_id)

  def mark_read(app_id, message_id, user_id), do: adapter().mark_read(app_id, message_id, user_id)
  def mark_delivered(app_id, message_id, user_id), do: adapter().mark_delivered(app_id, message_id, user_id)
  def soft_delete_message(app_id, message_id, user_id), do: adapter().soft_delete_message(app_id, message_id, user_id)
  def soft_delete_messages(app_id, message_ids, user_id), do: adapter().soft_delete_messages(app_id, message_ids, user_id)

  # ─── Attachments ──────────────────────────────────────────────────────────────

  def get_attachment!(id), do: Revoluchat.Chat.Adapters.Postgres.get_attachment!(id)
  def create_attachment_init(attrs), do: Revoluchat.Chat.Adapters.Postgres.create_attachment_init(attrs)
  
  def confirm_attachment(app_id, id, uploader_id) do
    # Always confirm in local Elixir DB first
    case Revoluchat.Chat.Adapters.Postgres.confirm_attachment(app_id, id, uploader_id) do
      {:ok, attachment} ->
        # If Advance Tier, sync metadata to Go backend
        if Application.get_env(:revoluchat, :tier_type) == "advance" do
          Revoluchat.Grpc.ChatClient.register_attachment(attachment)
        end
        {:ok, attachment}
      error -> error
    end
  end

  def approve_attachment_direct(app_id, id) do
    case Revoluchat.Chat.Adapters.Postgres.approve_attachment_direct(app_id, id) do
      {:ok, attachment} ->
        if Application.get_env(:revoluchat, :tier_type) == "advance" do
          Revoluchat.Grpc.ChatClient.register_attachment(attachment)
        end
        {:ok, attachment}
      error -> error
    end
  end

  def get_attachment_download_url(app_id, attachment_id, user_id), do: Revoluchat.Chat.Adapters.Postgres.get_attachment_download_url(app_id, attachment_id, user_id)
  
  def list_attachments_by_ids(app_id, ids) do
    if Application.get_env(:revoluchat, :tier_type) == "advance" do
      # In Advance Tier, get from Go and normalize (decode metadata string)
      Revoluchat.Grpc.ChatClient.list_attachments_by_ids(app_id, ids)
      |> Enum.map(&Revoluchat.Chat.Adapters.Grpc.normalize_attachment/1)
    else
      Revoluchat.Chat.Adapters.Postgres.list_attachments_by_ids(app_id, ids)
    end
  end

  def get_approved_attachment_for_user(app_id, id, user_id), do: Revoluchat.Chat.Adapters.Postgres.get_approved_attachment_for_user(app_id, id, user_id)

  # ─── Analytics ──────────────────────────────────────────────────────────────

  def count_messages_for_app(app_id), do: adapter().count_messages_for_app(app_id)
  def count_active_conversations(app_id), do: adapter().count_active_conversations(app_id)

  # --- GROUPS (ADVANCE TIER) ---

  def create_group(app_id, params), do: adapter().create_group(app_id, params)
  def get_group(app_id, group_id), do: adapter().get_group(app_id, group_id)
  def add_members(app_id, group_id, user_ids, role \\ "member"), do: adapter().add_members(app_id, group_id, user_ids, role)
  def remove_member(app_id, group_id, user_id), do: adapter().remove_member(app_id, group_id, user_id)
  def update_group(app_id, group_id, params), do: adapter().update_group(app_id, group_id, params)
  def leave_group(app_id, group_id, user_id), do: adapter().leave_group(app_id, group_id, user_id)
  def delete_group(app_id, group_id), do: adapter().delete_group(app_id, group_id)
  def mute_group(app_id, group_id, user_id, mute), do: adapter().mute_group(app_id, group_id, user_id, mute)
  def accept_group_invitation(app_id, group_id, user_id), do: adapter().accept_group_invitation(app_id, group_id, user_id)
end
