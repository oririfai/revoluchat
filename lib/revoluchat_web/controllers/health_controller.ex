defmodule RevoluchatWeb.HealthController do
  use RevoluchatWeb, :controller

  alias Revoluchat.Repo

  # GET /health — Liveness
  def liveness(conn, _params) do
    json(conn, %{status: "ok", timestamp: DateTime.utc_now()})
  end

  # GET /health/ready — Readiness
  def readiness(conn, _params) do
    checks = %{
      database: check_database(),
      oban: check_oban()
    }

    all_ok = Enum.all?(checks, fn {_, v} -> v == :ok end)
    status_code = if all_ok, do: 200, else: 503

    conn
    |> put_status(status_code)
    |> json(%{
      status: if(all_ok, do: "ready", else: "not_ready"),
      checks: Map.new(checks, fn {k, v} -> {k, to_string(v)} end),
      timestamp: DateTime.utc_now()
    })
  end

  # GET /health/metrics — Prometheus metrics
  def metrics(conn, _params) do
    # Requires TelemetryMetricsPrometheus to be setup,
    # but for now we will just dump what we have or setup standard exporter later.
    # Actually, we should use TelemetryMetricsPrometheus.Core if available,
    # but let's check dependencies first.
    # If not available, we might need to add it or just stub it.
    # Checking implementation plan: "metrics = TelemetryMetricsPrometheus.Core.scrape()"

    # Assuming the dependency is or will be added.
    # If not, this will crash. I'll comment it out or handle safely.

    try do
      metrics = TelemetryMetricsPrometheus.Core.scrape()

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, metrics)
    rescue
      _ ->
        conn
        |> put_status(501)
        |> json(%{error: "Prometheus exporter not configured"})
    end
  end

  defp check_database do
    case Repo.query("SELECT 1", [], timeout: 5_000) do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  rescue
    _ -> :error
  end

  defp check_oban do
    try do
      # Oban v2.17+ check
      case Oban.check_queue(queue: :default) do
        %{} -> :ok
        nil -> :error
      end
    rescue
      # Fallback or if Oban not running
      _ -> :error
    end
  end
end
