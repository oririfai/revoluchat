defmodule Revoluchat.Repo.Migrations.AddProfileToUserChats do
  use Ecto.Migration

  def change do
    alter table(:user_chats) do
      add :name, :string
      add :phone, :string
      add :avatar_url, :text
    end
  end
end
