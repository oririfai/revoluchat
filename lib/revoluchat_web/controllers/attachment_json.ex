defmodule RevoluchatWeb.AttachmentJSON do
  alias Revoluchat.Chat.Attachment

  @doc """
  Renders attachment initiation response with presigned URL.
  """
  def init(%{attachment: attachment, url: url}) do
    %{
      data: %{
        id: attachment.id,
        storage_key: attachment.storage_key,
        mime_type: attachment.mime_type,
        status: attachment.status,
        metadata: attachment.metadata,
        upload_url: url,
        expires_in: 3600
      }
    }
  end

  @doc """
  Renders a single attachment.
  """
  def show(%{attachment: attachment}) do
    %{
      data: data(attachment)
    }
  end

  defp data(%Attachment{} = attachment) do
    %{
      id: attachment.id,
      storage_key: attachment.storage_key,
      mime_type: attachment.mime_type,
      size: attachment.size,
      status: attachment.status,
      metadata: attachment.metadata,
      uploader_id: attachment.uploader_id,
      inserted_at: attachment.inserted_at
    }
  end
end
