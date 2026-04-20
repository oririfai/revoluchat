# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :revoluchat,
  ecto_repos: [Revoluchat.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.21.5",
  revoluchat: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  revoluchat: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures the endpoint
config :revoluchat, RevoluchatWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: RevoluchatWeb.ErrorHTML, json: RevoluchatWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Revoluchat.PubSub,
  live_view: [signing_salt: "VQbln3WO"]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: {Revoluchat.Logger.Formatter, :format},
  metadata: [:request_id, :user_id, :conversation_id, :message_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# ─── Oban — Background Jobs ──────────────────────────────────────────────────
config :revoluchat, Oban,
  repo: Revoluchat.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    Oban.Plugins.Lifeline
  ],
  queues: [
    default: 10,
    notifications: 20,
    broadcast: 10,
    attachments: 5,
    scan: 3
  ]

# ─── Auth Verification (JWKS) ──────────────────────────────────────────────────
# JWKS_URL adalah runtime config — dikonfigurasi di runtime.exs
# sehingga Docker container bisa membacanya dari env variable saat runtime.

# ─── Object Storage (MinIO / S3) ─────────────────────────────────────────────
config :ex_aws,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID", "minioadmin"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY", "minioadmin"),
  region: System.get_env("AWS_REGION", "us-east-1")

config :revoluchat, :storage,
  presigned_url_expiry: 3600

# ─── Rate Limiting (Hammer) ──────────────────────────────────────────────────
config :hammer,
  backend:
    {Hammer.Backend.ETS,
     [
       expiry_ms: 60_000 * 60 * 4,
       cleanup_interval_ms: 60_000 * 10
     ]}

# ─── WebRTC ICE Servers ──────────────────────────────────────────────────────
# Default public STUN as fallback. Production TURNs should be set via ICE_SERVERS env.
config :revoluchat, :ice_servers, [
  %{urls: "stun:stun.l.google.com:19302"}
]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
