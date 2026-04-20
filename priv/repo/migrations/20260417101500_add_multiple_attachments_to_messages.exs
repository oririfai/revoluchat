defmodule Revoluchat.Repo.Migrations.AddMultipleAttachmentsToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      # Add attachment_ids as an array of binary_id (UUID)
      add :attachment_ids, {:array, :binary_id}, default: []
    end

    # Drop the old complex constraint that enforced single attachment_id
    # We will relax this so either old or new format works
    drop constraint(:messages, :body_or_attachment)

    # Recreate a more flexible constraint
    # Valid if: 
    # - text type has body 
    # - attachment type has attachment_id OR attachment_ids is not empty
    # - system_call_summary (no extra validation needed for migration safety)
    create constraint(:messages, :body_or_attachment,
             check:
               "(type = 'text' AND body IS NOT NULL) OR " <>
               "(type = 'attachment' AND (attachment_id IS NOT NULL OR cardinality(attachment_ids) > 0)) OR " <>
               "(type = 'system_call_summary')"
           )
  end
end
