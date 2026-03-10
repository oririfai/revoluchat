defmodule Revoluchat.Repo.Migrations.CreateCallsTable do
  use Ecto.Migration

  def change do
    create table(:calls, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:app_id, :string, null: false)
      add(:conversation_id, references(:conversations, on_delete: :nothing, type: :binary_id))
      add(:caller_id, :integer, null: false)
      add(:receiver_id, :integer, null: false)
      # "audio", "video"
      add(:type, :string, null: false)
      # "dialing", "ringing", "connected", "missed", "rejected", "completed"
      add(:status, :string, null: false)
      add(:started_at, :utc_datetime)
      add(:ended_at, :utc_datetime)
      add(:duration_seconds, :integer)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:calls, [:app_id]))
    create(index(:calls, [:conversation_id]))
    create(index(:calls, [:caller_id]))
    create(index(:calls, [:receiver_id]))
    create(index(:calls, [:status]))
  end
end
