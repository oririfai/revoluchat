# verify_integration.exs
# Jalankan dengan: mix run verify_integration.exs

IO.puts("\n=== REVOLUCHAT INTEGRATION VERIFIER ===\n")

# 0. Check API Key
api_key = "b2QCpdQ8Ii9OAwxEUalPEtfZRGMkVbcvmEZ1KP5BXyM="
app_id_param = "app_1bdCOMJSiDc="

IO.puts("0. Checking API Key in Database...")
case Revoluchat.Accounts.get_api_key_by_key(api_key) do
  nil ->
    IO.puts("   ❌ ERROR: API Key not found or NOT ACTIVE in Database.")
    # List all keys for debugging
    IO.puts("   Current Active Keys:")
    Revoluchat.Accounts.list_api_keys()
    |> Enum.each(fn k -> IO.puts("   - #{k.name}: #{k.key} (App: #{k.app_id})") end)
  
  key ->
    IO.puts("   ✅ SUCCESS: API Key found.")
    IO.puts("      Name: #{key.name}")
    IO.puts("      Status: #{key.status}")
    IO.puts("      Database App ID: #{key.app_id}")
    if key.app_id != app_id_param do
      IO.puts("   ⚠️ WARNING: App ID mismatch! Dashboard says #{key.app_id}, but App.tsx uses #{app_id_param}")
    end
end

# 1. Check gRPC
IO.puts("\n1. Checking gRPC connection to User Service...")
case Revoluchat.Grpc.UserClient.get_user("1") do
  {:ok, user} ->
    IO.puts("   ✅ SUCCESS: Received user data via gRPC")
    IO.inspect(user)
  {:error, :not_found} ->
    IO.puts("   ⚠️ WARNING: gRPC connected but user ID 1 not found in User Service (revolu-be)")
  {:error, reason} ->
    IO.puts("   ❌ ERROR: gRPC failed. Reason: #{inspect(reason)}")
    IO.puts("      Endpoint: #{System.get_env("USER_SERVICE_GRPC_ENDPOINT")}")
end

# 2. Check JWKS
IO.puts("\n2. Checking JWKS endpoint...")
jwks_url = System.get_env("JWKS_URL")
case Req.get(jwks_url) do
  {:ok, %{status: 200, body: body}} ->
    IO.puts("   ✅ SUCCESS: JWKS endpoint reachable")
    IO.inspect(body)
  {:error, reason} ->
    IO.puts("   ❌ ERROR: JWKS failed. Reason: #{inspect(reason)}")
    IO.puts("      URL: #{jwks_url}")
  other ->
    IO.puts("   ❌ ERROR: JWKS returned non-200. Got: #{inspect(other)}")
end

IO.puts("\n=== VERIFICATION COMPLETE ===\n")
