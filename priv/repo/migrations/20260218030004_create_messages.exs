defmodule Revoluchat.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      # sender_id adalah integer (uint dari MySQL user service)
      add :sender_id, :integer, null: false
      add :attachment_id, references(:attachments, type: :binary_id, on_delete: :nilify_all)
      add :reply_to_id, :binary_id
      add :type, :string, null: false
      add :body, :text
      add :client_id, :string
      add :delivered_at, :utc_datetime_usec
      add :read_at, :utc_datetime_usec
      add :edited_at, :utc_datetime_usec
      add :deleted_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:messages, [:conversation_id, :inserted_at])
    create index(:messages, [:sender_id])
    create index(:messages, [:reply_to_id], where: "reply_to_id IS NOT NULL")
    create unique_index(:messages, [:client_id], where: "client_id IS NOT NULL")

    # Full-text search index untuk future search feature
    execute(
      "CREATE INDEX idx_messages_body_fts ON messages USING gin(to_tsvector('english', body)) WHERE body IS NOT NULL AND deleted_at IS NULL",
      "DROP INDEX IF EXISTS idx_messages_body_fts"
    )

    create constraint(:messages, :valid_type, check: "type IN ('text', 'attachment')")

    create constraint(:messages, :body_or_attachment,
             check:
               "(type = 'text' AND body IS NOT NULL) OR (type = 'attachment' AND attachment_id IS NOT NULL)"
           )
  end
end
