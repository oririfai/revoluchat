defmodule RevoluchatWeb.RTCController do
  use RevoluchatWeb, :controller

  def index(conn, _params) do
    ice_servers = Application.get_env(:revoluchat, :ice_servers, [
      %{urls: "stun:stun.l.google.com:19302"},
      %{urls: "stun:stun1.l.google.com:19302"},
      %{urls: "stun:stun2.l.google.com:19302"}
    ])

    json(conn, %{
      data: %{
        ice_servers: ice_servers
      }
    })
  end
end
