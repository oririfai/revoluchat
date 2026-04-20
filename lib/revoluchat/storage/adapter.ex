defmodule Revoluchat.Storage.Adapter do
  @moduledoc """
  Behavior for storage adapters (S3, Cloudinary).
  """

  @callback presigned_upload_data(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback presigned_get_url(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  @callback get_object(String.t()) :: {:ok, map()} | {:error, term()}
  @callback verify_upload(String.t()) :: {:ok, term()} | {:error, term()}
  @callback upload_binary(String.t(), binary(), String.t()) :: {:ok, term()} | {:error, term()}
end
