defmodule RevoluchatWeb.Presence do
  use Phoenix.Presence,
    otp_app: :revoluchat,
    pubsub_server: Revoluchat.PubSub
end
