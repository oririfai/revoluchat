alias Revoluchat.Repo
alias Revoluchat.Chat.Conversation

IO.puts("Starting seed...")

# 1. Conversation User 1 <-> User 2
# Note: User harus ada di User Service (MySQL). Kita asumsikan ID 1 dan 2 ada.

# Cek apakah sudah ada conversation antara 1 & 2 (atau 2 & 1)
query = import Ecto.Query

existing =
  Repo.one(
    from(c in Conversation,
      where: (c.user_a_id == "1" and c.user_b_id == "2") or (c.user_a_id == "2" and c.user_b_id == "1"),
      limit: 1
    )
  )

if existing do
  IO.puts("✅ Conversation already exists.")
  IO.puts("   ID: #{existing.id}")
  IO.puts("   Users: #{existing.user_a_id} <-> #{existing.user_b_id}")
else
  {:ok, conv} =
    Repo.insert(%Conversation{
      user_a_id: "1",
      user_b_id: "2",
      last_activity_at: DateTime.utc_now()
    })

  IO.puts("✅ Created NEW Conversation.")
  IO.puts("   ID: #{conv.id}")
  IO.puts("   Users: 1 <-> 2")
end


# 3. Default Admin Creation
alias Revoluchat.Accounts.Admin

admin_email = "admin@revoluchat.com"
admin_password = "password123"

unless Repo.get_by(Admin, email: admin_email) do
  %Admin{}
  |> Admin.changeset(%{email: admin_email, password: admin_password})
  |> Repo.insert!()

  IO.puts("✅ Created NEW default admin: #{admin_email} / #{admin_password}")
end

# 4. Default App Preferences & Global Server Limits
default_prefs = [
  {"max_message_size", "1048576"},
  {"rate_limit_per_sec", "5"},
  {"max_attachment_size_mb", "25"},
  {"app_version", "1.0.0"},
  {"playstore_url", "https://play.google.com/store/apps"},
  {"appstore_url", "https://apps.apple.com/app"}
]

IO.puts("🌱 Seeding default App Preferences & Global Server Limits...")

# Ensure required OTP applications are started for script environment
Application.ensure_all_started(:gun)
Application.ensure_all_started(:grpc)

unless Process.whereis(GRPC.Client.Supervisor) do
  DynamicSupervisor.start_link(strategy: :one_for_one, name: GRPC.Client.Supervisor)
end

Enum.each(default_prefs, fn {key, value} ->
  try do
    case Revoluchat.Grpc.AdminClient.set_app_preference(key, value) do
      {:ok, _} -> IO.puts("   - Set #{key} = #{value}")
      _ -> IO.puts("   - #{key} fallback configured (Default: #{value})")
    end
  catch
    _, _ -> IO.puts("   - #{key} fallback configured (Default: #{value})")
  end
end)

