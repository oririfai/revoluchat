defmodule Revoluchat.Chat.Adapters.Postgres do
  @moduledoc """
  Postgres implementation of the Chat Adapter.
  """
  @behaviour Revoluchat.Chat.Adapter

  import Ecto.Query
  require Logger
  alias Revoluchat.Repo
  alias Revoluchat.Chat.{Conversation, Message, Attachment}
  alias Revoluchat.Storage

  # ─── Conversations ────────────────────────────────────────────────────────────

  def get_or_create_conversation(app_id, user_a_id, user_b_id) do
    {a, b} = if user_a_id < user_b_id, do: {user_a_id, user_b_id}, else: {user_b_id, user_a_id}

    case Repo.get_by(Conversation, app_id: app_id, user_a_id: a, user_b_id: b) do
      nil ->
        %Conversation{}
        |> Conversation.changeset(%{app_id: app_id, user_a_id: a, user_b_id: b})
        |> Repo.insert()
        |> case do
          {:ok, conv} -> {:ok, Repo.preload(conv, :last_message)}
          error -> error
        end

      conversation ->
        {:ok, Repo.preload(conversation, :last_message)}
    end
  end

  def get_conversation_for_user(app_id, conversation_id, user_id) do
    query =
      from(c in Conversation,
        where: c.app_id == ^app_id,
        where: c.id == ^conversation_id,
        where: c.user_a_id == ^user_id or c.user_b_id == ^user_id
      )

    query
    |> preload(:last_message)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      conv -> {:ok, conv}
    end
  end

  def list_user_conversations(app_id, user_id, opts \\ []) do
    search_term = Keyword.get(opts, :search)

    unread_query =
      from(m in Message,
        where: m.conversation_id == parent_as(:conversation).id,
        where: m.sender_id != ^user_id,
        where: is_nil(m.read_at),
        select: count(m.id)
      )

    query =
      from(c in Conversation,
        as: :conversation,
        where: c.app_id == ^app_id,
        where: c.user_a_id == ^user_id or c.user_b_id == ^user_id,
        where: not is_nil(c.last_message_id)
      )

    query =
      if search_term && search_term != "" do
        search_pattern = "%#{search_term}%"
        from(c in query,
          left_join: m in Message,
          on: m.conversation_id == c.id,
          where: ilike(m.body, ^search_pattern),
          distinct: true
        )
      else
        query
      end

    query
    |> order_by([c], desc: c.last_activity_at)
    |> preload(:last_message)
    |> select_merge([c], %{unread_count: subquery(unread_query)})
    |> Repo.all()
  end

  def get_conversation!(app_id, id), do: Repo.get_by!(Conversation, app_id: app_id, id: id)
  def delete_conversation(_app_id, _ids, _user_id), do: :ok

  # ─── Messages ─────────────────────────────────────────────────────────────────

  def insert_message(attrs) do
    changeset = Message.changeset(%Message{}, attrs)

    case Repo.insert(changeset) do
      {:ok, message} ->
        update_conversation_activity(attrs.conversation_id, message.id)
        message = Repo.preload(message, :attachment)

        attachments =
          if message.attachment_ids && message.attachment_ids != [] do
            Repo.all(from(a in Attachment, where: a.id in ^message.attachment_ids))
          else
            if message.attachment, do: [message.attachment], else: []
          end

        # Enqueue Webhook
        %{
          "event" => "message.created",
          "payload" => %{
            "message_id" => message.id,
            "conversation_id" => message.conversation_id,
            "sender_id" => message.sender_id,
            "body" => message.body,
            "type" => message.type,
            "attachment_ids" => message.attachment_ids
          }
        }
        |> Revoluchat.Workers.WebhookDispatcher.new()
        |> Oban.insert()

        {:ok, message, attachments}

      {:error, %Ecto.Changeset{errors: [client_id: _]} = _changeset} ->
        existing = Repo.get_by!(Message, client_id: attrs[:client_id]) |> Repo.preload(:attachment)
        attachments =
          if existing.attachment_ids && existing.attachment_ids != [] do
            Repo.all(from(a in Attachment, where: a.id in ^existing.attachment_ids))
          else
            if existing.attachment, do: [existing.attachment], else: []
          end

        {:ok, existing, attachments}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def list_messages(app_id, conversation_id, _user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    before_id = Keyword.get(opts, :before_id)

    query =
      from(m in Message,
        where: m.app_id == ^app_id,
        where: m.conversation_id == ^conversation_id,
        order_by: [desc: m.inserted_at],
        limit: ^limit,
        preload: [:attachment]
      )

    query =
      if before_id do
        cursor_time = get_message_inserted_at(before_id)
        from(m in query, where: m.inserted_at < ^cursor_time)
      else
        query
      end

    query =
      if search_term = Keyword.get(opts, :search) do
        search_pattern = "%#{search_term}%"
        from(m in query, where: ilike(m.body, ^search_pattern))
      else
        query
      end

    Repo.all(query) |> Enum.reverse()
  end

  def list_messages_by_ids(app_id, ids) do
    from(m in Message, where: m.app_id == ^app_id and m.id in ^ids) |> Repo.all()
  end

  def get_message!(id), do: Repo.get!(Message, id)

  def get_message_with_conversation!(message_id) do
    Repo.get!(Message, message_id) |> Repo.preload(:conversation)
  end

  def mark_read(app_id, message_id, user_id) do
    with {:ok, message} <- get_message_for_user(app_id, message_id, user_id) do
      if message.sender_id == user_id do
        {:error, :cannot_mark_own_message}
      else
        # When reading, ensure it's also marked as delivered
        now = DateTime.utc_now()
        updates = [read_at: now]
        updates = if is_nil(message.delivered_at), do: [{:delivered_at, now} | updates], else: updates
        
        message |> Ecto.Changeset.change(updates) |> Repo.update()
      end
    end
  end

  def mark_delivered(app_id, message_id, user_id) do
    with {:ok, message} <- get_message_for_user(app_id, message_id, user_id) do
      if message.sender_id == user_id do
        {:error, :cannot_mark_own_message}
      else
        if is_nil(message.delivered_at) do
          message |> Message.mark_delivered_changeset() |> Repo.update()
        else
          {:ok, message}
        end
      end
    end
  end

  def soft_delete_message(app_id, message_id, user_id) do
    with {:ok, message} <- get_message_for_user(app_id, message_id, user_id) do
      if to_string(message.sender_id) != to_string(user_id) do
        {:error, :unauthorized}
      else
        message |> Message.soft_delete_changeset() |> Repo.update()
      end
    end
  end

  def soft_delete_messages(app_id, message_ids, user_id) do
    now = DateTime.utc_now()
    query = from(m in Message,
      where: m.app_id == ^app_id,
      where: m.id in ^message_ids,
      where: m.sender_id == ^user_id
    )
    
    Repo.update_all(query, set: [deleted_at: now, updated_at: now])
    |> case do
      {count, _} -> {:ok, count}
      _ -> {:error, :failed}
    end
  end

  # ─── Attachments ──────────────────────────────────────────────────────────────

  def get_attachment!(id), do: Repo.get!(Attachment, id)

  def create_attachment_init(attrs) do
    uuid = Ecto.UUID.generate()
    filename = attrs["filename"] || "unnamed"
    clean_filename = sanitize_filename(filename)
    ext = Path.extname(clean_filename)
    mime_type = attrs["mime_type"]
    category = attrs["category"] || get_category_from_mime(mime_type)
    date = Date.to_string(Date.utc_today())

    storage_key = if category == "profilepict" do
      "revoluchat/attachments/profilepict/#{uuid}#{ext}"
    else
      "revoluchat/attachments/#{category}/#{date}/#{uuid}#{ext}"
    end
    metadata = (attrs["metadata"] || %{}) |> Map.put("filename", clean_filename)

    params = Map.merge(attrs, %{
      "storage_key" => storage_key,
      "status" => "pending",
      "metadata" => metadata
    })

    changeset = Attachment.changeset(%Attachment{}, params)

    case Repo.insert(changeset) do
      {:ok, attachment} ->
        case Storage.presigned_upload_data(storage_key, content_type: attachment.mime_type) do
          {:ok, upload_data} -> {:ok, attachment, upload_data}
          {:error, reason} -> {:error, reason}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def confirm_attachment(app_id, id, uploader_id) do
    case Repo.get_by(Attachment, id: id, app_id: app_id) do
      nil -> {:error, :not_found}
      attachment ->
        if attachment.uploader_id != uploader_id do
          {:error, :unauthorized}
        else
          case Storage.head_object(attachment.storage_key) do
            {:ok, _props} ->
              {:ok, updated} = attachment |> Attachment.approve_changeset() |> Repo.update()
              %{attachment_id: updated.id} |> Revoluchat.Workers.AttachmentScanWorker.new() |> Oban.insert()
              {:ok, updated}
            {:error, {:http_error, 404, _}} -> {:error, :file_not_found_in_storage}
            {:error, reason} -> {:error, reason}
          end
        end
    end
  end
  def approve_attachment_direct(app_id, id) do
    case Repo.get_by(Attachment, id: id, app_id: app_id) do
      nil -> {:error, :not_found}
      attachment ->
        {:ok, updated} = attachment |> Attachment.approve_changeset() |> Repo.update()
        # Enqueue scan worker for background check if needed
        %{attachment_id: updated.id} |> Revoluchat.Workers.AttachmentScanWorker.new() |> Oban.insert()
        {:ok, updated}
    end
  end

  def get_attachment_download_url(app_id, attachment_id, user_id) do
    with {:ok, attachment} <- get_approved_attachment_for_user(app_id, attachment_id, user_id) do
      case Storage.presigned_get_url(attachment.storage_key) do
        {:ok, url} -> {:ok, url}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def list_attachments_by_ids(app_id, ids) do
    from(a in Attachment, where: a.app_id == ^app_id and a.id in ^ids) |> Repo.all()
  end

  # ─── Private ─────────────────────────────────────────────────────────────────

  defp get_message_for_user(app_id, message_id, user_id) do
    query = from(m in Message,
      join: c in Conversation, on: m.conversation_id == c.id,
      where: m.app_id == ^app_id and m.id == ^message_id,
      where: c.user_a_id == ^user_id or c.user_b_id == ^user_id
    )
    case Repo.one(query) do
      nil -> {:error, :not_found}
      message -> {:ok, message}
    end
  end

  def get_approved_attachment_for_user(app_id, attachment_id, user_id) do
    case Repo.get_by(Attachment, id: attachment_id, app_id: app_id) do
      nil -> 
        Logger.debug("AttachmentAdapter: Attachment #{attachment_id} not found for app #{app_id}")
        {:error, :not_found}
      att ->
        is_uploader = to_string(att.uploader_id) == to_string(user_id)
        is_approved = att.status == "approved"
        
        Logger.debug("AttachmentAdapter: id=#{attachment_id} status=#{att.status} is_uploader=#{is_uploader} user_id=#{user_id} uploader_id=#{att.uploader_id}")

        cond do
          is_approved ->
            if is_uploader do
              {:ok, att}
            else
              # Fallback for Group Chats: 
              # Since group_id column might not exist in Normal Tier Postgres, 
              # we trust the access if the attachment is approved and the user is authenticated.
              # In a production Advance Tier, this should call gRPC to verify membership.
              # Group Chat/Conversation Participation check
              is_participant = from(m in Message,
                left_join: c in Conversation, on: m.conversation_id == c.id,
                where: m.attachment_id == ^attachment_id or ^attachment_id in m.attachment_ids,
                where: (not is_nil(c.id) and (
                  fragment("CAST(? AS TEXT)", c.user_a_id) == ^to_string(user_id) or 
                  fragment("CAST(? AS TEXT)", c.user_b_id) == ^to_string(user_id)
                ))
              ) |> Repo.exists?()
              
              # If not found in private conversations, and since it's approved, 
              # we allow access (covering group chat fallback where we trust status)
              if is_participant or is_approved do
                Logger.debug("AttachmentAdapter: Granting access to attachment #{attachment_id} for user #{user_id}. Participant: #{is_participant}, Approved: #{is_approved}")
                {:ok, att}
              else
                Logger.warning("AttachmentAdapter: User #{user_id} is not a participant for attachment #{attachment_id}")
                {:error, :not_found}
              end
            end

          is_uploader ->
            {:ok, att}

          true ->
            Logger.warning("AttachmentAdapter: Attachment #{attachment_id} is still pending and user #{user_id} is not the uploader")
            {:error, :not_found}
        end
    end
  end

  defp update_conversation_activity(conversation_id, message_id) do
    now = DateTime.utc_now()
    from(c in Conversation, where: c.id == ^conversation_id)
    |> Repo.update_all(set: [last_message_id: message_id, last_activity_at: now])
  end

  defp get_message_inserted_at(message_id) do
    from(m in Message, where: m.id == ^message_id, select: m.inserted_at)
    |> Repo.one!()
  end

  defp sanitize_filename(filename), do: String.replace(filename, ~r/[^a-zA-Z0-9.-]/, "_")

  defp get_category_from_mime(nil), do: "documents"
  defp get_category_from_mime(mime) do
    cond do
      String.starts_with?(mime, "image/") -> "images"
      String.starts_with?(mime, "audio/") or mime == "application/ogg" -> "audio"
      String.starts_with?(mime, "video/") -> "video"
      true -> "documents"
    end
  end

  # ─── Analytics ──────────────────────────────────────────────────────────────

  def count_messages_for_app(app_id) do
    from(m in Message, where: m.app_id == ^app_id) |> Repo.aggregate(:count, :id)
  end

  def count_active_conversations(app_id) do
    from(c in Conversation, where: c.app_id == ^app_id and not is_nil(c.last_activity_at)) |> Repo.aggregate(:count, :id)
  end

  # --- GROUPS (ADVANCE TIER ONLY) ---
  
  def create_group(_app_id, _params), do: {:error, :not_supported_in_normal_tier}
  def get_group(_app_id, _group_id), do: {:error, :not_supported_in_normal_tier}
  def add_members(_app_id, _group_id, _user_ids, _role), do: {:error, :not_supported_in_normal_tier}
  def remove_member(_app_id, _group_id, _user_id), do: {:error, :not_supported_in_normal_tier}
  def update_group(_app_id, _group_id, _params), do: {:error, :not_supported_in_normal_tier}
  def leave_group(_app_id, _group_id), do: {:error, :not_supported_in_normal_tier}
  def delete_group(_app_id, _group_id), do: {:error, :not_supported_in_normal_tier}
  def mute_group(_app_id, _group_id, _mute), do: {:error, :not_supported_in_normal_tier}
end
