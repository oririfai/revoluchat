defmodule Revoluchat.Workers.UserProfileSyncWorker do
  use Oban.Worker, queue: :default

  require Logger
  alias Revoluchat.Accounts

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"app_id" => app_id, "user_id" => user_id}}) do
    Logger.info("UserProfileSyncWorker: Syncing profile for User #{user_id} in App #{app_id}")

    case Accounts.get_user(user_id) do
      {:ok, user} ->
        # reuse existing ensure_user_chat_registered logic which performs update
        Accounts.ensure_user_chat_registered(user_id, app_id, user)
        :ok

      {:error, :user_not_found} ->
        Logger.warning("UserProfileSyncWorker: User #{user_id} not found in User Service.")
        :ok

      {:error, reason} ->
        Logger.error("UserProfileSyncWorker: Failed to sync User #{user_id}. Reason: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
