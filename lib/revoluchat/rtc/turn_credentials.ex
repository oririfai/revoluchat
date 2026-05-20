defmodule Revoluchat.RTC.TurnCredentials do
  @moduledoc """
  Generates time-limited dynamic credentials for CoTURN (VM C).
  """

  @doc """
  Generates a dynamic TURN username and credential (password).
  Username format: <unix_timestamp>:<user_id>
  Password format: Base64(HMAC-SHA1(username, static_auth_secret))
  """
  def generate(user_id, ttl \\ 86400) do
    config = Application.get_env(:revoluchat, :coturn, [])
    host = Keyword.get(config, :host, "localhost")
    port = Keyword.get(config, :port, 3478)
    secret = Keyword.get(config, :secret, "secret")

    # Expiry timestamp (seconds)
    expiry = System.system_time(:second) + ttl
    username = "#{expiry}:#{user_id}"

    # Generate HMAC-SHA1 signature
    digest = :crypto.mac(:hmac, :sha, secret, username)
    credential = Base.encode64(digest)

    %{
      host: host,
      port: port,
      username: username,
      credential: credential
    }
  end
end
