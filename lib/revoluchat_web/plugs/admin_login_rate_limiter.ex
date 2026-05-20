defmodule RevoluchatWeb.Plugs.AdminLoginRateLimiter do
  import Plug.Conn
  import Phoenix.Controller
  require Logger

  # Scale is 900,000 ms (15 minutes)
  @scale 900_000
  # Max 10 attempts per 15 minutes
  @limit 10

  def init(opts), do: opts

  def call(conn, _opts) do
    # Only rate limit the POST requests (the actual login submissions)
    if conn.method == "POST" do
      ip = client_ip(conn)
      email = conn.params["auth"]["email"] || ""
      email_clean = String.downcase(String.trim(email))

      ip_key = "admin_login_ip:#{ip}"
      email_key = "admin_login_email:#{email_clean}"

      # Verify both rate limits
      case {check_limit(ip_key), check_limit(email_key)} do
        {:allow, :allow} ->
          conn

        _deny ->
          Logger.warning(
            "SECURITY ALERT: Admin login rate limit exceeded! IP: #{ip}, Email: #{email_clean}"
          )

          conn
          |> put_flash(
            :error,
            "Security Alert: Too many login attempts. Please wait 1 minute before trying again."
          )
          |> redirect(to: "/admin/login")
          |> halt()
      end
    else
      conn
    end
  end

  defp check_limit(key) do
    case Hammer.check_rate(key, @scale, @limit) do
      {:allow, _count} -> :allow
      {:deny, _limit} -> :deny
    end
  end

  defp client_ip(conn) do
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
