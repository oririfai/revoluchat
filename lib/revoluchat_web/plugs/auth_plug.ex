defmodule RevoluchatWeb.Plugs.AuthPlug do
  @moduledoc """
  Verifikasi JWT RS256 dari user service dan cek user context.
  Flow: Bearer token → verify RS256 → extract user_id (string/int) → assign conn.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Revoluchat.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, %{user_id: user_id, app_id: app_id}} <- Accounts.verify_token(token) do
      conn
      |> assign(:current_user_id, user_id)
      |> assign(:current_app_id, app_id)
    else
      [] ->
        unauthorized(conn, "Authorization header diperlukan")

      {:error, :user_not_found} ->
        unauthorized(conn, "User tidak ditemukan")

      {:error, _reason} ->
        unauthorized(conn, "Token tidak valid atau sudah expired")
    end
  end

  defp unauthorized(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "unauthorized", message: message})
    |> halt()
  end
end
