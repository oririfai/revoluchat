defmodule RevoluchatWeb.Plugs.AuthPlug do
  @moduledoc """
  Verifikasi JWT RS256 dari user service dan cek user context.
  Flow: Bearer token → verify RS256 → extract user_id (string/int) → assign conn.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Revoluchat.Accounts
  alias Revoluchat.Accounts.ApiKey

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         [api_key] <- get_req_header(conn, "x-api-key"),
         %ApiKey{app_id: api_key_app_id} <- Accounts.get_api_key_by_key(api_key),
         {:ok, %{user_id: user_id, app_id: token_app_id}} <- Accounts.verify_token(token),
         {:ok, user} <- Accounts.verify_user_exists(user_id) do
      # Prioritizing app_id from token if available, fallback to API Key app_id
      app_id = token_app_id || api_key_app_id

      # Ensure user_id is an integer if numeric
      user_id =
        if is_binary(user_id) and Regex.match?(~r/^\d+$/, user_id),
          do: String.to_integer(user_id),
          else: user_id

      # Sync user data locally (caching name, phone, avatar)
      Accounts.ensure_user_chat_registered(user_id, app_id, user)

      conn
      |> assign(:current_user_id, user_id)
      |> assign(:current_app_id, app_id)
      |> assign(:api_key, api_key)
    else
      [] ->
        unauthorized(conn, "Authorization header dan X-API-KEY diperlukan")

      nil ->
        unauthorized(conn, "API Key tidak valid atau sudah tidak aktif")

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
