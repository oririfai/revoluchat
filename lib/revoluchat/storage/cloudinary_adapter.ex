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

    # 2. Split key into folder + public_id (filename without extension)
    # This is the correct Cloudinary approach — folder defines the path,
    # public_id is just the unique file identifier (UUID, no extension).
    # Example key: "revoluchat/attachments/images/2024-04-08/uuid.jpg"
    # → folder: "revoluchat/attachments/images/2024-04-08"
    # → public_id: "uuid" (just the UUID, no folder, no extension)
    basename = Path.basename(key)                        # "uuid.jpg"
    file_id  = Path.rootname(basename)                   # "uuid"
    folder   = Path.dirname(key)                         # "revoluchat/attachments/images/2024-04-08"

    # 3. Alphabetical param order for signature: folder(F), public_id(P), timestamp(T)
    string_to_sign = "folder=#{folder}&public_id=#{file_id}&timestamp=#{timestamp}#{api_secret}"
    
    # 4. Calculate SHA1 Signature
    signature = :crypto.hash(:sha, string_to_sign) |> Base.encode16() |> String.downcase()

    # 5. Final fields to send to Mobile
    fields = %{
      "timestamp"  => timestamp,
      "api_key"    => api_key,
      "signature"  => signature,
      "public_id"  => file_id,
      "folder"     => folder
    }

    upload_url = "https://api.cloudinary.com/v1_1/#{cloud_name}/auto/upload"

    Logger.info("[Cloudinary] Presigned upload → folder: #{folder}, public_id: #{file_id}")

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
    
    # Reconstruct consistent with how we upload:
    # folder = directory path, file_id = UUID (no ext), format = extension
    basename    = Path.basename(key)                        # "uuid.jpg"
    file_id     = Path.rootname(basename)                   # "uuid"
    folder      = Path.dirname(key)                         # "revoluchat/attachments/images/date"
    ext         = key |> Path.extname() |> String.trim_leading(".")
    
    # Determine resource_type based on folder category in the key
    resource_type = cond do
      String.contains?(key, "/images/") -> "image"
      String.contains?(key, "/video/")  -> "video"
      true                              -> "raw"   # documents, audio, other files
    end

    # Cloudinary URL: {resource_type}/upload/{folder}/{file_id}.{ext}
    format = if ext == "", do: "bin", else: ext
    url = "https://res.cloudinary.com/#{cloud_name}/#{resource_type}/upload/#{folder}/#{file_id}.#{format}"
    {:ok, url}
  end

  @impl true
  def get_object(_key) do
    {:error, :not_implemented_for_cloudinary}
  end

  @impl true
  def verify_upload(_key) do
    {:ok, true}
  end

  @impl true
  def head_object(key) do
    {:ok, %{key: key}}
  end
  
  @impl true
  def upload_binary(_key, _binary_data, _content_type) do
    # Proxy upload is meant for R2 signature bug workarounds. 
    # Cloudinary presigned upload from Mobile works fine directly.
    {:error, :not_implemented_for_cloudinary}
  end
end
