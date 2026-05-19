
alias Revoluchat.Accounts
alias Revoluchat.Accounts.ServerKey
alias Revoluchat.Repo

key = "EZLR3TdkOxyJx1Y9OoqglkS-u-PaCD-BbVK6Ya5fAr09sDoTWrWAEgbc1YhFSq5x"
name = "Primary Go Backend"

# Check if key already exists
case Repo.get_by(ServerKey, key: key) do
  nil ->
    # Create new and set active
    case Accounts.create_server_key(name) do
      {:ok, sk} ->
        # Force update the key string just in case create_server_key generates its own (it shouldn't but safety first)
        sk |> ServerKey.changeset(%{key: key}) |> Repo.update!()
        Accounts.set_active_server_key(sk.id)
        IO.puts("Successfully created and activated new Server Key.")
      error ->
        IO.puts("Failed to create Server Key: #{inspect(error)}")
    end
  sk ->
    # Set existing as active
    Accounts.set_active_server_key(sk.id)
    IO.puts("Server Key already exists. Set as active.")
end
