defmodule Revoluchat.Workers.AttachmentScanWorker do
  use Oban.Worker,
    queue: :scan,
    max_attempts: 3,
    priority: 3

  alias Revoluchat.Repo
  alias Revoluchat.Chat.Attachment
  alias ExAws.S3

  # @bucket removed in favor of runtime bucket() helper

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"attachment_id" => id}}) do
    attachment = Repo.get!(Attachment, id)

    case scan_file(attachment.storage_key) do
      :clean ->
        # Already approved, maybe update checksum later
        :ok

      :infected ->
        # Reject and delete
        attachment
        |> Attachment.changeset(%{status: "rejected"})
        |> Repo.update!()

        S3.delete_object(bucket(), attachment.storage_key)
        |> ExAws.request()

        :ok
    end
  end

  defp scan_file(storage_key) do
    # STUB: Always return clean for Phase 3 MVP
    # In future: ClamAV or VirusTotal integration
    if String.contains?(storage_key, "infected") do
      :infected
    else
      :clean
    end
  end
  defp bucket do
    Application.get_env(:revoluchat, :storage)[:bucket] || "revoluchat"
  end
end
