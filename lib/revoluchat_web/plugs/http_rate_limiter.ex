defmodule RevoluchatWeb.Plugs.HttpRateLimiter do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(opts), do: opts

  def call(conn, opts) do
    scale = Keyword.fetch!(opts, :scale_ms)
    limit = Keyword.fetch!(opts, :limit)
    key_type = Keyword.get(opts, :key_type, :ip)

    key = generate_key(conn, key_type)

    case Hammer.check_rate(key, scale, limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_status(:too_many_requests)
        |> put_resp_header("retry-after", "#{div(scale, 1000)}")
        |> json(%{error: "too_many_requests", retry_after: div(scale, 1000)})
        |> halt()
    end
  end

  defp generate_key(conn, :user_id) do
    user_id = conn.assigns[:current_user_id] || client_ip(conn)
    "http_msgs:#{user_id}"
  end

  defp generate_key(conn, :ip) do
    "http_req:#{client_ip(conn)}"
  end

  defp client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end
end
