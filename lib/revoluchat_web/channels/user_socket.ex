defmodule RevoluchatWeb.UserSocket do
  use Phoenix.Socket

  require Logger
  alias Revoluchat.Accounts.ApiKey

  # Channel "tenant:*" will be routed to ChatChannel
  # where the suffix ":room:ID" is parsed manually string.split
  channel("tenant:*", RevoluchatWeb.ChatChannel)
  channel("user:*", RevoluchatWeb.UserChannel)

  @impl true
  def connect(%{"token" => token, "api_key" => api_key} = _params, socket, _connect_info) do
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
end
