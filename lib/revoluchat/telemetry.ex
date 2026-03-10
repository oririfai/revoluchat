defmodule Revoluchat.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # WebSocket Channel Metrics
      counter("phoenix.channel_joined.count", tags: [:channel]),
      counter("revoluchat.message.sent.count", tags: [:conversation_id]),
      summary("revoluchat.message.latency", unit: {:native, :millisecond}),

      # Database Metrics
      summary("revoluchat.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("revoluchat.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("revoluchat.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("revoluchat.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("revoluchat.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # Custom business metrics
      counter("revoluchat.upload.completed.count", tags: [:mime_type]),
      counter("revoluchat.notification.sent.count", tags: [:platform]),
      counter("revoluchat.auth.login.count", tags: [:result]),

      # Oban Metrics
      counter("oban.job.start.count", tags: [:queue, :worker]),
      counter("oban.job.stop.count", tags: [:queue, :worker, :state]),
      summary("oban.job.stop.duration", tags: [:queue, :worker], unit: {:native, :millisecond}),

      # VM Metrics
      last_value("vm.memory.total", unit: {:byte, :kilobyte}),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.system_counts.process_count")
    ]
  end

  defp periodic_measurements do
    [
      {Revoluchat.Telemetry, :dispatch_active_connections, []},
      {Revoluchat.Telemetry, :dispatch_oban_queue_depth, []}
    ]
  end

  def dispatch_active_connections do
    # Check if Presence process exists before listing to avoid badarg during startup
    if Process.whereis(RevoluchatWeb.Presence) do
      try do
        count = RevoluchatWeb.Presence.list("chat:*") |> map_size()
        :telemetry.execute([:revoluchat, :connections, :active], %{count: count}, %{})
      catch
        _, _ -> :ok
      end
    else
      :ok
    end
  end

  def dispatch_oban_queue_depth do
    depth = Oban.check_queue(queue: :notifications)[:limit] || 0

    :telemetry.execute([:revoluchat, :oban, :queue_depth], %{depth: depth}, %{
      queue: "notifications"
    })
  rescue
    _ -> :ok
  end
end
