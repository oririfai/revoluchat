defmodule Revoluchat.LiveKit.Health do
  @moduledoc """
  Monitors the health and connectivity status of the LiveKit WebRTC Server.
  Uses ETS caching with a 15-second TTL to avoid network spam and server load.
  """
  require Logger

  @cache_table :livekit_health_cache
  @cache_ttl_ms 15_000

  @doc """
  Performs a low-latency TCP health check with a 15-second ETS cache TTL.
  Returns `{:ok, info}` when online or `{:error, info}` when offline.
  """
  def check_health do
    ensure_cache_table()
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@cache_table, :last_health) do
      [{:last_health, cached_result, timestamp}] when now - timestamp < @cache_ttl_ms ->
        cached_result

      _ ->
        result = do_check_health()
        try do
          :ets.insert(@cache_table, {:last_health, result, now})
        rescue
          _ -> :ok
        end
        result
    end
  end

  defp ensure_cache_table do
    if :ets.info(@cache_table) == :undefined do
      try do
        :ets.new(@cache_table, [:named_table, :public, :set, read_concurrency: true])
      rescue
        _ -> :ok
      end
    end
  end

  defp do_check_health do
    config = Application.get_env(:revoluchat, :livekit, [])
    url = Keyword.get(config, :url, System.get_env("LIVEKIT_URL") || "ws://localhost:7880")

    # Parse host & port from LiveKit URL
    clean_url = String.replace(url, ~r/^wss?:\/\//, "http://")
    uri = URI.parse(clean_url)
    host = uri.host || "localhost"
    port = uri.port || 7880

    start_time = System.monotonic_time(:millisecond)

    case :gen_tcp.connect(String.to_charlist(host), port, [:binary, active: false], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        rtt_ms = System.monotonic_time(:millisecond) - start_time

        {:ok,
         %{
           status: :online,
           host: host,
           port: port,
           url: url,
           rtt_ms: rtt_ms
         }}

      {:error, reason} ->
        Logger.warning("[LiveKit Health] Connection check failed to #{host}:#{port} - #{inspect(reason)}")

        {:error,
         %{
           status: :offline,
           host: host,
           port: port,
           url: url,
           reason: inspect(reason)
         }}
    end
  end
end
