defmodule Revoluchat.Accounts.JwksStrategy do
  @moduledoc """
  Strategy untuk fetch JWKS ke endpoint server authentication punya client.
  """
  require Logger
  use JokenJwks.DefaultStrategyTemplate


  def init_opts(opts) do
    base_url = Application.get_env(:revoluchat, :jwks_url) || System.get_env("JWKS_URL")

    if is_nil(base_url) do
      raise "JWKS_URL tidak di-set di environment atau config.exs."
    end

    Logger.info("JwksStrategy initialized. Base URL: #{base_url}")
    # Log the base_url for debugging purposes
    Logger.debug("JWKS_URL being used: #{base_url}")

    full_url = build_url(base_url)

    opts
    |> Keyword.put(:base_url, base_url)
    |> Keyword.put(:jwks_url, full_url)
    |> Keyword.put(:first_fetch_sync, false)
    |> Keyword.put(:time_interval, 60_000)
  end


  # Helper untuk menyusun URL dengan server_key terbaru dari DB
  defp build_url(base_url) do
    active_key =
      try do
        case Revoluchat.Accounts.get_active_server_key() do
          nil -> nil
          record -> record.key
        end
      rescue
        _ -> nil
      end

    if active_key do
      uri = URI.parse(base_url)
      query = URI.decode_query(uri.query || "") |> Map.put("server_key", active_key)
      full_url = URI.to_string(%URI{uri | query: URI.encode_query(query)})
      Logger.info("Built JWKS URL successfully")
      Logger.info("Active server key found")
      full_url
    else
      Logger.warning("No active server key found, using base URL: #{base_url}")
      base_url
    end
  end

  @impl true
  def after_fetch(signers, _opts, state) do
    Logger.info("JWKS signers successfully fetched and cached. Count: #{if is_map(signers), do: map_size(signers), else: length(signers)}")
    # JokenJwks template uses :signers field in state for internal storage
    new_state = Keyword.put(state, :signers, signers)
    {:ok, signers, new_state}
  end

  @impl true
  def after_error(error, _opts, state) do
    Logger.error("JWKS fetch attempt failed. Reason: #{inspect(error)}")
    # Keep the current state (and signers) even if the fetch failed
    {:error, error, state}
  end

  def refresh_signers do
    base_url = Application.get_env(:revoluchat, :jwks_url) || System.get_env("JWKS_URL")

    if is_nil(base_url) do
      Logger.error("Cannot refresh JWKS signers: JWKS_URL is not set.")
    else
      # Get the active server key from database and build the full URL
      active_key =
        try do
          case Revoluchat.Accounts.get_active_server_key() do
            nil -> nil
            record -> record.key
          end
        rescue
          _ -> nil
        end

      full_url =
        if active_key do
          uri = URI.parse(base_url)
          query = URI.decode_query(uri.query || "") |> Map.put("server_key", active_key)
          URI.to_string(%URI{uri | query: URI.encode_query(query)})
        else
          base_url
        end

      Logger.info("Refreshing JWKS signers")
      Logger.info("Active server key found for refresh")

      # Dynamically extract supported JWS algorithms from JOSE to avoid Enumerable protocol crash (value: nil)
      algs =
        case Enum.find(JOSE.JWA.supports(), &match?({:jws, _}, &1)) do
          {:jws, {:alg, list}} -> list
          _ -> ["RS256"]
        end

      # Lakukan HTTP request manual untuk mem-bypass JokenJwks.check_fetch yang menolak key tanpa kid
      :inets.start()
      :ssl.start()

      case :httpc.request(:get, {String.to_charlist(full_url), []}, [ssl: [verify: :verify_none]], []) do
        {:ok, {{_, status, _}, _headers, body}} when status in 200..299 ->
          try do
            json_body = Jason.decode!(to_string(body))
            keys = json_body["keys"] || []
            
            # Panggil update_signers() yang sudah kita buat. Ini akan meng-inject "dummy_kid"
            # dan menaruh signers ke dalam ETS cache milik JokenJwks.
            update_signers(keys)
            
            Logger.info("JWKS signers successfully refreshed manually. Count: #{length(keys)}")
            {:ok, keys}
          rescue
            e ->
              Logger.error("Failed to parse JWKS JSON response: #{inspect(e)}")
              {:error, :json_parse_error}
          end
          
        {:ok, {{_, status, _}, _, body}} ->
          Logger.error("Failed to refresh JWKS signers. HTTP status: #{status}, Body: #{body}")
          {:error, {:http_status, status}}
          
        {:error, reason} ->
          Logger.error("Failed to refresh JWKS signers. HTTP request error: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @doc """
  Manually update the signers in the JwksStrategy cache.
  This is useful when we already have the signers (e.g. from manual verification)
  and want to cache them immediately without another HTTP fetch.
  """
  def update_signers(signers) do
    GenServer.call(__MODULE__, {:update_signers, signers})
  end

  @doc """
  Retrieve current signers from ETS cache.
  """
  def list_signers do
    alias JokenJwks.DefaultStrategyTemplate.EtsCache
    case EtsCache.get_signers(__MODULE__) do
      [{:signers, signers}] -> {:ok, signers}
      _ -> {:error, :not_fetched}
    end
  end

  @impl GenServer
  def handle_call({:update_signers, raw_keys}, _from, state) do
    Logger.info("Manually updating JWKS signers cache (ETS). New count: #{length(raw_keys)}")

    # We need to parse raw keys into Joken.Signer objects
    # This logic mimics JokenJwks.DefaultStrategyTemplate.validate_and_parse_keys
    algs = state[:jws_supported_algs] || (
      [_, _, {:jws, {:alg, a}}] = JOSE.JWA.supports()
      a
    )
    Logger.info("Supported algorithms for JWKS: #{inspect(algs)}")

    parsed_signers =
      Enum.reduce(raw_keys, %{}, fn key, acc ->
        case parse_key(key, algs) do
          {:ok, signer} ->
            Logger.info("Successfully parsed key with kid: #{key["kid"]}")
            Map.put(acc, key["kid"], signer)
          {:error, reason} ->
            Logger.error("Failed to parse key with kid: #{key["kid"]}. Reason: #{inspect(reason)}")
            acc
        end
      end)

    Logger.info("Total signers successfully parsed: #{map_size(parsed_signers)}")
    if map_size(parsed_signers) > 0 do
      Logger.info("Parsed kids: #{inspect(Map.keys(parsed_signers))}")
    end

    # 1. Update the ETS cache that JokenJwks actually reads from
    alias JokenJwks.DefaultStrategyTemplate.EtsCache
    EtsCache.put_signers(__MODULE__, parsed_signers)
    EtsCache.set_status(__MODULE__, :ok)

    # Verification: Check ETS immediately
    case EtsCache.get_signers(__MODULE__) do
      [{:signers, signers}] ->
        Logger.info("Verified ETS cache update. Kids in ETS: #{inspect(Map.keys(signers))}")
      other ->
        Logger.error("ETS cache verification FAILED! Got: #{inspect(other)}")
    end

    # 2. Update GenServer state just in case
    new_state = state
                |> Keyword.put(:signers, parsed_signers)

    {:reply, :ok, new_state}
  end

  defp parse_key(key, supported_algs) do
    # Jika server JWKS klien tidak memberikan kid, kita buatkan dummy kid
    key = if is_binary(key["kid"]), do: key, else: Map.put(key, "kid", "dummy_kid_#{:os.system_time(:microsecond)}")

    cond do
      key["use"] == "enc" -> {:error, :encryption_key}
      not is_binary(key["kid"]) -> {:error, :missing_kid}
      not is_binary(key["alg"]) -> {:error, :missing_alg}
      not (key["alg"] in supported_algs) -> {:error, :unsupported_algorithm}
      true ->
        signer = Joken.Signer.create(key["alg"], key)
        {:ok, signer}
    end
  end
end
