defmodule Revoluchat.Repo.Migrations.CreateAttachments do
  use Ecto.Migration

  def change do
    create table(:attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      # uploader_id adalah integer (uint dari MySQL user service)
      add :uploader_id, :integer, null: false
      add :storage_key, :string, null: false
      add :mime_type, :string, null: false
      add :size, :integer, null: false
      add :checksum, :string
      add :status, :string, null: false, default: "pending"

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:attachments, [:storage_key])
    create index(:attachments, [:uploader_id])
    create index(:attachments, [:status])

    create constraint(:attachments, :valid_status,
             check: "status IN ('pending', 'approved', 'rejected')"
           )
  end
end
