defmodule RevoluchatWeb.Plugs.AdminSessionPinning do
  import Plug.Conn
  import Phoenix.Controller
  use RevoluchatWeb, :verified_routes
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    if admin_id = get_session(conn, :admin_id) do
      current_ip = get_ip_string(conn)
      current_ua = get_req_header(conn, "user-agent") |> List.first() || "Unknown"

      expected_ip = get_session(conn, :login_ip)
      expected_ua = get_session(conn, :login_user_agent)
      is_remember_me = get_session(conn, :is_remember_me) || false

      # Pin both IP and UA for session logins.
      # Pin only UA (OS/browser type) for persistent cookies to handle home/mobile dynamic IP mobility.
      valid? =
        cond do
          is_nil(expected_ua) ->
            # If session pinning data hasn't been set yet, initialize it on this first request.
            # This is safe and ensures compatibility with logins that happened exactly during release deployment.
            true

          is_remember_me ->
            expected_ua == current_ua

          true ->
            expected_ip == current_ip and expected_ua == current_ua
        end

      if valid? do
        # If expected values were missing or nil (e.g. from transition), populate them now
        conn =
          if is_nil(expected_ua) do
            conn
            |> put_session(:login_ip, current_ip)
            |> put_session(:login_user_agent, current_ua)
          else
            conn
          end

        conn
      else
        Logger.warning(
          "SECURITY ALERT: Admin session hijack/fingerprint mismatch detected for Admin ID #{admin_id}!"
        )

        Logger.warning("Expected IP: #{inspect(expected_ip)}, Current IP: #{inspect(current_ip)}")
        Logger.warning("Expected UA: #{inspect(expected_ua)}, Current UA: #{inspect(current_ua)}")

        # Clear session & remember me cookie, log the action, alert user and redirect to login
        conn
        |> configure_session(drop: true)
        |> delete_resp_cookie("keep_stable")
        |> put_flash(
          :error,
          "Security Alert: Your IP address or device signature has changed. Please sign in again."
        )
        |> redirect(to: ~p"/admin/login")
        |> halt()
      end
    else
      conn
    end
  end

  defp get_ip_string(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [h | _] ->
        h |> String.split(",") |> List.first() |> String.trim()

      _ ->
        case get_req_header(conn, "x-real-ip") do
          [h | _] ->
            h

          _ ->
            conn.remote_ip
            |> :inet.ntoa()
            |> to_string()
        end
    end
  end
end
