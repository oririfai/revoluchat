defmodule Revoluchat.Repo.Migrations.AddSuspendedUntilToUserChats do
  use Ecto.Migration

  def change do
    alter table(:user_chats) do
      add :suspended_until, :utc_datetime
    end
  end
end
