defmodule Revoluchat.Repo.Migrations.AddAppIdToChatTables do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      add :app_id, :string, null: false, default: "default_app"
    end

    alter table(:messages) do
      add :app_id, :string, null: false, default: "default_app"
    end

    alter table(:attachments) do
      add :app_id, :string, null: false, default: "default_app"
    end

    # Create indexes for fast lookup by tenant
    create index(:conversations, [:app_id])
    create index(:messages, [:app_id, :conversation_id])
    create index(:attachments, [:app_id])
  end
end
