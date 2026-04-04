defmodule Revoluchat.Repo.Migrations.DropLicensesTable do
  use Ecto.Migration

  def up do
    drop table(:licenses)
  end

  def down do
    create table(:licenses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :license_key, :text, null: false
      add :status, :string, default: "active", null: false
      add :valid_until, :utc_datetime, null: false
      add :features, :map, default: %{}
      add :raw_jwt, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:licenses, [:license_key])
  end
end
