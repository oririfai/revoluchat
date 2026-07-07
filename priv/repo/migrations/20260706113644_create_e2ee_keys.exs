defmodule Revoluchat.Repo.Migrations.CreateE2EEKeys do
  use Ecto.Migration

  def change do
    create table(:e2ee_devices, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :app_id, :string, null: false
      add :user_id, :string, null: false
      add :device_id, :string, null: false
      add :registration_id, :integer, null: false
      add :identity_key_public, :text, null: false
      
      timestamps(type: :utc_datetime)
    end
    
    create unique_index(:e2ee_devices, [:app_id, :user_id, :device_id])

    create table(:e2ee_signed_pre_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :app_id, :string, null: false
      add :device_uuid, references(:e2ee_devices, type: :binary_id, on_delete: :delete_all), null: false
      add :key_id, :integer, null: false
      add :public_key, :text, null: false
      add :signature, :text, null: false
      
      timestamps(type: :utc_datetime)
    end
    
    create unique_index(:e2ee_signed_pre_keys, [:app_id, :device_uuid, :key_id])

    create table(:e2ee_one_time_pre_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :app_id, :string, null: false
      add :device_uuid, references(:e2ee_devices, type: :binary_id, on_delete: :delete_all), null: false
      add :key_id, :integer, null: false
      add :public_key, :text, null: false
      
      timestamps(type: :utc_datetime)
    end
    
    create unique_index(:e2ee_one_time_pre_keys, [:app_id, :device_uuid, :key_id])
  end
end
