defmodule Revoluchat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RevoluchatWeb.Telemetry,
      Revoluchat.Telemetry,
      {TelemetryMetricsPrometheus,
       [metrics: Revoluchat.Telemetry.metrics() ++ RevoluchatWeb.Telemetry.metrics()]},
      Revoluchat.Repo,
      # MySQL — User service DB (read-only, untuk verify user exist)
      Revoluchat.UserRepo,
      {DNSCluster, query: Application.get_env(:revoluchat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Revoluchat.PubSub},
      # Presence (untuk user online status)
      RevoluchatWeb.Presence,
      # Oban — background job processing
      {Oban, Application.fetch_env!(:revoluchat, Oban)},
      # gRPC Server
      {GRPC.Server.Supervisor,
       endpoint: Revoluchat.Grpc.Endpoint, port: 50051, start_server: true},
      # Start to serve requests, typically the last entry
      RevoluchatWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Revoluchat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RevoluchatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
