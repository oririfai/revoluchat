alias Revoluchat.Repo
alias Revoluchat.Accounts.ApiKey

IO.puts("--- Seeding Required API Key ---")

api_key = "8BRCMyA3R9b0nJ1K57abjrfxK4tlvGi8xdJHpnahAOc="
app_id = "revolu-app-1"

case Repo.get_by(ApiKey, key: api_key) do
  nil ->
    %ApiKey{}
    |> ApiKey.changeset(%{
      name: "RN App SDK",
      key: api_key,
      status: "active",
      app_id: app_id
    })
    |> Repo.insert!()
    IO.puts("✅ API Key seeded successfully.")

  _ ->
    IO.puts("✅ API Key already exists.")
end
