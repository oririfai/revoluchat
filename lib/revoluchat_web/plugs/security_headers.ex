defmodule RevoluchatWeb.Plugs.SecurityHeaders do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    connect_src = System.get_env("CSP_CONNECT_SRC") || "'self' wss: https:"
    csp_value = "default-src 'none'; connect-src #{connect_src};"

    conn
    |> put_resp_header("content-security-policy", csp_value)
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=()")
  end
end
