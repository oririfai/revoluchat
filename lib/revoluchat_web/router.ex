defmodule RevoluchatWeb.Router do
  use RevoluchatWeb, :router

  # ─── Pipelines ───────────────────────────────────────────────────────────────

  pipeline :api do
    plug(RevoluchatWeb.Plugs.SecurityHeaders)
    plug(:accepts, ["json"])

    plug(CORSPlug)

    # (CORS details configured in config/runtime.exs or config.exs natively)
  end

  pipeline :authenticated do
    plug(RevoluchatWeb.Plugs.AuthPlug)
  end

  pipeline :message_rate_limit do
    plug(RevoluchatWeb.Plugs.HttpRateLimiter,
      scale_ms: 60_000,
      limit: 60,
      key_type: :user_id
    )
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {RevoluchatWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  # ─── Health Checks (tanpa auth) ──────────────────────────────────────────────

  scope "/", RevoluchatWeb do
    pipe_through(:api)

    get("/health", HealthController, :liveness)
    get("/health/ready", HealthController, :readiness)
    get("/health/metrics", HealthController, :metrics)
    post("/api/debug/upload", DebugController, :upload)
  end

  scope "/admin", RevoluchatWeb do
    pipe_through(:browser)

    get("/login", LoginController, :index)
    post("/login", SessionController, :create)
    delete("/logout", SessionController, :delete)

    live_session :admin, on_mount: [{RevoluchatWeb.AdminAuth, :default}] do
      live("/", AdminDashboardLive, :summary)
      live("/activity", AdminDashboardLive, :activity)
      live("/setting", AdminDashboardLive, :setting)
      live("/documentation", AdminDashboardLive, :documentation)
      live("/apikeys", AdminDashboardLive, :api_keys)
      live("/serverkeys", AdminDashboardLive, :server_keys)
    end
  end

  # ─── API v1 ──────────────────────────────────────────────────────────────────

  scope "/api/v1", RevoluchatWeb do
    pipe_through([:api, :authenticated])

    # Conversations
    get("/conversations", ConversationController, :index)
    post("/conversations", ConversationController, :create)
    get("/conversations/:id", ConversationController, :show)

    # Contacts
    get("/contacts", ContactController, :index)
    post("/contacts", ContactController, :create)

    # Push tokens
    post("/push_tokens", PushTokenController, :create)
    delete("/push_tokens/:token", PushTokenController, :delete)

    # Attachments
    post("/attachments/init", AttachmentController, :init)
    put("/attachments/:id/upload", AttachmentController, :upload)
    post("/attachments/:id/confirm", AttachmentController, :confirm)
    get("/attachments/:id/download", AttachmentController, :download)
    get("/attachments/:id/show", AttachmentController, :show)

    # Analytics / Admin Dashboard
    get("/analytics/active_connections", AnalyticsController, :active_connections)
    get("/analytics/message_throughput", AnalyticsController, :message_throughput)
    get("/analytics/active_conversations", AnalyticsController, :active_conversations)

    # RTC Config
    get("/rtc_config", RTCController, :index)

    # Call History
    get("/calls/history", CallController, :history)
    delete("/calls/history", CallController, :delete_history)
  end

  scope "/api/v1", RevoluchatWeb do
    pipe_through([:api, :authenticated, :message_rate_limit])

    # Messages (nested under conversation)
    get("/conversations/:conversation_id/messages", MessageController, :index)
    post("/conversations/:conversation_id/messages", MessageController, :create)
  end

  # ─── Dev Dashboard ───────────────────────────────────────────────────────────

  if Application.compile_env(:revoluchat, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through([:fetch_session, :protect_from_forgery])
      live_dashboard("/dashboard", metrics: RevoluchatWeb.Telemetry)
    end
  end
end
