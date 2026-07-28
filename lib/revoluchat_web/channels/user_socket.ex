defmodule RevoluchatWeb.UserSocket do
  use Phoenix.Socket

  require Logger
  alias Revoluchat.Accounts.ApiKey

  # Channel "tenant:*" will be routed to ChatChannel
  # where the suffix ":room:ID" is parsed manually string.split
  channel("tenant:*", RevoluchatWeb.ChatChannel)
  channel("user:*", RevoluchatWeb.UserChannel)

  @impl true
  def connect(%{"token" => token, "api_key" => api_key} = _params, socket, connect_info) do
    with {:api_key, %ApiKey{app_id: api_key_app_id}} <-
           {:api_key, Revoluchat.Accounts.get_api_key_by_key(api_key)},
         {:token, {:ok, claims}} <- {:token, Revoluchat.Accounts.verify_token(token)},
         _log <- Logger.warning("Comparing App ID -> From DB: #{inspect(api_key_app_id)} (Key: #{inspect(api_key)}) | From Token: #{inspect(claims.app_id)}"),
         {:app_check, true} <-
           {:app_check, is_nil(claims.app_id) or claims.app_id == api_key_app_id},
         {:user, {:ok, user}} <- {:user, Revoluchat.Accounts.verify_user_exists(claims.user_id)} do
      user_id = claims.user_id
      # Prioritize app_id from token claims, fallback to API Key app_id
      app_id = claims.app_id || api_key_app_id

      # Keep user_id as string (UUID)
      user_id = to_string(user_id)

      # AUTOMATIC REGISTRATION:
      # Inisialisasi data pengguna dan registrasikan ke tabel user_chats jika belum ada
      # Update juga data profil terbaru (name, phone, avatar, dll)
      case Revoluchat.Accounts.ensure_user_chat_registered(user_id, app_id, user) do
        {:ok, _user_chat} ->
          socket =
            socket
            |> assign(:user_id, user_id)
            |> assign(:app_id, app_id)
            |> assign(:token, token)
            |> assign(:api_key, api_key)

          # Safely record user footprint log asynchronously
          Task.start(fn ->
            user_name = case user do
              %{name: n} when is_binary(n) -> n
              %{"name" => n} when is_binary(n) -> n
              _ -> "User #{user_id}"
            end
            user_phone = case user do
              %{phone: p} when is_binary(p) -> p
              %{"phone" => p} when is_binary(p) -> p
              _ -> "-"
            end
            
            {ip_address, user_agent} = extract_connect_info(connect_info, _params)
            Revoluchat.Accounts.log_user_activity(user_id, user_name, user_phone, ip_address, user_agent, "success")
          end)

          Logger.info("Socket connected: user_id=#{user_id}, app_id=#{app_id}")
          {:ok, socket}

        {:error, reason} ->
          Logger.error(
            "Socket connection failed: Could not register user #{user_id}. Reason: #{inspect(reason)}"
          )

          :error
      end
    else
      {:api_key, nil} ->
        Logger.warning("WebSocket rejected: Invalid or inactive API Key")
        :error

      {:token, {:error, reason}} ->
        Logger.warning("WebSocket rejected: Token verification failed")
        :error

      {:app_check, false} ->
        Logger.error("WebSocket rejected: Mismatch between App ID, API Key and Token.")
        :error

      {:user, {:error, :user_not_found}} ->
        Logger.error("WebSocket rejected: User ID not found in User Service.")
        :error

      {:user, {:error, {:suspended, suspended_until}}} ->
        Logger.error("WebSocket rejected: User is currently suspended until #{suspended_until}.")
        :error

      {:user, {:error, :suspended}} ->
        Logger.error("WebSocket rejected: User is currently suspended.")
        :error

      error ->
        Logger.error("WebSocket rejected: Unknown error. #{inspect(error)}")
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  # Identitas socket untuk disconnect paksa
  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"

  defp extract_connect_info(connect_info, params) do
    peer_data = Map.get(connect_info, :peer_data, %{})
    x_headers = Map.get(connect_info, :x_headers, [])

    ip =
      case Enum.find(x_headers, fn {k, _v} -> String.downcase(k) in ["x-forwarded-for", "x-real-ip"] end) do
        {_k, val} -> val |> String.split(",") |> List.first() |> String.trim()
        _ ->
          case Map.get(peer_data, :address) do
            ip_tuple when is_tuple(ip_tuple) -> :inet.ntoa(ip_tuple) |> to_string()
            _ -> "127.0.0.1"
          end
      end

    user_agent =
      cond do
        ua = Map.get(connect_info, :user_agent) ->
          ua

        header_ua = Enum.find_value(x_headers, fn {k, v} -> if String.downcase(k) == "user-agent", do: v end) ->
          header_ua

        param_ua = Map.get(params || %{}, "user_agent") || Map.get(params || %{}, "user-agent") ->
          param_ua

        true ->
          "Android App / Mobile SDK"
      end

    {ip, user_agent}
  end
end
