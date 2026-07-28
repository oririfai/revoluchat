defmodule RevoluchatWeb.SessionController do
  use RevoluchatWeb, :controller

  alias Revoluchat.Accounts.Admin
  alias Revoluchat.Repo

  def create(conn, %{"auth" => auth_params}) do
    email = auth_params["email"]
    password = auth_params["password"]
    remember_me = auth_params["remember_me"] in ["on", "true"]

    ip_address = get_ip_string(conn)
    user_agent = get_req_header(conn, "user-agent") |> List.first() || "Unknown"

    admin = Repo.get_by(Admin, email: email)

    authenticated? =
      if admin do
        Admin.verify_password(password, admin)
      else
        Bcrypt.no_user_verify()
        false
      end

    if authenticated? do
      # Log successful login to PostgreSQL
      Revoluchat.Accounts.log_admin_login(admin, ip_address, user_agent, :success)

      conn
      |> configure_session(renew: true)
      |> put_session(:admin_id, admin.id)
      |> put_session(:login_ip, ip_address)
      |> put_session(:login_user_agent, user_agent)
      |> put_session(:is_remember_me, remember_me)
      |> handle_remember_me(admin.id, remember_me)
      |> redirect(to: "/admin")
    else
      # Log failed login to PostgreSQL
      Revoluchat.Accounts.log_admin_login(email, ip_address, user_agent, :failed)

      conn
      |> put_flash(:error, "Invalid email or password")
      |> redirect(to: "/admin/login")
    end
  end

  defp handle_remember_me(conn, admin_id, true) do
    token = Phoenix.Token.sign(RevoluchatWeb.Endpoint, "admin_auth_salt", admin_id)

    put_resp_cookie(conn, "keep_stable", token,
      sign: true,
      max_age: 30 * 24 * 60 * 60,
      http_only: true,
      secure: conn.scheme == :https,
      same_site: "Lax"
    )
  end

  defp handle_remember_me(conn, _admin_id, false) do
    put_session(conn, :last_activity_at, System.system_time(:second))
  end

  def delete(conn, _params) do
    conn
    |> delete_resp_cookie("keep_stable")
    |> clear_session()
    |> configure_session(drop: true)
    |> redirect(to: "/admin/login")
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
