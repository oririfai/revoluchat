defmodule Revoluchat.Repo.Migrations.CreateUserChats do
  use Ecto.Migration

  def change do
    create table(:user_chats) do
      add :user_id, :bigint, null: false
      add :chat_id, :uuid, null: false
      add :app_id, :string, null: false

      timestamps()
    end

    create index(:user_chats, [:user_id])
    create index(:user_chats, [:chat_id])
    create index(:user_chats, [:app_id])
    create unique_index(:user_chats, [:user_id, :app_id], name: :user_id_app_id_unique)
  end
end
