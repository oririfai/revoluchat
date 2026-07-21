defmodule Revoluchat.Repo.Migrations.AddLastSeenAtToUserChats do
  use Ecto.Migration

  def change do
    alter table(:user_chats) do
      add_if_not_exists :last_seen_at, :utc_datetime, null: true
    end
  end
end
