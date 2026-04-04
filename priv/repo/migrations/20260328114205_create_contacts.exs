defmodule Revoluchat.Repo.Migrations.CreateContacts do
  use Ecto.Migration

  def change do
    create table(:contacts) do
      add :owner_id, :integer, null: false
      add :contact_id, :integer, null: false
      add :app_id, :string, null: false
      add :status, :string, default: "added"

      timestamps()
    end

    create index(:contacts, [:owner_id, :app_id])
    create unique_index(:contacts, [:owner_id, :contact_id, :app_id])
  end
end
