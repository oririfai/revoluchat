defmodule Revoluchat.Notifications.FcmAuth do
  use GenServer
  require Logger

  @table_name :fcm_auth_cache

  # API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Mendapatkan access token yang valid secara instan dari ETS cache (O(1)).
  Jika token belum ada atau expired, GenServer akan melakukan refresh secara sinkron & aman dari duplicate requests.
  """
  def get_access_token do
    case :ets.lookup(@table_name, :access_token) do
      [{:access_token, token, expiry}] ->
        now = DateTime.utc_now() |> DateTime.to_unix()
        # Jika token masih berlaku (dengan buffer keamanan 5 menit)
        if now < expiry - 300 do
          {:ok, token}
        else
          GenServer.call(__MODULE__, :refresh_token)
        end

      [] ->
        GenServer.call(__MODULE__, :refresh_token)
    end
  end

  @doc """
  Mendapatkan Project ID dari Service Account JSON.
  """
  def get_project_id do
    case :ets.lookup(@table_name, :project_id) do
      [{:project_id, project_id}] -> project_id
      [] -> System.get_env("FCM_PROJECT_ID") || "mock_project_id"
    end
  end

  # Callbacks
  @impl true
  def init(_opts) do
    :ets.new(@table_name, [:set, :protected, :named_table, read_concurrency: true])
    
    case load_credentials() do
      {:ok, creds} ->
        :ets.insert(@table_name, {:project_id, creds["project_id"]})
        {:ok, creds}

      {:error, reason} ->
        Logger.warning("FcmAuth: Failed to load Google Service Account credentials: #{reason}. FCM will run in MOCK mode.")
        {:ok, :mock}
    end
  end

  @impl true
  def handle_call(:refresh_token, _from, state) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    # Double-check jika proses lain sudah merefresh token saat request ini mengantre di mailbox GenServer
    case :ets.lookup(@table_name, :access_token) do
      [{:access_token, token, expiry}] when now < expiry - 300 ->
        {:reply, {:ok, token}, state}

      _ ->
        case refresh_access_token(state) do
          {:ok, token, expires_in, project_id} ->
            expiry = now + expires_in
            :ets.insert(@table_name, {:access_token, token, expiry})
            if project_id, do: :ets.insert(@table_name, {:project_id, project_id})
            {:reply, {:ok, token}, state}

          {:error, reason} ->
            Logger.error("FcmAuth: Failed to refresh FCM access token: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
    end
  end

  # Helpers
  defp load_credentials do
    cond do
      json_str = System.get_env("FCM_CREDENTIALS") ->
        Jason.decode(json_str)

      file_path = System.get_env("FCM_CREDENTIALS_FILE") ->
        if File.exists?(file_path) do
          file_path |> File.read!() |> Jason.decode()
        else
          {:error, "File does not exist: #{file_path}"}
        end

      true ->
        {:error, "No FCM_CREDENTIALS or FCM_CREDENTIALS_FILE in environment"}
    end
  end

  defp refresh_access_token(:mock) do
    {:ok, "mock_access_token", 3600, "mock_project_id"}
  end

  defp refresh_access_token(creds) do
    client_email = creds["client_email"]
    private_key = creds["private_key"]
    project_id = creds["project_id"]

    if is_nil(client_email) or is_nil(private_key) or is_nil(project_id) do
      {:error, "Missing required fields in service account JSON"}
    else
      try do
        signer = Joken.Signer.create("RS256", %{"pem" => private_key})
        now = DateTime.utc_now() |> DateTime.to_unix()
        
        claims = %{
          "iss" => client_email,
          "scope" => "https://www.googleapis.com/auth/firebase.messaging",
          "aud" => "https://oauth2.googleapis.com/token",
          "iat" => now,
          "exp" => now + 3600
        }

        with {:ok, jwt, _claims} <- Joken.generate_and_sign(%{}, claims, signer),
             {:ok, %{status: 200, body: body}} <- Req.post("https://oauth2.googleapis.com/token",
               form: [
                 grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
                 assertion: jwt
               ]
             ) do
          access_token = body["access_token"]
          expires_in = body["expires_in"] || 3600
          {:ok, access_token, expires_in, project_id}
        else
          {:error, reason} -> {:error, reason}
          {:ok, response} -> {:error, "Unexpected response from token endpoint: #{inspect(response)}"}
          other -> {:error, "Joken/Req failed: #{inspect(other)}"}
        end
      rescue
        e -> {:error, "Signing error: #{inspect(e)}"}
      end
    end
  end
end
