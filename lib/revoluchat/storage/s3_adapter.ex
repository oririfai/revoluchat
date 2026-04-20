defmodule Revoluchat.Storage.S3Adapter do
  @behaviour Revoluchat.Storage.Adapter
  require Logger

  # Removed compile-time @bucket to favor runtime lookup via bucket() helper.
  @default_expiry 3600

  @impl true
  def presigned_upload_data(key, opts \\ []) do
    expiry = Keyword.get(opts, :expiry, @default_expiry)
    _content_type = Keyword.get(opts, :content_type)

    # Removed query_params for Content-Type. S3/R2 expects Content-Type as an HTTP header,
    # not a query string parameter. OkHttp sends it as a header during PUT.
    config = ExAws.Config.new(:s3)

    public_host_str =
      case Application.get_env(:revoluchat, :storage) do
        nil -> config.host
        storage_conf -> storage_conf[:public_host] || config.host
      end

    # Handle cases where public_host might contain a port (e.g. localhost:9000)
    # We parse it to ensure host and port are separated in the config
    # to avoid encoding the colon as %3A.
    # Safely handle if host already has a scheme
    prefixed_host =
      if String.starts_with?(public_host_str, "http://") or
           String.starts_with?(public_host_str, "https://") do
        public_host_str
      else
        "http://" <> public_host_str
      end

    uri = URI.parse(prefixed_host)
    scheme = uri.scheme || "http"
    default_port = if scheme == "https", do: 443, else: 80

    public_config = Map.merge(config, %{
      scheme: scheme,
      host: uri.host, 
      port: uri.port || default_port
    })

    case ExAws.S3.presigned_url(public_config, :put, bucket(), key, expires_in: expiry) do
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
        "http://" <> public_host_str
      end

    uri = URI.parse(prefixed_host)
    scheme = uri.scheme || "http"
    default_port = if scheme == "https", do: 443, else: 80

    public_config = Map.merge(config, %{
      scheme: scheme,
      host: uri.host, 
      port: uri.port || default_port
    })

    # Use path-style addressing for local dev (localhost/127.0.0.1/10.0.2.2) 
    # as virtual-host addressing (bucketName.localhost) is often unresolvable on devices.
    is_local = uri.host in ["localhost", "127.0.0.1", "10.0.2.2"]
    
    ExAws.S3.presigned_url(public_config, :get, bucket(), key, 
      expires_in: expiry,
      virtual_host: if(is_local, do: false, else: true)
    )
  end

  @impl true
  def get_object(key) do
    ExAws.S3.get_object(bucket(), key)
    |> ExAws.request()
  end

  @impl true
  def verify_upload(key) do
    ExAws.S3.head_object(bucket(), key)
    |> ExAws.request()
  end

  @impl true
  def upload_binary(key, binary_data, content_type) do
    ExAws.S3.put_object(bucket(), key, binary_data, content_type: content_type)
    |> ExAws.request()
  end

  defp bucket do
    Application.get_env(:revoluchat, :storage)[:bucket] || "revoluchat"
  end
end
