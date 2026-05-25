defmodule Revoluchat.Workers.FcmPushWorker do
  @moduledoc """
  Background worker untuk mengirim Push Notification via Firebase (FCM HTTP v1).
  Ini memastikan bahwa network latency FCM tidak memblokir process Phoenix Channel.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [
      period: 5,
      keys: [:user_id, :conversation_id],
      states: [:available, :scheduled]
    ]

  require Logger
  alias Revoluchat.Notifications

  @impl Oban.Worker
  def perform(%Oban.Job{args: args = %{"app_id" => app_id, "user_id" => user_id}}) do
    Logger.info("FcmPushWorker: Starting push dispatch for User #{user_id} in App #{app_id}")

    tokens = Notifications.get_push_tokens(app_id, user_id)

    if Enum.empty?(tokens) do
      Logger.debug("FcmPushWorker: User #{user_id} has no registered push tokens. Skipping.")
      :ok
    else
      dispatch_to_fcm(tokens, args)
    end
  end

  defp dispatch_to_fcm(tokens, args) do
    {:ok, access_token} = Revoluchat.Notifications.FcmAuth.get_access_token()
    project_id = Revoluchat.Notifications.FcmAuth.get_project_id()

    Enum.each(tokens, fn push_token ->
      payload =
        cond do
          Map.has_key?(args, "message") ->
            build_message_payload(
              push_token.token,
              args["message"],
              args["conversation_id"],
              push_token.platform,
              args["app_id"],
              args
            )

          Map.has_key?(args, "call") ->
            build_call_payload(push_token.token, args["call"])

          true ->
            nil
        end

      if payload do
        if access_token == "mock_access_token" do
          Logger.info("FcmPushWorker: [MOCK MODE] Simulating FCM Push")
          Logger.debug("Payload: #{inspect(payload)}")
        else
          fcm_url = "https://fcm.googleapis.com/v1/projects/#{project_id}/messages:send"
          
          # Kirim request menggunakan Finch pool (HTTP/2 multiplexing)
          case Req.post(fcm_url, json: payload, auth: {:bearer, access_token}) do
            {:ok, %{status: 200}} ->
              Logger.info("FcmPushWorker: Push successfully sent")

            {:ok, %{status: status}} when status in [404, 410] ->
              Logger.warning("FcmPushWorker: Unregistered FCM token detected (status: #{status}). Deleting token from database.")
              Notifications.delete_push_token_by_token(push_token.token)

            {:ok, %{status: status, body: body}} ->
              Logger.error("FcmPushWorker: FCM returned error status #{status}: #{inspect(body)}")

            {:error, reason} ->
              Logger.error("FcmPushWorker: Failed to send push via HTTP/2: #{inspect(reason)}")
              raise "FCM network error: #{inspect(reason)}"
          end
        end
      end
    end)

    :ok
  end

  def build_message_payload(device_token, msg_map, conversation_id \\ nil, platform \\ nil, app_id \\ nil, extra_args \\ %{}) do
    conv_id = conversation_id || Map.get(msg_map, "conversation_id") || Map.get(msg_map, :conversation_id) || ""
    
    # Handle both string and atom keys for msg_map to extract user info robustly
    user_map = Map.get(msg_map, "user") || Map.get(msg_map, :user)
    
    sender_name =
      if user_map do
        Map.get(user_map, "name") || Map.get(user_map, :name) || "Unknown"
      else
        Map.get(msg_map, "sender_name") || Map.get(msg_map, :sender_name) || "Unknown"
      end

    # Handle both string and atom keys for robustness in extra args
    extra_conversation_name = Map.get(extra_args, "conversation_name") || Map.get(extra_args, :conversation_name)
    extra_sender_avatar_url = Map.get(extra_args, "sender_avatar_url") || Map.get(extra_args, :sender_avatar_url)

    # Only query DB/gRPC if we don't already have both name and avatar passed in extra_args
    has_extra_group_info =
      extra_conversation_name not in [nil, ""] and
        extra_sender_avatar_url not in [nil, ""]

    group_data =
      if String.starts_with?(conv_id, "group_") and not is_nil(app_id) and app_id != "" and not has_extra_group_info do
        group_id = String.replace_prefix(conv_id, "group_", "")
        case Revoluchat.Chat.get_group(app_id, group_id) do
          {:ok, group} ->
            RevoluchatWeb.GroupController.format_group(group, app_id, "")
          _ ->
            nil
        end
      else
        nil
      end

    group_name =
      cond do
        extra_conversation_name not in [nil, ""] ->
          extra_conversation_name

        group_data ->
          group_data[:name] || ""

        true ->
          ""
      end

    # 1. Resolve individual sender's avatar (handling string and atom user map keys)
    raw_sender_avatar =
      if user_map do
        Map.get(user_map, "avatar_url") || Map.get(user_map, :avatar_url) || ""
      else
        ""
      end
    sender_avatar_url = resolve_avatar(raw_sender_avatar)

    # 2. Resolve conversation avatar (group avatar if group, else sender avatar)
    conversation_avatar_url =
      cond do
        extra_sender_avatar_url not in [nil, ""] ->
          extra_sender_avatar_url

        group_data ->
          group_data[:avatar_url] || ""

        String.starts_with?(conv_id, "group_") ->
          ""

        true ->
          sender_avatar_url
      end

    inserted_dt =
      case Map.get(msg_map, "inserted_at") || Map.get(msg_map, :inserted_at) do
        nil -> DateTime.utc_now()
        str ->
          case DateTime.from_iso8601(str) do
            {:ok, dt, _offset} -> dt
            _ -> DateTime.utc_now()
          end
      end

    wib_dt = DateTime.add(inserted_dt, 7 * 3600, :second)
    hour = wib_dt.hour |> to_string() |> String.pad_leading(2, "0")
    minute = wib_dt.minute |> to_string() |> String.pad_leading(2, "0")
    time_str = "#{hour}:#{minute} WIB"

    title = "#{sender_name} • #{time_str}"

    body =
      cond do
        Map.get(msg_map, "is_encrypted") == true or Map.get(msg_map, "is_encrypted") == "true" or
        Map.get(msg_map, :is_encrypted) == true or Map.get(msg_map, :is_encrypted) == "true" ->
          "Mengirimkan pesan terenkripsi"

        true ->
          truncate(Map.get(msg_map, "body") || Map.get(msg_map, :body), 100)
      end

    is_android_data_only = platform in ["fcm", "android"]

    if is_android_data_only do
      %{
        "message" => %{
          "token" => device_token,
          "data" => %{
            "conversation_id" => conv_id,
            "message_id" => to_string(Map.get(msg_map, "id") || Map.get(msg_map, :id)),
            "type" => to_string(Map.get(msg_map, "type") || Map.get(msg_map, :type)),
            "action" => "open_chat",
            "sender_avatar_url" => sender_avatar_url,
            "conversation_avatar_url" => conversation_avatar_url,
            "sender_name" => sender_name,
            "conversation_name" => group_name,
            "title" => title,
            "body" => body
          }
        }
      }
    else
      %{
        "message" => %{
          "token" => device_token,
          "notification" => %{
            "title" => title,
            "body" => body
          },
          "data" => %{
            "conversation_id" => conv_id,
            "message_id" => to_string(Map.get(msg_map, "id") || Map.get(msg_map, :id)),
            "type" => to_string(Map.get(msg_map, "type") || Map.get(msg_map, :type)),
            "action" => "open_chat",
            "sender_avatar_url" => sender_avatar_url,
            "conversation_avatar_url" => conversation_avatar_url,
            "sender_name" => sender_name,
            "conversation_name" => group_name
          }
        }
      }
    end
  end

  defp resolve_avatar(nil), do: ""
  defp resolve_avatar(""), do: ""
  defp resolve_avatar(url) do
    if String.match?(url, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i) do
      "/api/a/v1/attachments/#{url}/show"
    else
      url
    end
  end

  def build_call_payload(device_token, call_map) do
    %{
      "message" => %{
        "token" => device_token,
        "android" => %{
          "priority" => "high"
        },
        "apns" => %{
          "payload" => %{
            "aps" => %{
              "content-available" => 1
            }
          }
        },
        "notification" => %{
          "title" => "Incoming #{String.capitalize(call_map["type"])} Call",
          "body" => "#{call_map["caller_name"]} is calling you..."
        },
        "data" => %{
          "call_id" => call_map["call_id"],
          "caller_id" => to_string(call_map["caller_id"]),
          "caller_name" => call_map["caller_name"],
          "caller_photo" => call_map["caller_photo"] || "",
          "phone_number" => call_map["phone_number"],
          "type" => call_map["type"],
          "action" => "incoming_call"
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
