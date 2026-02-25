defmodule Revoluchat.Repo.Migrations.CreatePushTokens do
  use Ecto.Migration

  def change do
    create table(:push_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      # user_id adalah integer (uint dari MySQL user service)
      add :user_id, :integer, null: false
      add :platform, :string, null: false
      add :token, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:push_tokens, [:user_id])
    create unique_index(:push_tokens, [:token])

    create constraint(:push_tokens, :valid_platform, check: "platform IN ('fcm', 'apns')")
  end
end
