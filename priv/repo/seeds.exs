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
      where: (c.user_a_id == 1 and c.user_b_id == 2) or (c.user_a_id == 2 and c.user_b_id == 1),
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
      user_a_id: 1,
      user_b_id: 2,
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
