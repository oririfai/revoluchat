defmodule RevoluchatWeb.PushTokenController do
  use RevoluchatWeb, :controller

  alias Revoluchat.Notifications

  action_fallback RevoluchatWeb.FallbackController

  # POST /api/v1/push_tokens
  def create(conn, %{"platform" => platform, "token" => token}) do
    app_id = conn.assigns.current_app_id
    user_id = conn.assigns.current_user_id

    with {:ok, _push_token} <- Notifications.register_push_token(app_id, user_id, platform, token) do
      send_resp(conn, :no_content, "")
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "platform dan token wajib diisi"})
  end

  # DELETE /api/v1/push_tokens
  def delete(conn, %{"token" => token}) do
    app_id = conn.assigns.current_app_id
    user_id = conn.assigns.current_user_id
    Notifications.delete_push_token(app_id, user_id, token)
    send_resp(conn, :no_content, "")
  end
end
