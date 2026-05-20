defmodule Revoluchat.Repo.Migrations.SyncUserChatsSchema do
  use Ecto.Migration

  def change do
    alter table(:user_chats) do
      add :is_active, :boolean, default: true
      add :description, :text
      add :birth_date, :date
    end
  end
end
