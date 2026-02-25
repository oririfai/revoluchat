defmodule Revoluchat.Storage do
  @moduledoc """
  Wrapper untuk operasi object storage (MinIO / S3).
  Menangani presigned URL generation dan pengecekan object.
  """

  require Logger

  # Baca config saat compile time (default) atau runtime
  # Pastikan config :revoluchat, :storage diset di config.exs
  @bucket Application.compile_env(:revoluchat, [:storage, :bucket], "revoluchat")
  # 1 jam
  @default_expiry 3600

  @doc """
  Generate Presigned PUT URL untuk upload langsung ke MinIO.
  Client melakukan PUT ke URL ini dengan file body.
  """
  def presigned_put_url(key, opts \\ []) do
    expiry = Keyword.get(opts, :expiry, @default_expiry)
    content_type = Keyword.get(opts, :content_type)

    # Query params untuk signature
    query_params = if content_type, do: [{"Content-Type", content_type}], else: []

    config = ExAws.Config.new(:s3)

    # Generate URL
    case ExAws.S3.presigned_url(config, :put, @bucket, key,
           expires_in: expiry,
           query_params: query_params
         ) do
      {:ok, url} ->
        {:ok, url}

      {:error, reason} ->
        Logger.error("Failed to generate presigned PUT URL: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Generate Presigned GET URL untuk download file privat.
  """
  def presigned_get_url(key, opts \\ []) do
    expiry = Keyword.get(opts, :expiry, @default_expiry)
    config = ExAws.Config.new(:s3)

    case ExAws.S3.presigned_url(config, :get, @bucket, key, expires_in: expiry) do
      {:ok, url} -> {:ok, url}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Cek apakah object ada di storage (Head Object).
  Digunakan untuk verifikasi upload sukses sebelum update status DB.
  """
  @spec head_object(String.t()) :: {:ok, term()} | {:error, term()}
  def head_object(key) do
    ExAws.S3.head_object(@bucket, key)
    |> ExAws.request()
  end

  @doc """
  Initializes the bucket if it doesn't exist.
  Best effort, biasanya dilakukan via script init docker.
  """
  def ensure_bucket do
    ExAws.S3.put_bucket(@bucket, "us-east-1")
    |> ExAws.request()
  end
end
