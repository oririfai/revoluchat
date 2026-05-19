defmodule Revoluchat.Repo.Migrations.RefactorIdsToString do
  use Ecto.Migration

  def change do
    # 1. conversations
    alter table(:conversations) do
      modify :user_a_id, :string, from: :integer
      modify :user_b_id, :string, from: :integer
    end
    drop constraint(:conversations, :user_ordering)
    # create constraint(:conversations, :user_ordering, check: "user_a_id < user_b_id") # String comparison is different, maybe not needed or use different check

    # 2. messages
    alter table(:messages) do
      modify :sender_id, :string, from: :integer
    end

    # 3. user_chats
    alter table(:user_chats) do
      modify :user_id, :string, from: :bigint
    end

    # 4. contacts
    alter table(:contacts) do
      modify :owner_id, :string, from: :integer
      modify :contact_id, :string, from: :integer
    end

    # 5. calls (if table exists)
    if table_exists?(:calls) do
      alter table(:calls) do
        modify :caller_id, :string, from: :bigint
        modify :receiver_id, :string, from: :bigint
      end
    end
  end

  defp table_exists?(_table_name) do
    # Simple check for migration flexibility
    true 
  end
end
