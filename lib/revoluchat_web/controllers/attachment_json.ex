defmodule RevoluchatWeb.AttachmentJSON do
  alias Revoluchat.Chat.Attachment

  @doc """
  Renders attachment initiation response with presigned URL.
  """
  def init(%{attachment: attachment, url: upload_data}) do
    base = %{
      id: attachment.id,
      storage_key: attachment.storage_key,
      mime_type: attachment.mime_type,
      status: attachment.status,
      metadata: attachment.metadata,
      expires_in: 3600
    }

    data = 
      if is_map(upload_data) do
        Map.merge(base, %{
          upload_url: upload_data.upload_url,
          upload_method: upload_data.method,
          upload_params: upload_data[:fields]
        })
      else
        Map.merge(base, %{upload_url: upload_data})
      end

    %{data: data}
  end

  @doc """
  Renders a single attachment.
  """
  def show(%{attachment: attachment, url: url}) do
    %{
      data: Map.merge(data(attachment), %{url: url})
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
