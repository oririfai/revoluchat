defmodule Revoluchat.Storage.S3Adapter do
  @behaviour Revoluchat.Storage.Adapter
  require Logger

  @bucket Application.compile_env(:revoluchat, [:storage, :bucket], "revoluchat")
  @default_expiry 3600

  @impl true
  def presigned_upload_data(key, opts \\ []) do
    expiry = Keyword.get(opts, :expiry, @default_expiry)
    content_type = Keyword.get(opts, :content_type)

    query_params = if content_type, do: [{"Content-Type", content_type}], else: []
    config = ExAws.Config.new(:s3)
    
    public_host = 
      case Application.get_env(:revoluchat, :storage) do
        nil -> config.host
        storage_conf -> storage_conf[:public_host] || config.host
      end

    public_config = %{config | host: public_host}

    case ExAws.S3.presigned_url(public_config, :put, @bucket, key,
           expires_in: expiry,
           query_params: query_params
         ) do
      {:ok, url} ->
        {:ok, %{upload_url: url, method: "PUT"}}

      {:error, reason} ->
        Logger.error("Failed to generate presigned PUT URL: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def presigned_get_url(key, opts \\ []) do
    expiry = Keyword.get(opts, :expiry, @default_expiry)
    config = ExAws.Config.new(:s3)
    
    public_host = 
      case Application.get_env(:revoluchat, :storage) do
        nil -> config.host
        storage_conf -> storage_conf[:public_host] || config.host
      end

    public_config = %{config | host: public_host}

    ExAws.S3.presigned_url(public_config, :get, @bucket, key, expires_in: expiry)
  end

  @impl true
  def verify_upload(key) do
    ExAws.S3.head_object(@bucket, key)
    |> ExAws.request()
  end
end
