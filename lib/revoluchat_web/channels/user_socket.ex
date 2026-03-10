defmodule RevoluchatWeb.UserSocket do
  use Phoenix.Socket

  require Logger

  # Channel "tenant:*" will be routed to ChatChannel
  # where the suffix ":room:ID" is parsed manually string.split
  channel("tenant:*", RevoluchatWeb.ChatChannel)

  @impl true
  def connect(%{"token" => token} = params, socket, _connect_info) do
    # 1. License Check (Circuit Breaker)
    case Revoluchat.Licensing.Core.get_active_license() do
      nil ->
        Logger.error("WebSocket rejected: No license found.")
        :error

      license ->
        if Revoluchat.Licensing.Core.is_valid?() do
          # 2. Verify JWT via JWKS (Stateless)
          case Revoluchat.Accounts.verify_token(token) do
            {:ok, %{user_id: user_id, app_id: app_id}} ->
              # ENSURE user_id is integer for standard DB compatibility if it's numeric
              user_id =
                if is_binary(user_id) and Regex.match?(~r/^\d+$/, user_id),
                  do: String.to_integer(user_id),
                  else: user_id

              # 3. Stateful User Check via gRPC to Main App
              case Revoluchat.Accounts.verify_user_exists(user_id) do
                {:ok, _user} ->
                  socket =
                    socket
                    |> assign(:user_id, user_id)
                    |> assign(:app_id, app_id)

                  Logger.info("Socket connected for user #{user_id}")
                  {:ok, socket}

                {:error, :user_not_found} ->
                  Logger.error(
                    "WebSocket rejected: User #{user_id} not found in main app via gRPC."
                  )

                  :error

                {:error, reason} ->
                  Logger.error(
                    "WebSocket rejected: gRPC error for user #{user_id}: #{inspect(reason)}"
                  )

                  :error
              end

            _ ->
              :error
          end
        else
          Logger.error(
            "WebSocket rejected: License invalid/expired. Status: #{license.status}, Valid Until: #{license.valid_until}"
          )

          :error
        end
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  # Identitas socket untuk disconnect paksa
  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
