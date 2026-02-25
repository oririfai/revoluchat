defmodule Revoluchat.Repo.Migrations.AlterPushTokensForMultiTenancy do
  use Ecto.Migration

  def up do
    alter table(:push_tokens) do
      add :app_id, :string, default: "default_app", null: false
      modify :user_id, :string, null: false
    end

    create index(:push_tokens, [:app_id, :user_id])
  end

  def down do
    drop index(:push_tokens, [:app_id, :user_id])

    alter table(:push_tokens) do
      remove :app_id
      modify :user_id, :integer, null: false
    end
  end
end
