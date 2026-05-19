defmodule Revoluchat.Repo.Migrations.ClearLegacyChatData do
  use Ecto.Migration

  def up do
    # Clear tables that refer to legacy numeric user IDs
    # Since these are mostly caches/relationships that will be rebuilt on relogin
    execute "TRUNCATE TABLE user_chats CASCADE"
    execute "TRUNCATE TABLE contacts CASCADE"
    execute "TRUNCATE TABLE conversations CASCADE"
    execute "TRUNCATE TABLE messages CASCADE"
    execute "TRUNCATE TABLE calls CASCADE"
  end

  def down do
    :ok
  end
end
