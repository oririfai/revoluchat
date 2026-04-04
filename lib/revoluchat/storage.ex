defmodule Revoluchat.Storage do
  @moduledoc """
  Dispatcher for storage operations.
  Uses configured provider (s3, cloudinary).
  """

  @doc """
  Generate upload data/URL for direct-to-storage upload.
  """
  def presigned_upload_data(key, opts \\ []) do
    adapter().presigned_upload_data(key, opts)
  end

  # Alias for backward compatibility if needed, but we should use upload_data
  def presigned_put_url(key, opts \\ []) do
    case presigned_upload_data(key, opts) do
      {:ok, %{upload_url: url}} -> {:ok, url}
      error -> error
    end
  end

  @doc """
  Generate download URL for a file.
  """
  def presigned_get_url(key, opts \\ []) do
    adapter().presigned_get_url(key, opts)
  end

  @doc """
  Verify if object exists in storage.
  """
  def head_object(key) do
    adapter().verify_upload(key)
  end

  defp adapter do
    config = Application.get_env(:revoluchat, :storage)
    case config[:provider] do
      :cloudinary -> Revoluchat.Storage.CloudinaryAdapter
      _ -> Revoluchat.Storage.S3Adapter
    end
  end
end
