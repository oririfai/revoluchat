defmodule Revoluchat.Repo.Migrations.CreateAdminLoginActivities do
  use Ecto.Migration

  def change do
    create table(:admin_login_activities) do
      add :admin_id, references(:admins, on_delete: :nilify_all), null: true
      add :email, :string, null: true
      add :ip_address, :string, null: false
      add :user_agent, :text, null: false
      add :device_os, :string, null: false
      add :device_browser, :string, null: false
      add :status, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:admin_login_activities, [:admin_id])
    create index(:admin_login_activities, [:ip_address])
    create index(:admin_login_activities, [:status])
  end
end
