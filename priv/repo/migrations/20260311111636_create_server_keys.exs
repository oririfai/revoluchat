defmodule Revoluchat.Repo.Migrations.CreateServerKeys do
  use Ecto.Migration

  def change do
    create table(:server_keys) do
      add :name, :string
      add :key, :string
      add :status, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:server_keys, [:key])
  end
end
