defmodule Revoluchat.Repo.Migrations.AddCreatedByToAdmins do
  use Ecto.Migration

  def change do
    alter table(:admins) do
      add :created_by, :string, default: "System"
    end
  end
end
