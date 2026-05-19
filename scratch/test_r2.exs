# Test R2 get_object
alias Revoluchat.Storage.R2Adapter

key = "revoluchat/attachments/images/2026-05-11/15628dbb-6c63-4f77-ac3f-0262d892bd34.jpg"
bucket = Application.get_env(:revoluchat, :storage)[:bucket]

IO.puts "Testing get_object for key: #{key} in bucket: #{bucket}"

case R2Adapter.get_object(key) do
  {:ok, %{status_code: status}} ->
    IO.puts "Success! Status: #{status}"
  {:error, reason} ->
    IO.puts "Error! Reason: #{inspect(reason)}"
  other ->
    IO.puts "Other! #{inspect(other)}"
end
