defmodule RevoluchatWeb.AnalyticsController do
  use RevoluchatWeb, :controller

  alias Revoluchat.Chat

  action_fallback RevoluchatWeb.FallbackController

  @doc """
  Mendapatkan total active WebSocket connections untuk tenant (app_id).
  Karena Phoenix tersebar, metrik telemetri yang diekspor via PromEx biasanya
  lebih disarankan untuk Production. Endpoint REST ini untuk dashboard admin sederhana.
  """
  def active_connections(conn, _params) do
    app_id = conn.assigns.current_app_id

    # Untuk simplifikasi MVP, kita hitung jumlah child di PubSub untuk tenant ini
    # Di skala 100k+, PromEx / metrics exporter lebih direkomendasikan.

    conn
    |> json(%{
      success: true,
      app_id: app_id,
      metric: "active_connections",
      # Dummy/Placeholder for REST. In real scenario, export via Prometheus.
      value: "See Prometheus/Grafana /metrics endpoint for realtime clusters count."
    })
  end

  @doc """
  Total akumulasi kiriman pesan dari tenant ini.
  """
  def message_throughput(conn, _params) do
    app_id = conn.assigns.current_app_id
    total_messages = Chat.count_messages_for_app(app_id)

    conn
    |> json(%{
      success: true,
      app_id: app_id,
      metric: "message_throughput",
      value: total_messages
    })
  end

  @doc """
  Total percakapan yang punya aktivitas.
  """
  def active_conversations(conn, _params) do
    app_id = conn.assigns.current_app_id
    active_convs = Chat.count_active_conversations(app_id)

    conn
    |> json(%{
      success: true,
      app_id: app_id,
      metric: "active_conversations",
      value: active_convs
    })
  end
end
