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
    with {:api_key, %ApiKey{app_id: api_key_app_id}} <- {:api_key, Revoluchat.Accounts.get_api_key_by_key(api_key)},
         {:token, {:ok, claims}} <- {:token, Revoluchat.Accounts.verify_token(token)},
         {:user, {:ok, user}} <- {:user, Revoluchat.Accounts.verify_user_exists(claims.user_id)} do
      
      user_id = claims.user_id
      # Prioritize app_id from token claims, fallback to API Key app_id
      app_id = claims.app_id || api_key_app_id
      
      # ENSURE user_id is integer for standard DB compatibility if it's numeric
      user_id =
        cond do
          is_integer(user_id) -> user_id
          is_binary(user_id) and Regex.match?(~r/^\d+$/, user_id) -> String.to_integer(user_id)
          is_binary(user_id) and Regex.match?(~r/^\d+\.0$/, user_id) -> 
            user_id |> String.replace(".0", "") |> String.to_integer()
          is_float(user_id) -> trunc(user_id)
          true -> user_id
        end

      # AUTOMATIC REGISTRATION: 
      # Inisialisasi data pengguna dan registrasikan ke tabel user_chats jika belum ada
      # Update juga data profil terbaru (name, phone, avatar)
      case Revoluchat.Accounts.ensure_user_chat_registered(user_id, app_id, user) do
        {:ok, _user_chat} ->
          socket =
            socket
            |> assign(:user_id, user_id)
            |> assign(:app_id, app_id)

          Logger.info("Socket connected: user_id=#{user_id}, app_id=#{app_id}")
          {:ok, socket}
        
        {:error, reason} ->
          Logger.error("Socket connection failed: Could not register user #{user_id}. Reason: #{inspect(reason)}")
          :error
      end
    else
      {:api_key, nil} ->
        Logger.error("WebSocket rejected: Invalid or inactive API Key: #{api_key}")
        :error

      {:token, {:error, reason}} ->
        Logger.error("WebSocket rejected: Token verification failed. Reason: #{inspect(reason)}")
        :error

      {:user, {:error, :user_not_found}} ->
        Logger.error("WebSocket rejected: User ID not found in User Service (revolu-be) via gRPC.")
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
