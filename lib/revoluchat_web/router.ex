defmodule RevoluchatWeb.CORSConfig do
  def allowed_origins do
    Application.get_env(:cors_plug, :origin, "*")
  end
end

defmodule RevoluchatWeb.Router do
  use RevoluchatWeb, :router

  # ─── Pipelines ───────────────────────────────────────────────────────────────

  pipeline :api do
    plug(RevoluchatWeb.Plugs.SecurityHeaders)
    plug(:accepts, ["json"])

    plug(CORSPlug, origin: &RevoluchatWeb.CORSConfig.allowed_origins/0)

    # (CORS details configured dynamically at runtime)
  end

  pipeline :authenticated do
    plug(RevoluchatWeb.Plugs.AuthPlug)
  end

  pipeline :api_global_rate_limit do
    plug(RevoluchatWeb.Plugs.HttpRateLimiter,
      scale_ms: 60_000,
      limit: 120,
      key_type: :user_id
    )
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
    plug(RevoluchatWeb.Plugs.AdminAutoLogin)
    plug(RevoluchatWeb.Plugs.AdminSessionTimeout)
    plug(RevoluchatWeb.Plugs.AdminSessionPinning)
    plug(:put_root_layout, html: {RevoluchatWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :admin_login_rate_limit do
    plug(RevoluchatWeb.Plugs.AdminLoginRateLimiter)
  end

  # ─── Health Checks (tanpa auth) ──────────────────────────────────────────────

  scope "/", RevoluchatWeb do
    pipe_through(:api)

    get("/health", HealthController, :liveness)
    get("/health/ready", HealthController, :readiness)
    get("/health/metrics", HealthController, :metrics)
  end

  scope "/admin", RevoluchatWeb do
    pipe_through([:browser, :admin_login_rate_limit])

    post("/login", SessionController, :create)
  end

  scope "/admin", RevoluchatWeb do
    pipe_through(:browser)

    get("/login", LoginController, :index)
    delete("/logout", SessionController, :delete)

    live_session :admin, on_mount: [{RevoluchatWeb.AdminAuth, :default}] do
      live("/", AdminDashboardLive, :summary)
      live("/activity", AdminDashboardLive, :activity)
      live("/users", AdminDashboardLive, :users)
      live("/setting", AdminDashboardLive, :setting)
      live("/documentation", AdminDashboardLive, :documentation)
      live("/apikeys", AdminDashboardLive, :api_keys)
      live("/serverkeys", AdminDashboardLive, :server_keys)
      live("/admins", AdminDashboardLive, :admins)
      live("/logs", AdminDashboardLive, :logs)
    end
  end

  # ─── API v1 ──────────────────────────────────────────────────────────────────

  scope "/api/v1", RevoluchatWeb do
    pipe_through([:api, :authenticated, :api_global_rate_limit])

    # Conversations
    get("/conversations", ConversationController, :index)
    post("/conversations", ConversationController, :create)
    get("/conversations/:id", ConversationController, :show)
    delete("/conversations/:id", ConversationController, :delete)
    delete("/conversations", ConversationController, :delete)
    post("/conversations/archive", ConversationController, :archive)
    post("/conversations/unarchive", ConversationController, :unarchive)

    # Contacts
    get("/contacts", ContactController, :index)
    post("/contacts", ContactController, :create)
    post("/contacts/sync", ContactController, :sync)

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

    # Groups
    post("/groups", GroupController, :create)
    get("/groups/:id", GroupController, :show)
    put("/groups/:id", GroupController, :update)
    post("/groups/:id/members", GroupController, :add_members)
    delete("/groups/:id/members/:user_id", GroupController, :remove_member)
    post("/groups/:id/leave", GroupController, :leave)
    post("/groups/:id/mute", GroupController, :mute)
    post("/groups/:id/accept", GroupController, :accept)

    # E2EE Keys
    post("/e2ee/keys/register", E2EEController, :register)
    get("/e2ee/keys/bundle/:user_id", E2EEController, :get_bundle)
    post("/e2ee/keys/replenish", E2EEController, :replenish)

    # Status
    get("/statuses", StatusController, :index)
    post("/statuses", StatusController, :create)
    post("/statuses/:id/view", StatusController, :view)
    delete("/statuses/:id", StatusController, :delete)
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

