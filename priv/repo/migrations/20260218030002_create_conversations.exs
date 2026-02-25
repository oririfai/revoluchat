defmodule Revoluchat.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      # user_id adalah integer (uint dari MySQL user service)
      add :user_a_id, :integer, null: false
      add :user_b_id, :integer, null: false
      add :last_message_id, :binary_id
      add :last_activity_at, :utc_datetime_usec, default: fragment("NOW()")

      timestamps(type: :utc_datetime_usec)
    end

    # Constraint: user_a_id < user_b_id (deterministic ordering — cegah duplikat A-B vs B-A)
    create constraint(:conversations, :user_ordering, check: "user_a_id < user_b_id")

    # Satu conversation per pasang user
    create unique_index(:conversations, [:user_a_id, :user_b_id])
    create index(:conversations, [:last_activity_at])
    create index(:conversations, [:user_a_id])
    create index(:conversations, [:user_b_id])
  end
end
