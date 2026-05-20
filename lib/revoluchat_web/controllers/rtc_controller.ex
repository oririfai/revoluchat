defmodule RevoluchatWeb.RTCController do
  use RevoluchatWeb, :controller
  alias Revoluchat.RTC.TurnCredentials

  def index(conn, _params) do
    user_id = conn.assigns[:current_user_id] || "guest"
    creds = TurnCredentials.generate(user_id)

    ice_servers = [
      %{urls: "stun:stun.l.google.com:19302"},
      %{urls: "stun:stun1.l.google.com:19302"},
      %{
        urls: [
          "turn:#{creds.host}:#{creds.port}?transport=udp",
          "turn:#{creds.host}:#{creds.port}?transport=tcp"
        ],
        username: creds.username,
        credential: creds.credential
      }
    ]

    json(conn, %{
      data: %{
        ice_servers: ice_servers
      }
    })
  end
end
