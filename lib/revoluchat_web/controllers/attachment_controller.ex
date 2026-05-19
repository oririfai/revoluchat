defmodule RevoluchatWeb.AttachmentController do
  use RevoluchatWeb, :controller

  alias Revoluchat.Chat
  alias RevoluchatWeb.AttachmentJSON
  require Logger

  action_fallback RevoluchatWeb.FallbackController

  def init(conn, params) do
    user_id = conn.assigns[:current_user_id]
    numeric_user_id = conn.assigns[:current_numeric_user_id]
    app_id = conn.assigns[:current_app_id]
    attrs = 
      params
      |> Map.put("uploader_id", numeric_user_id || user_id)
      |> Map.put("app_id", app_id)

    with {:ok, attachment, url} <- Chat.create_attachment_init(attrs) do
      conn
      |> put_status(:created)
      |> put_view(json: AttachmentJSON)
      |> render(:init, attachment: attachment, url: url)
    end
  end

  def upload(conn, %{"id" => id}) do
    try do
      # 50MB max body limit for binary upload
      case Plug.Conn.read_body(conn, length: 50_000_000) do
        {:ok, binary_data, conn} ->
          attachment = Chat.get_attachment!(id)
          
          case Revoluchat.Storage.upload_binary(
                 attachment.storage_key,
                 binary_data,
                 attachment.mime_type
               ) do
            {:ok, _} ->
              # Auto-approve since we just successfully uploaded it
              app_id = conn.assigns[:current_app_id]
              Chat.approve_attachment_direct(app_id, id)
              
              json(conn, %{success: true})
              
            {:error, reason} ->
              conn
              |> put_status(:bad_request)
              |> json(%{error: "Failed to upload to storage", details: inspect(reason)})
          end

        {:more, _, _} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Body is too large or chunked incorrectly"})

        _ ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Failed to read request body"})
      end
    rescue
      e ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "Exception occurred", 
          exception: Exception.message(e),
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        })
    end
  end

  def confirm(conn, %{"id" => id}) do
    user_id = conn.assigns[:current_numeric_user_id] || conn.assigns[:current_user_id]
    app_id = conn.assigns[:current_app_id]

    with {:ok, attachment} <- Chat.confirm_attachment(app_id, id, user_id),
         {:ok, url} <- Chat.get_attachment_download_url(app_id, id, user_id) do
      conn
      |> put_view(json: AttachmentJSON)
      |> render(:show, attachment: attachment, url: url)
    end
  end

  def download(conn, %{"id" => id}) do
    user_id = conn.assigns[:current_numeric_user_id] || conn.assigns[:current_user_id]
    app_id = conn.assigns[:current_app_id]

    case Chat.get_attachment_download_url(app_id, id, user_id) do
      {:ok, url} ->
        json(conn, %{url: url})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(json: RevoluchatWeb.ErrorJSON)
        |> render(:"404")
    end
  end

  def show(conn, %{"id" => id}) do
    app_id = conn.assigns.current_app_id
    user_id = conn.assigns[:current_numeric_user_id] || conn.assigns[:current_user_id]

    case Chat.get_approved_attachment_for_user(app_id, id, user_id) do
      {:ok, attachment} ->
        Logger.info("AttachmentController: Fetching from storage key: #{attachment.storage_key}")
        case Revoluchat.Storage.get_object(attachment.storage_key) do
          {:ok, %{body: binary_data, status_code: status} = resp} when status in 200..299 ->
            Logger.info("AttachmentController: Successfully fetched binary data for #{id}. Size: #{byte_size(binary_data)} bytes. Response: #{inspect(Map.drop(resp, [:body]))}")
            conn
            |> put_resp_content_type(attachment.mime_type || "application/octet-stream")
            |> put_resp_header("cache-control", "public, max-age=3600")
            |> send_resp(200, binary_data)

          {:ok, %{status_code: status, body: body}} ->
            Logger.error("AttachmentController: Storage returned error status #{status} for attachment #{id}. Body: #{inspect(body)}")
            conn |> put_status(:internal_server_error) |> json(%{error: "Storage error", status: status})

          {:ok, other} ->
            Logger.error("AttachmentController: Storage returned unexpected structure: #{inspect(other)}")
            conn |> put_status(:internal_server_error) |> json(%{error: "Unexpected storage response"})

          {:error, {:http_error, 404, _}} ->
            Logger.info("AttachmentController: Attachment #{id} missing in upstream storage (NoSuchKey). It may have been a failed upload.")
            conn |> put_status(:not_found) |> json(%{error: "File not found in storage"})

          {:error, reason} ->
            Logger.error("AttachmentController: Proxy fetch failed from storage for attachment #{id}: #{inspect(reason)}")
            conn
            |> put_status(:bad_request)
            |> json(%{error: "Proxy fetch failed", details: inspect(reason)})
        end

      {:error, reason} ->
        Logger.warning("Access denied or attachment not found for proxy show: #{id}, reason: #{inspect(reason)}")
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Attachment not found or not authorized"})
    end
  end

  # ─── Private ─────────────────────────────────────────────────────────────────
end
