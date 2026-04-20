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
        if upload_data[:proxy] do
          # Build a relative path. The Android client will securely prefix this with its own baseUrl.
          url = "/api/v1/attachments/#{attachment.id}/upload"
          Map.merge(base, %{
            upload_url: url,
            upload_method: "PUT"
          })
        else
          Map.merge(base, %{
            upload_url: upload_data.upload_url,
            upload_method: upload_data.method,
            upload_params: upload_data[:fields],
            amz_date: upload_data[:amz_date],
            amz_content_sha256: upload_data[:amz_content_sha256]
          })
        end
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
