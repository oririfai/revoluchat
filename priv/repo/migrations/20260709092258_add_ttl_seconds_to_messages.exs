defmodule Revoluchat.Repo.Migrations.AddTtlSecondsToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :ttl_seconds, :integer, default: 0
    end
  end
end
