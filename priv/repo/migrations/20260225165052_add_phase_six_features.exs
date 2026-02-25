defmodule Revoluchat.Repo.Migrations.AddPhaseSixFeatures do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :is_encrypted, :boolean, default: false, null: false
    end

    alter table(:attachments) do
      add :metadata, :map
    end
  end
end
