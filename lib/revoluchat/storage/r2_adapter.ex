defmodule Revoluchat.Storage.R2Adapter do
  @behaviour Revoluchat.Storage.Adapter
  require Logger

  @default_expiry 3600

  @impl true
  def presigned_upload_data(key, _opts \\ []) do
    # Because Cloudflare R2 has conflicting requirements for Presigned URLs (requiring either missing headers or strict header-auth),
    # we use a proxy upload strategy where Android uploads directly to our Phoenix backend, which then uses ExAws.
    {:ok, %{proxy: true, storage_key: key}}
  end

  @impl true
  def presigned_get_url(key, opts \\ []) do
    expiry = Keyword.get(opts, :expiry, @default_expiry)
    case ExAws.S3.presigned_url(config(), :get, bucket(), key,
           expires_in: expiry
         ) do
      {:ok, url} ->
        {:ok, url}

      {:error, reason} ->
        Logger.error("Failed R2 GET presigned URL for #{key}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def get_object(key) do
    ExAws.S3.get_object(bucket(), key)
    |> ExAws.request(config())
  end
  
  def config do
    config = ExAws.Config.new(:s3)

    public_host_str =
      case Application.get_env(:revoluchat, :storage) do
        nil -> config.host
        storage_conf -> storage_conf[:public_host] || config.host
      end

    prefixed_host =
      if String.starts_with?(public_host_str, "http://") or
           String.starts_with?(public_host_str, "https://") do
        public_host_str
      else
        "https://" <> public_host_str
      end

    uri = URI.parse(prefixed_host)
    
    # Align scheme and port to avoid TLS mismatches
    scheme = uri.scheme || "https"
    default_port = if scheme == "https", do: 443, else: 80
    
    # ExAws specifically expects the scheme to end with "://"
    Map.merge(config, %{
      scheme: scheme <> "://",
      host: uri.host, 
      port: uri.port || default_port,
      region: "auto",
      virtual_host: false
    })
  end

  @impl true
  def verify_upload(key) do
    ExAws.S3.head_object(bucket(), key)
    |> ExAws.request(config())
  end

  @impl true
  def upload_binary(key, binary_data, content_type) do
    case ExAws.S3.put_object(bucket(), key, binary_data, content_type: content_type)
         |> ExAws.request(config()) do
      {:ok, result} ->
        Logger.info("Storage (R2): Successfully uploaded key=#{key} to bucket=#{bucket()}")
        {:ok, result}

      error ->
        error
    end
  end

  defp bucket do
    Application.get_env(:revoluchat, :storage)[:bucket] || "revoluchat"
  end
end
