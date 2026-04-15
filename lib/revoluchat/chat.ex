defmodule Revoluchat.Chat do
  @moduledoc """
  Context untuk conversation dan message management.
  """

  import Ecto.Query
  alias Revoluchat.Repo
  alias Revoluchat.Chat.{Conversation, Message, Attachment}
  alias Revoluchat.Storage

  # ─── Conversations ────────────────────────────────────────────────────────────

  @doc """
  Buat atau ambil conversation antara dua user di sebuah aplikasi tertentu.
  user_a_id < user_b_id selalu (deterministic ordering).
  """
  def get_or_create_conversation(app_id, user_a_id, user_b_id) do
    # Enforce ordering: a < b
    {a, b} =
      if user_a_id < user_b_id,
        do: {user_a_id, user_b_id},
        else: {user_b_id, user_a_id}

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

  @doc """
  Ambil conversation hanya jika user adalah member.
  Dipakai di Channel join untuk authorization.
  """
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
      nil ->
        {:error, :not_found}

      conv ->
        {:ok, conv}
    end
  end

  def list_user_conversations(app_id, user_id, opts \\ []) do
    search_term = Keyword.get(opts, :search)

    # Subquery for unread messages count
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
        where: c.user_a_id == ^user_id or c.user_b_id == ^user_id
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

    conversations =
      query
      |> order_by([c], desc: c.last_activity_at)
      |> preload(:last_message)
      |> select_merge([c], %{unread_count: subquery(unread_query)})
      |> Repo.all()

    conversations
  end

  def get_conversation!(app_id, id), do: Repo.get_by!(Conversation, app_id: app_id, id: id)

  # ─── Messages ─────────────────────────────────────────────────────────────────

  @doc """
  Insert message — persist first, broadcast second (aturan wajib).
  Idempotent via client_id: jika sudah ada, kembalikan message yang ada.
  """
  def insert_message(attrs) do
    changeset = Message.changeset(%Message{}, attrs)

    case Repo.insert(changeset) do
      {:ok, message} ->
        # Update last_activity di conversation
        update_conversation_activity(attrs.conversation_id, message.id)

        # Preload attachment agar tidak crash saat diformat
        message = Repo.preload(message, :attachment)

        # Enqueue Webhook for incoming message (B2B SDK feature)
        %{
          "event" => "message.created",
          "payload" => %{
            "message_id" => message.id,
            "conversation_id" => message.conversation_id,
            "sender_id" => message.sender_id,
            "body" => message.body,
            "type" => message.type
          }
        }
        |> Revoluchat.Workers.WebhookDispatcher.new()
        |> Oban.insert()

        {:ok, message}

      {:error, %Ecto.Changeset{errors: [client_id: _]} = _changeset} ->
        # Idempotent: client_id sudah ada, kembalikan message yang ada
        existing =
          Repo.get_by!(Message, client_id: attrs[:client_id]) |> Repo.preload(:attachment)

        {:ok, existing}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Cursor-based pagination untuk message history.
  before_id: ambil pesan sebelum message ini (untuk load more).
  """
  def list_messages(app_id, conversation_id, opts \\ []) do
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
        # Ambil inserted_at dari cursor message
        cursor_time = get_message_inserted_at(before_id)

        from(m in query,
          where: m.inserted_at < ^cursor_time
        )
      else
        query
      end

    query =
      if search_term = Keyword.get(opts, :search) do
        search_pattern = "%#{search_term}%"

        from(m in query,
          where: ilike(m.body, ^search_pattern)
        )
      else
        query
      end

    Repo.all(query) |> Enum.reverse()
  end

  def get_message!(id), do: Repo.get!(Message, id)

  def get_message_with_conversation!(message_id) do
    Repo.get!(Message, message_id)
    |> Repo.preload(:conversation)
  end

  def mark_read(app_id, message_id, user_id) do
    with {:ok, message} <- get_message_for_user(app_id, message_id, user_id) do
      # Hanya recipient yang bisa mark read
      if message.sender_id == user_id do
        {:error, :cannot_mark_own_message}
      else
        message
        |> Message.mark_read_changeset()
        |> Repo.update()
      end
    end
  end

  def soft_delete_message(app_id, message_id, user_id) do
    with {:ok, message} <- get_message_for_user(app_id, message_id, user_id) do
      if message.sender_id != user_id do
        {:error, :unauthorized}
      else
        message
        |> Message.soft_delete_changeset()
        |> Repo.update()
      end
    end
  end

  # ─── Attachments ──────────────────────────────────────────────────────────────

  @doc """
  Initiate upload: Create pending attachment record & generate presigned URL.
  Returns {:ok, attachment, upload_url}.
  """
  def create_attachment_init(attrs) do
    uuid = Ecto.UUID.generate()
    filename = attrs["filename"] || "unnamed"
    clean_filename = sanitize_filename(filename)
    ext = Path.extname(clean_filename)
    mime_type = attrs["mime_type"]
    category = get_category_from_mime(mime_type)
    date = Date.to_string(Date.utc_today())
    
    storage_key = "revoluchat/attachments/#{category}/#{date}/#{uuid}#{ext}"

    # Store sanitized filename in metadata
    metadata = 
      (attrs["metadata"] || %{})
      |> Map.put("filename", clean_filename)

    params =
      Map.merge(attrs, %{
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

  defp get_category_from_mime(nil), do: "documents"
  defp get_category_from_mime(mime) do
    cond do
      String.starts_with?(mime, "image/") -> "images"
      String.starts_with?(mime, "audio/") or mime == "application/ogg" -> "audio"
      String.starts_with?(mime, "video/") -> "video"
      true -> "documents"
    end
  end

  defp sanitize_filename(filename) do
    filename
    |> String.replace(~r/[^a-zA-Z0-9.-]/, "_")
  end

  @doc """
  Confirm upload: Verify object exists in storage & update status to approved.
  """
  def confirm_attachment(app_id, id, uploader_id) do
    case Repo.get_by(Attachment, id: id, app_id: app_id) do
      nil ->
        {:error, :not_found}

      attachment ->
        if attachment.uploader_id != uploader_id do
          {:error, :unauthorized}
        else
          # Verify storage existence
          case Storage.head_object(attachment.storage_key) do
            {:ok, _props} ->
              {:ok, updated} =
                attachment
                |> Attachment.approve_changeset()
                |> Repo.update()

              # Enqueue scan job
              %{attachment_id: updated.id}
              |> Revoluchat.Workers.AttachmentScanWorker.new()
              |> Oban.insert()

              {:ok, updated}

            {:error, {:http_error, 404, _}} ->
              {:error, :file_not_found_in_storage}

            {:error, reason} ->
              {:error, reason}
          end
        end
    end
  end

  @doc """
  Generate presigned download URL for an approved attachment.
  Strict access control: uploader OR participant in a conversation using this attachment.
  """
  def get_attachment_download_url(app_id, attachment_id, user_id) do
    with {:ok, attachment} <- get_approved_attachment_for_user(app_id, attachment_id, user_id) do
      case Storage.presigned_get_url(attachment.storage_key) do
        {:ok, url} -> {:ok, url}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # ─── Private ─────────────────────────────────────────────────────────────────

  defp get_message_for_user(app_id, message_id, user_id) do
    query =
      from(m in Message,
        join: c in Conversation,
        on: m.conversation_id == c.id,
        where: m.app_id == ^app_id and m.id == ^message_id,
        where: c.user_a_id == ^user_id or c.user_b_id == ^user_id
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      message -> {:ok, message}
    end
  end

  defp get_approved_attachment_for_user(app_id, attachment_id, user_id) do
    # 1. Check if uploader
    case Repo.get_by(Attachment, id: attachment_id, app_id: app_id, status: "approved") do
      %Attachment{uploader_id: ^user_id} = att ->
        {:ok, att}

      att when not is_nil(att) ->
        # 2. Check if participant in any conversation containing this attachment
        is_participant =
          from(m in Message,
            join: c in Conversation,
            on: m.conversation_id == c.id,
            where: m.attachment_id == ^attachment_id,
            where: c.user_a_id == ^user_id or c.user_b_id == ^user_id
          )
          |> Repo.exists?()

        if is_participant, do: {:ok, att}, else: {:error, :not_found}

      nil ->
        {:error, :not_found}
    end
  end

  defp get_approved_attachment(id) do
    case Repo.get(Attachment, id) do
      nil -> {:error, :not_found}
      %Attachment{status: "approved"} = att -> {:ok, att}
      _ -> {:error, :not_found}
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

  # ─── Analytics ──────────────────────────────────────────────────────────────

  def count_messages_for_app(app_id) do
    from(m in Message, where: m.app_id == ^app_id)
    |> Repo.aggregate(:count, :id)
  end

  def count_active_conversations(app_id) do
    from(c in Conversation, where: c.app_id == ^app_id and not is_nil(c.last_activity_at))
    |> Repo.aggregate(:count, :id)
  end
end
