defmodule Revoluchat.Storage.CloudinaryAdapter do
  @behaviour Revoluchat.Storage.Adapter

  require Logger

  @impl true
  def presigned_upload_data(key, _opts \\ []) do
    config = Application.get_env(:revoluchat, :storage, [])
    cloud_name = config[:cloud_name]
    api_key = config[:api_key]
    api_secret = config[:api_secret]

    if is_nil(cloud_name) || is_nil(api_key) || is_nil(api_secret) do
      Logger.error("[Cloudinary] Configuration missing")
    end

    # 1. Generate Timestamp
    timestamp = DateTime.utc_now() |> DateTime.to_unix() |> to_string()

    # 2. SYNC PUBLIC_ID (STRIP EXTENSION)
    # Cloudinary public_id should not contain the extension (.jpg, .png etc)
    # or it will double-extension the final URL (image.jpg.jpg)
    public_id = key |> Path.rootname()

    # Alphabetical order: public_id (P) before timestamp (T).
    string_to_sign = "public_id=#{public_id}&timestamp=#{timestamp}#{api_secret}"
    
    # 3. Calculate SHA1 Signature
    signature = :crypto.hash(:sha, string_to_sign) |> Base.encode16() |> String.downcase()

    # 4. Final fields to send to Mobile
    fields = %{
      "timestamp" => timestamp,
      "api_key" => api_key,
      "signature" => signature,
      "public_id" => public_id
    }

    upload_url = "https://api.cloudinary.com/v1_1/#{cloud_name}/auto/upload"

    {:ok, %{
      upload_url: upload_url,
      method: "POST",
      fields: fields
    }}
  end

  @impl true
  def presigned_get_url(key, _opts \\ []) do
    config = Application.get_env(:revoluchat, :storage, [])
    cloud_name = config[:cloud_name]
    
    # Cloudinary expects the public_id (no ext) followed by the format extension
    public_id = key |> Path.rootname()
    ext = key |> Path.extname() |> String.trim_leading(".")
    
    # Default to jpg if no extension found
    format = if ext == "", do: "jpg", else: ext
    
    url = "https://res.cloudinary.com/#{cloud_name}/image/upload/#{public_id}.#{format}"
    {:ok, url}
  end

  @impl true
  def verify_upload(_key) do
    {:ok, true}
  end

  @impl true
  def head_object(key) do
    {:ok, %{key: key}}
  end
end
