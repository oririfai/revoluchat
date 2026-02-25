defmodule Revoluchat.Chat.Attachment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ~w(pending approved rejected)

  schema "attachments" do
    field :app_id, :string
    field :metadata, :map
    field :storage_key, :string
    field :mime_type, :string
    field :size, :integer
    field :checksum, :string
    field :status, :string, default: "pending"
    # uploader_id adalah integer (uint dari MySQL user service)
    field :uploader_id, :integer

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [
      :app_id,
      :uploader_id,
      :storage_key,
      :mime_type,
      :size,
      :checksum,
      :status,
      :metadata
    ])
    |> validate_required([:app_id, :uploader_id, :storage_key, :mime_type, :size])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:size, greater_than: 0)
    |> unique_constraint(:storage_key)
  end

  def approve_changeset(attachment) do
    change(attachment, status: "approved")
  end

  def reject_changeset(attachment) do
    change(attachment, status: "rejected")
  end

  def set_checksum_changeset(attachment, checksum) do
    change(attachment, checksum: checksum)
  end
end
