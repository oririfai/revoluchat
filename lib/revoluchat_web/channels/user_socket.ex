defmodule RevoluchatWeb.UserSocket do
  use Phoenix.Socket

  require Logger

  # Channel "tenant:*" will be routed to ChatChannel
  # where the suffix ":room:ID" is parsed manually string.split
  channel "tenant:*", RevoluchatWeb.ChatChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    # 1. License Check (Circuit Breaker)
    if not Revoluchat.Licensing.Core.is_valid?() do
      Logger.error("WebSocket connection rejected: SDK License is invalid or expired.")
      :error
    else
      # 2. Verify JWT via JWKS (Stateless)
      case Revoluchat.Accounts.verify_token(token) do
        {:ok, %{user_id: user_id, app_id: app_id}} ->
          socket =
            socket
            |> assign(:user_id, user_id)
            |> assign(:app_id, app_id)

          # --- Observability: Track active connections per tenant ---
          :telemetry.execute(
            [:revoluchat, :connections, :active],
            %{count: 1},
            %{app_id: app_id}
          )

          {:ok, socket}

        _ ->
          :error
      end
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  # Identitas socket untuk disconnect paksa
  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
