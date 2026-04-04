defmodule Revoluchat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Revoluchat.Repo,
      {DNSCluster, query: Application.get_env(:revoluchat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Revoluchat.PubSub},
      # Presence (untuk user online status) must start before Telemetry
      RevoluchatWeb.Presence,
      RevoluchatWeb.Telemetry,
      Revoluchat.Telemetry,
      {TelemetryMetricsPrometheus,
       [metrics: Revoluchat.Telemetry.metrics() ++ RevoluchatWeb.Telemetry.metrics()]},
      # Oban — background job processing
      {Oban, Application.fetch_env!(:revoluchat, Oban)},
      # gRPC Server
      {GRPC.Server.Supervisor,
       endpoint: Revoluchat.Grpc.Endpoint, port: 50051, start_server: true},
      # JWKS Strategy (untuk dynamic fetch public keys dari user-be)
      Revoluchat.Accounts.JwksStrategy,
      # gRPC Client Supervisor (untuk call ke user service)
      {GRPC.Client.Supervisor, []},
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
