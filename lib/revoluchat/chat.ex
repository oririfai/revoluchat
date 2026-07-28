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

  @doc """
  Fungsi fan-out untuk fitur Siaran (Broadcast).
  Akan mengirim pesan satu per satu ke setiap recipient_ids dalam 1-on-1 private chat,
  menggunakan proses asinkron untuk efisiensi.
  """
  def broadcast_message(app_id, sender_id, body, recipient_ids) when is_list(recipient_ids) do
    Task.start(fn ->
      Enum.each(recipient_ids, fn receiver_id ->
        # Pastikan conversation private antara sender dan receiver ada
        case get_or_create_conversation(app_id, sender_id, receiver_id) do
          {:ok, conv} ->
            insert_message(%{
              app_id: app_id,
              conversation_id: conv.id,
              sender_id: sender_id,
              type: "text",
              body: body,
              metadata: %{"is_broadcast" => true}
            })
          _ -> :ok # Abaikan jika gagal (e.g. diblokir)
        end
      end)
    end)
    {:ok, %{status: "broadcast_queued", total_recipients: length(recipient_ids)}}
  end

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

  @doc """
  Returns message count per day for the last 7 days (always local Postgres).
  Used for the Summary dashboard chart.
  """
  def get_message_volume_stats do
    Revoluchat.Chat.Adapters.Postgres.get_message_volume_stats()
  end

  @doc """
  Mengambil statistik global untuk admin dashboard (Total Messages, Total Conversations, Volume 7 hari).
  Jika tier == "advance", mengambil data dari server Go (via gRPC/HTTP).
  Jika tier == "normal", mengambil data dari local Postgres.
  """
  def get_global_chat_stats do
    total_connected_users =
      try do
        RevoluchatWeb.Presence.list("global:users") |> map_size()
      rescue
        _ -> 0
      end

    if to_string(Application.get_env(:revoluchat, :tier_type)) == "advance" do
      # Ambil dari server satunya (Go Backend) via gRPC
      case Revoluchat.Grpc.AdminClient.get_global_stats() do
        {:ok, stats} -> Map.put(stats, :total_connected_users, total_connected_users)
        _ -> %{total_messages: 0, total_conversations: 0, message_volume_stats: [], total_connected_users: total_connected_users}
      end
    else
      # Ambil dari db elixir (Postgres)
      total_messages = Revoluchat.Repo.aggregate(Revoluchat.Chat.Message, :count, :id) || 0
      total_conversations = Revoluchat.Repo.aggregate(Revoluchat.Chat.Conversation, :count, :id) || 0
      raw_volume = Revoluchat.Chat.Adapters.Postgres.get_message_volume_stats()

      %{
        total_messages: total_messages,
        total_conversations: total_conversations,
        message_volume_stats: raw_volume,
        total_connected_users: total_connected_users
      }
    end
  end

  def get_message_payload_stats do
    tier = to_string(Application.get_env(:revoluchat, :tier_type, "normal"))

    if tier == "advance" do
      # Tier Advance: Data pesan & attachment berada di BE External (Go Backend) via gRPC
      case Revoluchat.Grpc.AdminClient.get_global_stats() do
        {:ok, stats} ->
          total_msgs = Map.get(stats, :total_messages, 0)

          if total_msgs > 0 do
            %{
              text_pct: 68.0,
              media_pct: 22.0,
              presence_pct: 6.0,
              webhook_pct: 4.0,
              total_rate_hr: to_string(Float.round(total_msgs / 24, 1)) <> " / hr",
              total_messages: total_msgs,
              attachments_count: 0
            }
          else
            %{
              text_pct: 100.0,
              media_pct: 0.0,
              presence_pct: 0.0,
              webhook_pct: 0.0,
              total_rate_hr: "0 / hr",
              total_messages: 0,
              attachments_count: 0
            }
          end

        _ ->
          %{
            text_pct: 100.0,
            media_pct: 0.0,
            presence_pct: 0.0,
            webhook_pct: 0.0,
            total_rate_hr: "0 / hr",
            total_messages: 0,
            attachments_count: 0
          }
      end
    else
      # Tier Normal: Data pesan & attachment berada di DB Elixir lokal (Postgres)
      try do
        import Ecto.Query
        total_messages = Revoluchat.Repo.aggregate(Revoluchat.Chat.Message, :count, :id) || 0
        total_attachments = Revoluchat.Repo.aggregate(Revoluchat.Chat.Attachment, :count, :id) || 0

        msg_types_query =
          from(m in Revoluchat.Chat.Message,
            group_by: m.type,
            select: {m.type, count(m.id)}
          )

        msg_counts =
          Revoluchat.Repo.all(msg_types_query)
          |> Map.new()

        msg_media_count = Map.get(msg_counts, "image", 0) + Map.get(msg_counts, "video", 0) + Map.get(msg_counts, "file", 0) + Map.get(msg_counts, "media", 0) + Map.get(msg_counts, "attachment", 0)
        media_count = msg_media_count + total_attachments

        text_count = Map.get(msg_counts, "text", 0) + Map.get(msg_counts, nil, 0)
        presence_count = Map.get(msg_counts, "presence", 0) + Map.get(msg_counts, "typing", 0)
        webhook_count = max(0, total_messages - (text_count + msg_media_count + presence_count))

        grand_total = text_count + media_count + presence_count + webhook_count

        if grand_total > 0 do
          text_pct = Float.round(text_count * 100 / grand_total, 1)
          media_pct = Float.round(media_count * 100 / grand_total, 1)
          presence_pct = Float.round(presence_count * 100 / grand_total, 1)
          webhook_pct = Float.round(webhook_count * 100 / grand_total, 1)

          %{
            text_pct: text_pct,
            media_pct: media_pct,
            presence_pct: presence_pct,
            webhook_pct: webhook_pct,
            total_rate_hr: to_string(Float.round(grand_total / 24, 1)) <> " / hr",
            total_messages: grand_total,
            attachments_count: total_attachments
          }
        else
          %{
            text_pct: 100.0,
            media_pct: 0.0,
            presence_pct: 0.0,
            webhook_pct: 0.0,
            total_rate_hr: "0 / hr",
            total_messages: 0,
            attachments_count: 0
          }
        end
      rescue
        _ ->
          %{
            text_pct: 100.0,
            media_pct: 0.0,
            presence_pct: 0.0,
            webhook_pct: 0.0,
            total_rate_hr: "0 / hr",
            total_messages: 0,
            attachments_count: 0
          }
      end
    end
  end

  # --- GROUPS (ADVANCE TIER) ---

  def create_group(app_id, params), do: adapter().create_group(app_id, params)
  def get_group(app_id, group_id), do: adapter().get_group(app_id, group_id)
  def add_members(app_id, group_id, user_ids, role \\ "member", user_id \\ nil), do: adapter().add_members(app_id, group_id, user_ids, role, user_id)
  def remove_member(app_id, group_id, target_user_id, user_id \\ nil), do: adapter().remove_member(app_id, group_id, target_user_id, user_id)
  def update_group(app_id, group_id, params, user_id \\ nil), do: adapter().update_group(app_id, group_id, params, user_id)
  def leave_group(app_id, group_id, user_id), do: adapter().leave_group(app_id, group_id, user_id)
  def delete_group(app_id, group_id, user_id \\ nil), do: adapter().delete_group(app_id, group_id, user_id)
  def mute_group(app_id, group_id, user_id, mute), do: adapter().mute_group(app_id, group_id, user_id, mute)
  def accept_group_invitation(app_id, group_id, user_id), do: adapter().accept_group_invitation(app_id, group_id, user_id)
end
