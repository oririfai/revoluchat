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

# ─── Object Storage (MinIO) Config ──────────────────────────────────────────
# Config ini dijalankan di semua env (dev/prod) saat runtime
if System.get_env("AWS_ACCESS_KEY_ID") do
  minio_host = System.get_env("MINIO_HOST") || "minio"
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
    bucket: System.get_env("STORAGE_BUCKET") || "revoluchat",
    presigned_url_expiry: 3600
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

  # Konfigurasi UserRepo (MySQL) dari User Service
  mysql_host = System.get_env("DB_MYSQL_HOST") || raise "DB_MYSQL_HOST missing"
  mysql_port = String.to_integer(System.get_env("DB_MYSQL_PORT") || "25060")
  mysql_user = System.get_env("DB_MYSQL_USER") || raise "DB_MYSQL_USER missing"
  mysql_pass = System.get_env("DB_MYSQL_PASSWORD") || raise "DB_MYSQL_PASSWORD missing"
  mysql_name = System.get_env("DB_MYSQL_NAME") || "nukar_api"

  config :revoluchat, Revoluchat.UserRepo,
    username: mysql_user,
    password: mysql_pass,
    hostname: mysql_host,
    port: mysql_port,
    database: mysql_name,
    pool_size: String.to_integer(System.get_env("MYSQL_POOL_SIZE") || "5"),
    # DigitalOcean managed DB butuh SSL biasanya (atau setidaknya supported)
    ssl: false

  # Config RSA Public Key Path
  rsa_public_key_path = System.get_env("RSA_PUBLIC_KEY_PATH")

  if rsa_public_key_path do
    config :revoluchat, :rsa_public_key_path, rsa_public_key_path
  end

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
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

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
