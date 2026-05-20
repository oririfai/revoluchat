defmodule Revoluchat.Repo.Migrations.ChangeCallIdsToString do
  use Ecto.Migration

  def up do
    alter table(:calls) do
      modify :caller_id, :string, from: :integer
      modify :receiver_id, :string, from: :integer
    end

    alter table(:call_histories) do
      modify :user_id, :string, from: :integer
      modify :other_party_id, :string, from: :integer
    end
  end

  def down do
    alter table(:calls) do
      modify :caller_id, :integer, from: :string
      modify :receiver_id, :integer, from: :string
    end

    alter table(:call_histories) do
      modify :user_id, :integer, from: :string
      modify :other_party_id, :integer, from: :string
    end
  end
end
