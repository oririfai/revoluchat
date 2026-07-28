defmodule Revoluchat.Repo.Migrations.CreateUserLoginActivities do
  use Ecto.Migration

  def change do
    create table(:user_login_activities) do
      add :user_id, :string, null: false
      add :name, :string, null: true
      add :phone, :string, null: true
      add :ip_address, :string, null: false
      add :user_agent, :text, null: false
      add :device_os, :string, null: false
      add :device_browser, :string, null: false
      add :status, :string, null: false, default: "success"

      timestamps(type: :utc_datetime)
    end

    create index(:user_login_activities, [:user_id])
    create index(:user_login_activities, [:ip_address])
    create index(:user_login_activities, [:inserted_at])
  end
end
