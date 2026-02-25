defmodule Revoluchat.Workers.FcmPushWorker do
  @moduledoc """
  Background worker untuk mengirim Push Notification via Firebase (FCM HTTP v1).
  Ini memastikan bahwa network latency FCM tidak memblokir process Phoenix Channel.
  """

  use Oban.Worker, max_attempts: 5
  require Logger
  alias Revoluchat.Notifications

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"app_id" => app_id, "user_id" => user_id, "message" => msg_map}}) do
    Logger.info("FcmPushWorker: Starting push dispatch for User #{user_id} in App #{app_id}")

    tokens = Notifications.get_push_tokens(app_id, user_id)

    if Enum.empty?(tokens) do
      Logger.debug("FcmPushWorker: User #{user_id} has no registered push tokens. Skipping.")
      :ok
    else
      dispatch_to_fcm(tokens, msg_map)
    end
  end

  defp dispatch_to_fcm(tokens, msg_map) do
    # Placeholder struct to mimic external HTTP Post via Req to https://fcm.googleapis.com
    # During development/MVP, we mock this as the user has not provided the Service Account JSON yet.
    _fcm_url = "https://fcm.googleapis.com/v1/projects/YOUR_PROJECT_ID/messages:send"

    Enum.each(tokens, fn push_token ->
      payload = build_fcm_payload(push_token.token, msg_map)

      Logger.info(
        "FcmPushWorker: Simulating FCM Push to token #{push_token.token} (Platform: #{push_token.platform})"
      )

      Logger.debug("Payload: #{inspect(payload)}")

      # Usually we do something like: Req.post(fcm_url, json: payload, auth: {:bearer, get_fcm_oauth_token()})
    end)

    :ok
  end

  defp build_fcm_payload(device_token, msg_map) do
    %{
      "message" => %{
        "token" => device_token,
        "notification" => %{
          "title" => "New Message",
          "body" => truncate(msg_map["body"], 50)
        },
        "data" => %{
          "conversation_id" => msg_map["conversation_id"],
          "message_id" => msg_map["id"],
          "type" => msg_map["type"],
          "action" => "open_chat"
        }
      }
    }
  end

  defp truncate(nil, _limit), do: "Attachment received"

  defp truncate(text, limit) do
    if String.length(text) > limit do
      String.slice(text, 0, limit) <> "..."
    else
      text
    end
  end
end
