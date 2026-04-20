import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/revoluchat start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :revoluchat, RevoluchatWeb.Endpoint, server: true
end

cors_origins =
  case System.get_env("CORS_ALLOWED_ORIGINS") do
    nil -> "*"
    origins -> String.split(origins, ",")
  end

config :cors_plug,
  origin: cors_origins,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  headers: ["Authorization", "Content-Type", "Accept", "Origin"]

# ─── JWKS URL (Runtime, dibaca saat container start) ───────────────────────────
jwks_url = System.get_env("JWKS_URL") || "http://host.docker.internal:8089/jwks"
config :revoluchat, :jwks_url, jwks_url

# ─── WebRTC ICE Servers (Dynamic via Environment Var) ─────────────────────────
if ice_servers_json = System.get_env("ICE_SERVERS") do
  case Jason.decode(ice_servers_json) do
    {:ok, servers} -> 
      # Convert string keys to atoms for Elixir Map consistency
      atomized_servers = Enum.map(servers, fn entry ->
        for {k, v} <- entry, into: %{}, do: {String.to_existing_atom(k), v}
      end)
      config :revoluchat, :ice_servers, atomized_servers
    _ -> 
      :ok
  end
end

# ─── LiveKit Server Config ────────────────────────────────────────────────────
config :revoluchat, :livekit,
  url: System.get_env("LIVEKIT_URL") || "http://localhost:7880",
  api_key: System.get_env("LIVEKIT_API_KEY") || "devkey",
  api_secret: System.get_env("LIVEKIT_API_SECRET") || "secret"

# ─── Object Storage Config (minio, cloudflareR2, cloudinary) ──────────────────
storage_mode = System.get_env("STORAGE_ADAPTOR_MODE") || "minio"

case storage_mode do
  "minio" ->
    minio_host = System.get_env("MINIO_HOST") || "minio"
    minio_public_host = System.get_env("MINIO_PUBLIC_HOST") || minio_host
    minio_port = String.to_integer(System.get_env("MINIO_PORT") || "9000")

    config :ex_aws,
      access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
      secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
      region: System.get_env("AWS_REGION") || "us-east-1",
      s3: [
        scheme: "http://",
        host: minio_host,
        port: minio_port
      ]

    config :revoluchat, :storage,
      provider: :s3,
      bucket: System.get_env("STORAGE_BUCKET") || "revoluchat",
      presigned_url_expiry: 3600,
      public_host: minio_public_host

  "cloudflareR2" ->
    account_id = System.get_env("R2_ACCOUNT_ID")

    config :ex_aws,
      access_key_id: System.get_env("R2_ACCESS_KEY_ID"),
      secret_access_key: System.get_env("R2_SECRET_ACCESS_KEY"),
      region: "auto",
      s3: [
        scheme: "https://",
        host: "#{account_id}.r2.cloudflarestorage.com",
        port: 443
      ]

    config :revoluchat, :storage,
      provider: :r2,
      bucket: System.get_env("R2_BUCKET"),
      presigned_url_expiry: 3600,
      public_host: System.get_env("R2_PUBLIC_DOMAIN") || "#{account_id}.r2.cloudflarestorage.com"

  "cloudinary" ->
    cloudinary_url = System.get_env("CLOUDINARY_URL")

    config_data =
      if cloudinary_url && String.starts_with?(cloudinary_url, "cloudinary://") do
        uri = URI.parse(cloudinary_url)
        [api_key, api_secret] = String.split(uri.userinfo || ":", ":")

        %{
          cloud_name: uri.host,
          api_key: api_key,
          api_secret: api_secret
        }
      else
        %{
          cloud_name: System.get_env("CLOUDINARY_CLOUD_NAME"),
          api_key: System.get_env("CLOUDINARY_API_KEY"),
          api_secret: System.get_env("CLOUDINARY_API_SECRET")
        }
      end

    if config_data.cloud_name && config_data.api_key && config_data.api_secret do
      config :revoluchat, :storage,
        provider: :cloudinary,
        cloud_name: config_data.cloud_name,
        api_key: config_data.api_key,
        api_secret: config_data.api_secret

      config :cloudinex,
        api_key: config_data.api_key,
        secret: config_data.api_secret,
        cloud_name: config_data.cloud_name
    else
      # Fallback to empty if not fully configured, though the adapter should handle nil
      config :revoluchat, :storage, provider: :cloudinary
    end

  mode ->
    # Fallback/Warning for invalid mode
    if config_env() != :test do
      IO.warn("Unsupported STORAGE_ADAPTOR_MODE: #{inspect(mode)}. Storage might not function correctly.")
    end
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :revoluchat, Revoluchat.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    sockets_options: maybe_ipv6

  # User Service Integration via gRPC handled by Revoluchat.Grpc.UserClient


  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :revoluchat, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :revoluchat, RevoluchatWeb.Endpoint,
    url: [host: host, port: port, scheme: "http"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    check_origin: false

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :revoluchat, RevoluchatWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :revoluchat, RevoluchatWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
