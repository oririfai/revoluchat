defmodule Revoluchat.Repo.Migrations.AddRoleAndPermissionsToAdmins do
  use Ecto.Migration

  def change do
    alter table(:admins) do
      add :role, :string, default: "super_admin", null: false
      add :permissions, {:array, :string}, default: []
    end
  end
end
