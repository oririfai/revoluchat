defmodule Revoluchat.Repo.Migrations.CreateApiKeysTable do
  use Ecto.Migration

  def change do
    create table(:api_keys) do
      add(:name, :string, null: false)
      add(:key, :string, null: false)
      add(:status, :string, null: false, default: "active")
      add(:app_id, :string, null: false, default: "default_app")

      timestamps()
    end

    create(unique_index(:api_keys, [:key]))
    create(index(:api_keys, [:app_id]))
  end
end
