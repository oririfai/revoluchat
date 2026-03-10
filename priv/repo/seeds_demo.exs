alias Revoluchat.Repo

IO.puts("--- Seeding Demo Data ---")

# 1. Create users table (normally managed by external service)
Repo.query!("""
CREATE TABLE IF NOT EXISTS users (
  id integer PRIMARY KEY,
  uuid varchar(255),
  name varchar(255),
  phone varchar(255),
  status varchar(255),
  is_kyc boolean DEFAULT false,
  fcm varchar(255)
)
""")

IO.puts("Table 'users' verified.")

# 2. Seed Users
Repo.query!(
  "INSERT INTO users (id, uuid, name, status) VALUES (123, 'user-123-uuid', 'Demo User A', 'active') ON CONFLICT (id) DO NOTHING"
)

Repo.query!(
  "INSERT INTO users (id, uuid, name, status) VALUES (456, 'user-456-uuid', 'Demo User B', 'active') ON CONFLICT (id) DO NOTHING"
)

IO.puts("Users 123 and 456 seeded.")

# 3. Seed Conversation
app_id = "demo-app-id"
user_a_id = 123
user_b_id = 456

query =
  Ecto.Adapters.SQL.query!(
    Repo,
    "SELECT id FROM conversations WHERE app_id = $1 AND ((user_a_id = $2 AND user_b_id = $3) OR (user_a_id = $3 AND user_b_id = $2)) LIMIT 1",
    [app_id, user_a_id, user_b_id]
  )

case query.rows do
  [] ->
    id = "00000000-0000-0000-0000-000000000001"

    Repo.query!(
      "INSERT INTO conversations (id, app_id, user_a_id, user_b_id, inserted_at, updated_at, last_activity_at) VALUES ($1, $2, $3, $4, now(), now(), now())",
      [Ecto.UUID.dump!(id), app_id, user_a_id, user_b_id]
    )

    IO.puts("Conversation created with ID: #{id}")

  [[id_bin]] ->
    IO.puts("Conversation already exists: #{Ecto.UUID.cast!(id_bin)}")
end

# 4. Seed License (FIXED: Delete old ones first to avoid unique constraint issue)
IO.puts("Cleaning old licenses...")
Repo.delete_all(Revoluchat.Licensing.License)

jwt =
  "eyJhbGciOiJub25lIn0.eyJleHAiOjE5MjQ5MDgyMDAsInN0YXR1cyI6ImFjdGl2ZSIsImp0aSI6ImRlbW8tbGljZW5zZSJ9.signature"

case Revoluchat.Licensing.Core.apply_license(jwt) do
  {:ok, _} ->
    IO.puts("License applied successfully.")

  {:error, %Ecto.Changeset{} = cs} ->
    IO.puts("Failed to apply license (Changeset error): #{inspect(cs.errors)}")

  {:error, reason} ->
    IO.puts("Failed to apply license (Reason): #{inspect(reason)}")

  _ ->
    IO.puts("License status confirmed.")
end

IO.puts("--- Demo Seeding Complete ---")
