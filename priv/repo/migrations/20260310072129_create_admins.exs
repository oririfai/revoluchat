defmodule Revoluchat.Repo.Migrations.CreateAdmins do
  use Ecto.Migration

  def change do
    create table(:admins) do
      add(:email, :string, null: false)
      add(:password_hash, :string, null: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:admins, [:email]))
  end
end
