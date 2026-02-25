# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :revoluchat,
  ecto_repos: [Revoluchat.Repo, Revoluchat.UserRepo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :revoluchat, RevoluchatWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: RevoluchatWeb.ErrorJSON],
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
# Saat client mendeploy Revoluchat, mereka HARUS mengisi JWKS_URL.
# URL ini menunjuk ke endpoint auth mereka.
config :revoluchat,
       :jwks_url,
       System.get_env("JWKS_URL", "http://localhost:4000/.well-known/jwks.json")

# ─── Object Storage (MinIO / S3) ─────────────────────────────────────────────
config :ex_aws,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID", "minioadmin"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY", "minioadmin"),
  region: System.get_env("AWS_REGION", "us-east-1")

config :revoluchat, :storage,
  bucket: System.get_env("STORAGE_BUCKET", "revoluchat"),
  presigned_url_expiry: 3600

# ─── Rate Limiting (Hammer) ──────────────────────────────────────────────────
config :hammer,
  backend:
    {Hammer.Backend.ETS,
     [
       expiry_ms: 60_000 * 60 * 4,
       cleanup_interval_ms: 60_000 * 10
     ]}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
