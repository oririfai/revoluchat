defmodule RevoluchatWeb.AttachmentController do
  use RevoluchatWeb, :controller

  alias Revoluchat.Chat
  alias RevoluchatWeb.AttachmentJSON

  action_fallback RevoluchatWeb.FallbackController

  def init(conn, params) do
    user_id = conn.assigns[:current_user_id]
    attrs = Map.put(params, "uploader_id", user_id)

    with {:ok, attachment, url} <- Chat.create_attachment_init(attrs) do
      conn
      |> put_status(:created)
      |> put_view(json: AttachmentJSON)
      |> render(:init, attachment: attachment, url: url)
    end
  end

  def confirm(conn, %{"id" => id}) do
    user_id = conn.assigns[:current_user_id]
    app_id = conn.assigns[:current_app_id]

    with {:ok, attachment} <- Chat.confirm_attachment(app_id, id, user_id),
         {:ok, url} <- Chat.get_attachment_download_url(app_id, id, user_id) do
      conn
      |> put_view(json: AttachmentJSON)
      |> render(:show, attachment: attachment, url: url)
    end
  end

  def download(conn, %{"id" => id}) do
    user_id = conn.assigns[:current_user_id]
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
end
