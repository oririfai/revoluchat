defmodule RevoluchatWeb.Plugs.AdminAutoLogin do
  import Plug.Conn
  alias Phoenix.Token
  alias RevoluchatWeb.Endpoint

  @salt "admin_auth_salt"
  @cookie_name "keep_stable"
  # 30 days
  @max_age 30 * 24 * 60 * 60

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :admin_id) do
      # Already logged in, nothing to do
      conn
    else
      # Check if remember_me cookie is present
      conn = fetch_cookies(conn, signed: [@cookie_name])

      case conn.cookies[@cookie_name] do
        nil ->
          conn

        token ->
          case Token.verify(Endpoint, @salt, token, max_age: @max_age) do
            {:ok, admin_id} ->
              # Successfully verified, restore session
              current_ua = get_req_header(conn, "user-agent") |> List.first() || "Unknown"
              current_ip = get_ip_string(conn)

              conn
              |> put_session(:admin_id, admin_id)
              |> put_session(:is_remember_me, true)
              |> put_session(:login_user_agent, current_ua)
              |> put_session(:login_ip, current_ip)
              # Slide token expiration on each visit by generating a new one
              |> refresh_remember_me_cookie(admin_id)

            {:error, _reason} ->
              # Token invalid or expired, clear cookie
              delete_resp_cookie(conn, @cookie_name)
          end
      end
    end
  end

  defp refresh_remember_me_cookie(conn, admin_id) do
    token = Token.sign(Endpoint, @salt, admin_id)

    put_resp_cookie(conn, @cookie_name, token,
      sign: true,
      max_age: @max_age,
      http_only: true,
      secure: conn.scheme == :https,
      same_site: "Lax"
    )
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

defmodule RevoluchatWeb.Plugs.AdminSessionTimeout do
  import Plug.Conn
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]

  @cookie_name "keep_stable"
  # 30 minutes in seconds
  @timeout_seconds 30 * 60

  def init(opts), do: opts

  def call(conn, _opts) do
    admin_id = get_session(conn, :admin_id)

    # If the user is on the login or session create route, skip timeout logic to avoid loops
    if admin_id && conn.request_path not in ["/admin/login", "/admin/logout"] do
      # If "Remember Me" cookie is NOT present, enforce idle session timeout
      conn = fetch_cookies(conn, signed: [@cookie_name])

      if is_nil(conn.cookies[@cookie_name]) do
        now = System.system_time(:second)
        last_activity = get_session(conn, :last_activity_at)

        if last_activity && now - last_activity > @timeout_seconds do
          # Exceeded idle timeout limit, destroy session and redirect
          conn
          |> clear_session()
          |> configure_session(drop: true)
          |> put_flash(:error, "Your session has expired due to inactivity. Please log in again.")
          |> redirect(to: "/admin/login")
          |> halt()
        else
          # Still active, update timestamp
          put_session(conn, :last_activity_at, now)
        end
      else
        # Persistent login session is active, no idle timeout required
        conn
      end
    else
      conn
    end
  end
end
