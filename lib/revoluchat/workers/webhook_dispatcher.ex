defmodule Revoluchat.Workers.WebhookDispatcher do
  @moduledoc """
  Worker Oban untuk mengirim event (e.g., new_message) via HTTP
  ke endpoint backend utama milik tenant (Client).
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 5

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event" => event, "payload" => payload}}) do
    webhook_url = Application.get_env(:revoluchat, :webhook_url) || System.get_env("WEBHOOK_URL")

    if is_nil(webhook_url) or webhook_url == "" do
      Logger.debug("Skipping webhook dispatch: WEBHOOK_URL is not configured.")
      :ok
    else
      dispatch_webhook(webhook_url, event, payload)
    end
  end

  defp dispatch_webhook(url, event, payload) do
    # Buat request body
    body =
      Jason.encode!(%{
        "event" => event,
        "payload" => payload,
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      })

    # Tambah HMAC signature (opsional, direkomendasikan untuk Enterprise secure webhook)
    secret =
      Application.get_env(:revoluchat, :webhook_secret) ||
        System.get_env("WEBHOOK_SECRET", "dummy_secret_for_dev")

    signature = :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower)

    headers = [
      {"Content-Type", "application/json"},
      {"X-Revoluchat-Signature", "sha256=#{signature}"}
    ]

    # POST menggunakan req default library dari Phoenix
    case Req.post(url, body: body, headers: headers, receive_timeout: 5_000) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        Logger.info("Webhook delivered successfully: #{event}")
        :ok

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("Webhook failed with status #{status}: #{event}")
        {:error, "Webhook failed with HTTP #{status}"}

      {:error, exception} ->
        Logger.error("Webhook network error: #{inspect(exception)}")
        {:error, exception}
    end
  end
end
