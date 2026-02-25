defmodule Revoluchat.Workers.LicenseCheckerWorker do
  @moduledoc """
  Background worker checking license status.
  In a real scenario, this runs daily and queries `https://license.revoluchat.com`.
  """

  use Oban.Worker, max_attempts: 3
  require Logger

  alias Revoluchat.Licensing.Core

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    case Core.get_active_license() do
      nil ->
        Logger.info("LicenseCheckerWorker: No active license in DB, doing nothing.")
        :ok

      license ->
        # Simulate an external HTTP check
        _url = "https://mock.license.revoluchat.com/api/v1/verify"
        _payload = %{license_key: license.license_key}

        # Normally we use Req here
        # case Req.post(url, json: payload) do
        #   {:ok, %{status: 200, body: %{"status" => "active"}}} -> :ok
        #   {:ok, %{status: 402}} -> Core.revoke_license()
        #   ...
        Logger.info(
          "LicenseCheckerWorker: Dialing home for #{license.license_key}... (Mock Check)"
        )

        # For MVP: Always assume it's still active unless forcefully revoked in DB
        :ok
    end
  end
end
