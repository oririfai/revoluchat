defmodule Revoluchat.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @max_body_length 10_000

  schema "messages" do
    field(:app_id, :string)
    field(:type, :string)
    field(:body, :string)
    field(:is_encrypted, :boolean, default: false)
    field(:client_id, :string)
    field(:delivered_at, :utc_datetime_usec)
    field(:read_at, :utc_datetime_usec)
    field(:edited_at, :utc_datetime_usec)
    field(:deleted_at, :utc_datetime_usec)
    # sender_id adalah integer (uint dari MySQL user service)
    field(:sender_id, :integer)

    field(:status, :string, virtual: true, default: "sent")
    field(:metadata, :map)
    field(:attachment_ids, {:array, :binary_id}, default: [])

    belongs_to(:conversation, Revoluchat.Chat.Conversation)
    belongs_to(:attachment, Revoluchat.Chat.Attachment)
    belongs_to(:reply_to, Revoluchat.Chat.Message, foreign_key: :reply_to_id)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :app_id,
      :type,
      :body,
      :metadata,
      :is_encrypted,
      :client_id,
      :sender_id,
      :conversation_id,
      :attachment_id,
      :attachment_ids,
      :reply_to_id
    ])
    |> validate_required([:app_id, :type, :conversation_id, :sender_id])
    |> validate_inclusion(:type, ["text", "attachment", "system_call_summary"],
      message: "harus 'text', 'attachment', atau 'system_call_summary'"
    )
    |> validate_length(:body, max: @max_body_length)
    |> validate_no_html(:body)
    |> validate_body_or_attachment()
    |> unique_constraint(:client_id)
    |> foreign_key_constraint(:conversation_id)
    |> foreign_key_constraint(:sender_id)
    |> foreign_key_constraint(:attachment_id)
  end

  def soft_delete_changeset(message) do
    change(message, deleted_at: DateTime.utc_now())
  end

  def mark_delivered_changeset(message) do
    change(message, delivered_at: DateTime.utc_now())
  end

  def mark_read_changeset(message) do
    change(message, read_at: DateTime.utc_now())
  end

  # ─── Private validators ───────────────────────────────────────────────────────

  defp validate_body_or_attachment(changeset) do
    type = get_field(changeset, :type)
    body = get_field(changeset, :body)
    attachment_id = get_field(changeset, :attachment_id)
    attachment_ids = get_field(changeset, :attachment_ids)

    cond do
      type == "text" && (is_nil(body) || String.trim(body) == "") ->
        add_error(changeset, :body, "wajib diisi untuk tipe text")

      type == "attachment" && is_nil(attachment_id) && (is_nil(attachment_ids) || attachment_ids == []) ->
        add_error(changeset, :attachment_id, "wajib diisi untuk tipe attachment (singular atau plural)")

      type == "system_call_summary" ->
        changeset
        
      true ->
        changeset
    end
  end

  defp validate_no_html(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      body ->
        if String.match?(body, ~r/<[^>]+>/),
          do: add_error(changeset, field, "HTML tidak diizinkan"),
          else: changeset
    end
  end
end
