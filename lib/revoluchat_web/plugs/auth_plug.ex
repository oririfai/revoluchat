defmodule RevoluchatWeb.Plugs.AuthPlug do
  @moduledoc """
  Verifikasi JWT RS256 dari user service dan cek user context.
  Flow: Bearer token → verify RS256 → extract user_id (string/int) → assign conn.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Revoluchat.Accounts
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_query_params(conn)
    # Try headers first, then params for media assets
    token =
      case get_req_header(conn, "authorization") do
        ["Bearer " <> t] -> t
        _ -> conn.query_params["token"]
      end

    api_key =
      case get_req_header(conn, "x-api-key") do
        [k] -> k
        _ -> conn.query_params["api_key"]
      end

    Logger.debug("AuthPlug: Examining request. Path: #{conn.request_path}")

    Logger.debug(
      "AuthPlug: Extracted Token: #{if token, do: "Present (length #{String.length(token)})", else: "nil"}"
    )

    Logger.debug("AuthPlug: Extracted API Key: #{if api_key, do: "Present", else: "nil"}")

    with t when not is_nil(t) <- token,
         k when not is_nil(k) <- api_key do
      Logger.debug("AuthPlug: Found Token and API Key. Verifying...")

      case Accounts.get_api_key_by_key(k) do
        nil ->
          Logger.error("AuthPlug: API Key not found in database: #{inspect(k)}")
          unauthorized(conn, "API Key tidak valid")

        api_key_record ->
          Logger.debug("AuthPlug: API Key record found. Verifying JWT Token...")

          case Accounts.verify_token(t) do
            {:ok, %{user_id: user_id, app_id: token_app_id}} ->
              Logger.debug("AuthPlug: JWT Token verified for user_id: #{user_id}")

              if token_app_id && token_app_id != api_key_record.app_id do
                Logger.error(
                  "AuthPlug: App ID mismatch between API Key (#{api_key_record.app_id}) and Token (#{token_app_id})"
                )

                unauthorized(conn, "App ID mismatch")
              else
                case Accounts.verify_user_exists(user_id) do
                  {:ok, user} ->
                    # Prioritizing app_id from token if available, fallback to API Key app_id
                    app_id = token_app_id || api_key_record.app_id

                    # Keep user_id as string (UUID)
                    user_id = to_string(user_id)

                    # Capture numeric ID if available for legacy features (like attachments)
                    numeric_id =
                      case user.id do
                        id when is_integer(id) ->
                          id

                        id when is_binary(id) ->
                          case Integer.parse(id) do
                            {int, ""} -> int
                            _ -> nil
                          end

                        _ ->
                          nil
                      end

                    # Sync user data locally (caching name, phone, avatar)
                    Accounts.ensure_user_chat_registered(user_id, app_id, user)

                    conn
                    |> assign(:current_user_id, user_id)
                    |> assign(:current_numeric_user_id, numeric_id)
                    |> assign(:current_app_id, app_id)
                    |> assign(:api_key, k)
                    |> assign(:token, t)

                  {:error, {:suspended, suspended_until}} ->
                    Logger.error(
                      "AuthPlug: User #{user_id} is currently suspended until #{suspended_until}"
                    )

                    unauthorized(conn, "User is currently suspended", suspended_until)

                  {:error, :suspended} ->
                    Logger.error("AuthPlug: User #{user_id} is currently suspended")
                    unauthorized(conn, "User is currently suspended")

                  {:error, _reason} ->
                    Logger.error("AuthPlug: User not found in remote service: #{user_id}")
                    unauthorized(conn, "User not found")
                end
              end

            {:error, reason} ->
              Logger.error("AuthPlug: JWT Verification failed: #{inspect(reason)}")
              unauthorized(conn, "Token invalid or expired")
          end
      end
    else
      _ ->
        Logger.error(
          "AuthPlug: Missing token or api_key. Token: #{inspect(token)}, API Key: #{inspect(api_key)}"
        )

        unauthorized(conn, "Token atau API Key tidak ditemukan (cek header/params)")
    end
  end

  defp unauthorized(conn, message, suspended_until \\ nil) do
    payload =
      if suspended_until do
        %{error: "suspended", message: message, suspended_until: suspended_until}
      else
        %{error: "unauthorized", message: message}
      end

    conn
    |> put_status(:unauthorized)
    |> json(payload)
    |> halt()
  end
end
