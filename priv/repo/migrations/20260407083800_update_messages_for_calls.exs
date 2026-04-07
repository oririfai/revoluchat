defmodule Revoluchat.Repo.Migrations.UpdateMessagesForCalls do
  use Ecto.Migration

  def change do
    # 1. Update messages table: Add metadata and modify constraints
    alter table(:messages) do
      add :metadata, :map
    end

    # Drop old constraints to update them
    drop constraint(:messages, :valid_type)
    drop constraint(:messages, :body_or_attachment)

    # Re-create constraints with new allowed type
    create constraint(:messages, :valid_type, check: "type IN ('text', 'attachment', 'system_call_summary')")

    create constraint(:messages, :body_or_attachment,
             check:
               "(type = 'text' AND body IS NOT NULL) OR (type = 'attachment' AND attachment_id IS NOT NULL) OR (type = 'system_call_summary')"
           )

    # 2. Create call_histories table
    create table(:call_histories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :app_id, :string, null: false
      
      # The owner who sees this record in their history
      add :user_id, :integer, null: false
      
      # The other party in the call
      add :other_party_id, :integer, null: false
      
      # "incoming", "outgoing"
      add :direction, :string, null: false
      
      # "audio", "video"
      add :type, :string, null: false
      
      # "missed", "rejected", "completed"
      add :status, :string, null: false
      
      add :duration_seconds, :integer, default: 0
      add :started_at, :utc_datetime, null: false
      
      # Reference to the original conversation for "Call Back" feature
      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :nothing)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:call_histories, [:app_id])
    create index(:call_histories, [:user_id, :inserted_at])
  end
end
