defmodule RevoluchatWeb.UserChannel do
  use Phoenix.Channel
  require Logger
  alias Revoluchat.{Calls, Accounts, Chat}

  def join("user:" <> user_id, _params, socket) do
    # Security check: User can only join their own topic
    authorized_user_id = to_string(socket.assigns.user_id)

    if user_id == authorized_user_id do
      Logger.info("UserChannel: User #{user_id} joined their private channel")

      send(self(), :after_join)

      {:ok, socket}
    else
      Logger.warning(
        "UserChannel: User #{authorized_user_id} attempted to join private channel of user #{user_id}"
      )

      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_info(:after_join, socket) do
    user_id = socket.assigns.user_id
    tier = to_string(Application.get_env(:revoluchat, :tier_type))

    allow_presence =
      if tier == "advance" do
        case Revoluchat.Grpc.UserClient.get_user(user_id) do
          {:ok, user} ->
            last_seen = Map.get(user.privacy_settings || %{}, "last_seen", "Everyone")
            last_seen != 3
          _ -> true
        end
      else
        true
      end

    if allow_presence do
      RevoluchatWeb.Presence.track(self(), "global:users", user_id, %{
        online_at: inspect(System.system_time(:second))
      })

      # Broadcast online status to all user's rooms
      try do
        conversations = Revoluchat.Chat.list_user_conversations(socket.assigns.app_id, user_id)
        Enum.each(conversations, fn c ->
          room_topic =
            if c.type == "group" or not is_nil(c.group) do
              "tenant:#{socket.assigns.app_id}:group:#{c.id}"
            else
              "tenant:#{socket.assigns.app_id}:room:#{c.id}"
            end

          RevoluchatWeb.Endpoint.broadcast(room_topic, "user_status_changed", %{
            "room_id" => c.id,
            "user_id" => user_id,
            "is_online" => true,
            "last_seen_at" => nil
          })
        end)
      rescue
        e -> Logger.error("Failed to broadcast online status: #{inspect(e)}")
      end
    else
      Logger.info("UserChannel: Presence bypassed for User #{user_id} due to privacy settings")
    end
    {:noreply, socket}
  end

  @impl true
  def handle_in("update_privacy", params, socket) do
    user_id = socket.assigns.user_id
    tier = to_string(Application.get_env(:revoluchat, :tier_type))

    last_seen_param = Map.get(params || %{}, "last_seen")

    allow_presence =
      cond do
        !is_nil(last_seen_param) ->
          last_seen_param != 3

        tier == "advance" ->
          case Revoluchat.Grpc.UserClient.get_user(user_id) do
            {:ok, user} ->
              last_seen = Map.get(user.privacy_settings || %{}, "last_seen", "Everyone")
              last_seen != 3

            _ ->
              true
          end

        true ->
          true
      end

    if allow_presence do
      RevoluchatWeb.Presence.track(self(), "global:users", user_id, %{
        online_at: inspect(System.system_time(:second))
      })

      try do
        conversations = Revoluchat.Chat.list_user_conversations(socket.assigns.app_id, user_id)

        Enum.each(conversations, fn c ->
          room_topic =
            if c.type == "group" or not is_nil(c.group) do
              "tenant:#{socket.assigns.app_id}:group:#{c.id}"
            else
              "tenant:#{socket.assigns.app_id}:room:#{c.id}"
            end

          RevoluchatWeb.Endpoint.broadcast(room_topic, "user_status_changed", %{
            "room_id" => c.id,
            "user_id" => user_id,
            "is_online" => true,
            "last_seen_at" => nil
          })
        end)
      rescue
        e -> Logger.error("Failed to broadcast online status: #{inspect(e)}")
      end
    else
      RevoluchatWeb.Presence.untrack(self(), "global:users", user_id)

      try do
        conversations = Revoluchat.Chat.list_user_conversations(socket.assigns.app_id, user_id)

        Enum.each(conversations, fn c ->
          room_topic =
            if c.type == "group" or not is_nil(c.group) do
              "tenant:#{socket.assigns.app_id}:group:#{c.id}"
            else
              "tenant:#{socket.assigns.app_id}:room:#{c.id}"
            end

          RevoluchatWeb.Endpoint.broadcast(room_topic, "user_status_changed", %{
            "room_id" => c.id,
            "user_id" => user_id,
            "is_online" => false,
            "last_seen_at" => nil
          })
        end)
      rescue
        e -> Logger.error("Failed to broadcast offline status: #{inspect(e)}")
      end
    end

    {:reply, :ok, socket}
  end

  @impl true
  def handle_in("mark_delivered", %{"message_id" => message_id} = params, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id

    case Revoluchat.Chat.mark_delivered(app_id, message_id, user_id) do
      {:ok, message} ->
        room_id = params["room_id"] || message.conversation_id
        room_topic =
          if String.starts_with?(to_string(room_id), "group_") do
            "tenant:#{app_id}:group:#{clean_id(room_id)}"
          else
            "tenant:#{app_id}:room:#{clean_id(room_id)}"
          end

        conv_id = room_id || message.conversation_id || message.group_id
        payload = %{
          "message_id" => message_id,
          "conversation_id" => conv_id,
          "room_id" => conv_id,
          "delivered_to" => user_id,
          "delivered_at" => format_dt(message.delivered_at),
          "status" => "delivered"
        }

        RevoluchatWeb.Endpoint.broadcast(room_topic, "message_delivered", payload)
        if message.sender_id do
          RevoluchatWeb.Endpoint.broadcast("user:#{message.sender_id}", "message_delivered", payload)
        end

        {:reply, :ok, socket}

      {:error, _} ->
        {:reply, {:error, %{reason: "not_found"}}, socket}
    end
  end

  # FAST PATH SIGNALING: Accept/Reject via User Channel (Bypassing Room Join)
  def handle_in("call:respond", %{"call_id" => call_id, "response" => action}, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id

    try do
      # 1. Authorization check
      if Calls.is_participant?(app_id, call_id, user_id) do
        case action do
          "accept" ->
            case Calls.accept_call(app_id, call_id) do
              {:ok, call} ->
                # Build identities and tokens
                caller = Accounts.get_registered_user(app_id, call.caller_id)
                current_user_id = socket.assigns.user_id
                receiver = Accounts.get_registered_user(app_id, current_user_id)

                caller_name =
                  if(caller && caller.name && caller.name != "",
                    do: caller.name,
                    else: (caller && caller.phone) || "User"
                  )

                receiver_name =
                  if(receiver && receiver.name && receiver.name != "",
                    do: receiver.name,
                    else: (receiver && receiver.phone) || "User"
                  )

                # Generate LiveKit Tokens dynamically
                livekit_url =
                  Application.get_env(:revoluchat, :livekit)[:url] ||
                    System.get_env("LIVEKIT_URL") || "ws://localhost:7880"

                {:ok, caller_token} =
                  Revoluchat.LiveKit.Token.generate(call_id, call.caller_id, caller_name)

                {:ok, current_token} =
                  Revoluchat.LiveKit.Token.generate(call_id, current_user_id, receiver_name)

                # Generate CoTURN credentials dynamically
                coturn_caller = Revoluchat.RTC.TurnCredentials.generate(call.caller_id)
                coturn_receiver = Revoluchat.RTC.TurnCredentials.generate(current_user_id)

                payload = %{
                  "call_id" => call_id,
                  "type" => call.type,
                  "status" => "connected",
                  "caller_id" => call.caller_id,
                  "caller_name" => caller_name,
                  "receiver_id" => current_user_id,
                  "receiver_name" => receiver_name,
                  "livekit_url" => livekit_url,
                  "livekit_token_caller" => caller_token,
                  "livekit_token_receiver" => current_token,
                  "is_group" => not is_nil(call.group_id),
                  "coturn_host" => coturn_caller.host,
                  "coturn_port" => coturn_caller.port,
                  "coturn_username_caller" => coturn_caller.username,
                  "coturn_credential_caller" => coturn_caller.credential,
                  "coturn_username_receiver" => coturn_receiver.username,
                  "coturn_credential_receiver" => coturn_receiver.credential
                }

                # BROADCAST to correct Room/Group topic
                target_topic =
                  cond do
                    call.group_id && call.group_id != "" ->
                      gid =
                        if String.starts_with?(call.group_id, "group_"),
                          do: call.group_id,
                          else: "group_#{call.group_id}"

                      "tenant:#{app_id}:group:#{gid}"

                    true ->
                      "tenant:#{app_id}:room:#{call.conversation_id}"
                  end

                RevoluchatWeb.Endpoint.broadcast!(target_topic, "call:accepted", payload)

                # Private topics (Global)
                RevoluchatWeb.Endpoint.broadcast!(
                  "user:#{call.caller_id}",
                  "call:accepted",
                  payload
                )

                # If 1-on-1, notify specific receiver channel
                if is_nil(call.group_id) && call.receiver_id != 0 do
                  RevoluchatWeb.Endpoint.broadcast!(
                    "user:#{call.receiver_id}",
                    "call:accepted",
                    payload
                  )
                end

                # Explicitly push to the current responder's socket to ensure they get it
                push(socket, "call:accepted", payload)

                {:reply, :ok, socket}

              {:error, reason} ->
                Logger.error("UserChannel: Failed to accept call #{call_id}: #{inspect(reason)}")
                {:reply, {:error, %{reason: "failed_to_accept"}}, socket}
            end

          "reject" ->
            case Calls.reject_call(app_id, call_id) do
              {:ok, call} ->
                payload = %{"call_id" => call_id, "status" => "rejected", "type" => call.type}
                # Broadcast to correct Room/Group topic
                target_topic =
                  cond do
                    call.group_id && call.group_id != "" ->
                      gid =
                        if String.starts_with?(call.group_id, "group_"),
                          do: call.group_id,
                          else: "group_#{call.group_id}"

                      "tenant:#{app_id}:group:#{gid}"

                    true ->
                      "tenant:#{app_id}:room:#{call.conversation_id}"
                  end

                RevoluchatWeb.Endpoint.broadcast!(target_topic, "call:rejected", payload)

                RevoluchatWeb.Endpoint.broadcast!(
                  "user:#{call.caller_id}",
                  "call:rejected",
                  payload
                )

                # Insert summary bubble
                insert_call_summary(call)

                {:reply, :ok, socket}

              _error ->
                {:reply, {:error, %{reason: "failed_to_reject"}}, socket}
            end
        end
      else
        {:reply, {:error, %{reason: "unauthorized"}}, socket}
      end
    rescue
      e ->
        Logger.error("UserChannel signaling error: #{inspect(e)}")
        {:reply, {:error, %{reason: "internal_error"}}, socket}
    end
  end

  def handle_in("call:hangup", %{"call_id" => call_id} = params, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id

    Logger.info(
      "UserChannel: Received call:hangup for call #{call_id} from user #{user_id} (App: #{app_id})"
    )

    try do
      is_pending = String.starts_with?(call_id, "pending-")

      if is_pending do
        conversation_id = Map.get(params, "conversation_id")

        Logger.info(
          "UserChannel: Handling pending call hangup for conversation #{conversation_id}"
        )

        if conversation_id do
          is_group = String.starts_with?(conversation_id, "group_")

          # Broadcast to room/group topic
          room_topic =
            if is_group,
              do: "tenant:#{app_id}:group:#{conversation_id}",
              else: "tenant:#{app_id}:room:#{conversation_id}"

          payload = %{
            "call_id" => call_id,
            "status" => "canceled",
            "conversation_id" => conversation_id
          }

          RevoluchatWeb.Endpoint.broadcast(room_topic, "call:hangup", payload)

          # Notify participants
          if is_group do
            case Chat.get_group(app_id, conversation_id) do
              {:ok, group} ->
                Enum.each(group.members, fn member ->
                  RevoluchatWeb.Endpoint.broadcast(
                    "user:#{member.user_id}",
                    "call:hangup",
                    payload
                  )
                end)

              _ ->
                :ok
            end
          else
            case Chat.get_conversation_for_user(app_id, conversation_id, user_id) do
              {:ok, conv} ->
                RevoluchatWeb.Endpoint.broadcast("user:#{conv.user_a_id}", "call:hangup", payload)
                RevoluchatWeb.Endpoint.broadcast("user:#{conv.user_b_id}", "call:hangup", payload)

              _ ->
                :ok
            end
          end
        end

        {:reply, :ok, socket}
      else
        if Calls.is_participant?(app_id, call_id, user_id) do
          case Calls.complete_call(app_id, call_id) do
            {:ok, call} ->
              payload = %{
                "call_id" => call_id,
                "status" => call.status,
                "type" => call.type,
                "conversation_id" => call.conversation_id
              }

              # Broadcast to correct Room/Group topic (Ensuring group_ prefix for groups)
              target_topic =
                cond do
                  call.group_id && call.group_id != "" ->
                    gid =
                      if String.starts_with?(call.group_id, "group_"),
                        do: call.group_id,
                        else: "group_#{call.group_id}"

                    "tenant:#{app_id}:group:#{gid}"

                  true ->
                    "tenant:#{app_id}:room:#{call.conversation_id}"
                end

              RevoluchatWeb.Endpoint.broadcast!(target_topic, "call:hangup", payload)

              # Global signaling for all participants
              Logger.info(
                "UserChannel: Broadcasting call:hangup for call #{call_id} to global topics. Caller: #{call.caller_id}, Receiver: #{call.receiver_id}"
              )

              is_group = call.group_id && call.group_id != ""

              if is_group do
                case Chat.get_group(app_id, call.group_id) do
                  {:ok, group} ->
                    Enum.each(group.members, fn member ->
                      topic = "user:#{member.user_id}"

                      Logger.info(
                        "UserChannel: Broadcasting hangup to group member topic: #{topic}"
                      )

                      RevoluchatWeb.Endpoint.broadcast(topic, "call:hangup", payload)
                    end)

                  _ ->
                    Logger.warning("UserChannel: Group #{call.group_id} not found for signaling")
                    :ok
                end
              else
                caller_topic = "user:#{call.caller_id}"
                receiver_topic = "user:#{call.receiver_id}"

                Logger.info(
                  "UserChannel: Broadcasting hangup to private topics: #{caller_topic} and #{receiver_topic}"
                )

                RevoluchatWeb.Endpoint.broadcast!(caller_topic, "call:hangup", payload)

                if call.receiver_id && call.receiver_id != 0 do
                  RevoluchatWeb.Endpoint.broadcast!(receiver_topic, "call:hangup", payload)
                end
              end

              # Insert summary bubble
              insert_call_summary(call, socket)
              {:reply, :ok, socket}

            {:error, reason} ->
              Logger.error(
                "UserChannel: complete_call failed for call #{call_id}: #{inspect(reason)}"
              )

              {:reply, {:error, %{reason: reason}}, socket}

            other ->
              Logger.error(
                "UserChannel: complete_call returned unexpected result: #{inspect(other)}"
              )

              {:reply, {:error, %{reason: "unexpected_error"}}, socket}
          end
        else
          Logger.warning("UserChannel: User #{user_id} is not a participant of call #{call_id}")
          {:reply, {:error, %{reason: "unauthorized"}}, socket}
        end
      end
    rescue
      e ->
        Logger.error("UserChannel: CRASH in call:hangup: #{inspect(e)}")
        Logger.error("Stacktrace: #{inspect(__STACKTRACE__)}")
        {:reply, {:error, %{reason: "internal_error"}}, socket}
    end
  end

  def handle_in("call:cancel", %{"call_id" => call_id} = params, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id

    Logger.info(
      "UserChannel: Received call:cancel for call #{call_id} from user #{user_id} (App: #{app_id})"
    )

    try do
      is_pending = String.starts_with?(call_id, "pending-")

      if is_pending do
        conversation_id = Map.get(params, "conversation_id")

        Logger.info(
          "UserChannel: Handling pending call cancel for conversation #{conversation_id}"
        )

        if conversation_id do
          is_group = String.starts_with?(conversation_id, "group_")

          # Broadcast to room/group topic
          room_topic =
            if is_group,
              do: "tenant:#{app_id}:group:#{conversation_id}",
              else: "tenant:#{app_id}:room:#{conversation_id}"

          payload = %{
            "call_id" => call_id,
            "status" => "canceled",
            "conversation_id" => conversation_id
          }

          RevoluchatWeb.Endpoint.broadcast(room_topic, "call:cancel", payload)

          # Notify participants
          if is_group do
            case Chat.get_group(app_id, conversation_id) do
              {:ok, group} ->
                Enum.each(group.members, fn member ->
                  RevoluchatWeb.Endpoint.broadcast(
                    "user:#{member.user_id}",
                    "call:cancel",
                    payload
                  )
                end)

              _ ->
                :ok
            end
          else
            case Chat.get_conversation_for_user(app_id, conversation_id, user_id) do
              {:ok, conv} ->
                RevoluchatWeb.Endpoint.broadcast("user:#{conv.user_a_id}", "call:cancel", payload)
                RevoluchatWeb.Endpoint.broadcast("user:#{conv.user_b_id}", "call:cancel", payload)

              _ ->
                :ok
            end
          end
        end

        {:reply, :ok, socket}
      else
        if Calls.is_participant?(app_id, call_id, user_id) do
          case Calls.cancel_call(app_id, call_id) do
            {:ok, call} ->
              payload = %{
                "call_id" => call_id,
                "status" => "canceled",
                "type" => call.type,
                "conversation_id" => call.conversation_id
              }

              # Broadcast to correct Room/Group topic (Ensuring group_ prefix for groups)
              target_topic =
                cond do
                  call.group_id && call.group_id != "" ->
                    gid =
                      if String.starts_with?(call.group_id, "group_"),
                        do: call.group_id,
                        else: "group_#{call.group_id}"

                    "tenant:#{app_id}:group:#{gid}"

                  true ->
                    "tenant:#{app_id}:room:#{call.conversation_id}"
                end

              RevoluchatWeb.Endpoint.broadcast!(target_topic, "call:cancel", payload)

              # Global signaling for all participants
              Logger.info(
                "UserChannel: Broadcasting call:cancel to global topics for call #{call_id}"
              )

              is_group = call.group_id && call.group_id != ""

              if is_group do
                case Chat.get_group(app_id, call.group_id) do
                  {:ok, group} ->
                    Enum.each(group.members, fn member ->
                      topic = "user:#{member.user_id}"

                      Logger.info(
                        "UserChannel: Broadcasting cancel to group member topic: #{topic}"
                      )

                      RevoluchatWeb.Endpoint.broadcast(topic, "call:cancel", payload)
                    end)

                  _ ->
                    :ok
                end
              else
                caller_topic = "user:#{call.caller_id}"
                receiver_topic = "user:#{call.receiver_id}"

                Logger.info(
                  "UserChannel: Broadcasting cancel to private topics: #{caller_topic} and #{receiver_topic}"
                )

                RevoluchatWeb.Endpoint.broadcast!(caller_topic, "call:cancel", payload)

                if call.receiver_id && call.receiver_id != 0 do
                  RevoluchatWeb.Endpoint.broadcast!(receiver_topic, "call:cancel", payload)
                end
              end

              # Insert summary bubble
              insert_call_summary(call, socket)
              {:reply, :ok, socket}

            {:error, reason} ->
              Logger.error(
                "UserChannel: cancel_call failed for call #{call_id}: #{inspect(reason)}"
              )

              {:reply, {:error, %{reason: reason}}, socket}
          end
        else
          Logger.warning(
            "UserChannel: User #{user_id} is not a participant of call #{call_id} (cancel)"
          )

          {:reply, {:error, %{reason: "unauthorized"}}, socket}
        end
      end
    rescue
      e ->
        Logger.error("UserChannel: CRASH in call:cancel: #{inspect(e)}")
        Logger.error("Stacktrace: #{inspect(__STACKTRACE__)}")
        {:reply, {:error, %{reason: "internal_error"}}, socket}
    end
  end

  def handle_in("call:request", %{"type" => call_type} = params, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id
    conversation_id = params["conversation_id"]
    group_id = params["group_id"]
    receiver_id = params["receiver_id"]

    Logger.info(
      "UserChannel: call:request from #{user_id}. Type: #{call_type}, Conv: #{conversation_id}, Group: #{group_id}, Receiver: #{receiver_id}"
    )

    # Security & Context Resolution
    case {conversation_id, group_id} do
      {conv_id, _} when is_binary(conv_id) and conv_id != "" ->
        # 1-on-1 Call
        case Chat.get_conversation_for_user(app_id, conv_id, user_id) do
          {:ok, conversation} ->
            # Automatically identify receiver if not provided by SDK
            receiver_id =
              receiver_id ||
                if to_string(conversation.user_a_id) == to_string(user_id),
                  do: conversation.user_b_id,
                  else: conversation.user_a_id

            initiate_and_broadcast_call(
              app_id,
              conv_id,
              nil,
              user_id,
              receiver_id,
              call_type,
              socket
            )

          _ ->
            {:reply, {:error, %{reason: "unauthorized"}}, socket}
        end

      {_, gid} when is_binary(gid) and gid != "" ->
        # Group Call
        case Chat.get_group(app_id, gid) do
          {:ok, _group} ->
            initiate_and_broadcast_call(app_id, nil, gid, user_id, nil, call_type, socket)

          _ ->
            {:reply, {:error, %{reason: "group_not_found"}}, socket}
        end

      _ ->
        {:reply, {:error, %{reason: "invalid_context"}}, socket}
    end
  end

  def handle_in("call:ringing", %{"call_id" => call_id}, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id

    try do
      if Calls.is_participant?(app_id, call_id, user_id) do
        case Calls.get_call(app_id, call_id) do
          {:ok, call} ->
            # Update state in DB
            Calls.set_ringing(app_id, call_id)

            # Notify the caller specifically
            RevoluchatWeb.Endpoint.broadcast!("user:#{call.caller_id}", "call:ringing", %{
              "call_id" => call_id,
              "type" => call.type
            })

            {:reply, :ok, socket}

          _error ->
            {:reply, {:error, %{reason: "not_found"}}, socket}
        end
      else
        {:reply, {:error, %{reason: "unauthorized"}}, socket}
      end
    rescue
      _ -> {:reply, {:error, %{reason: "internal_error"}}, socket}
    end
  end

  # --- Call Summary Helpers ---

  defp insert_call_summary(call) do
    payload = Calls.generate_summary_payload(call)

    case Chat.insert_message(payload) do
      {:ok, message, attachments} ->
        # Broadcast the new bubble to the chat room topic
        target_topic =
          if call.group_id && call.group_id != "",
            do: "tenant:#{call.app_id}:group:#{call.group_id}",
            else: "tenant:#{call.app_id}:room:#{call.conversation_id}"

        RevoluchatWeb.Endpoint.broadcast!(
          target_topic,
          "new_message",
          format_message(message, attachments)
        )

        # Broadcast conversation_updated to participants
        is_group = call.group_id && call.group_id != ""

        if is_group do
          case Chat.get_group(call.app_id, call.group_id) do
            {:ok, group} ->
              update_payload = %{
                conversation_id: call.group_id,
                type: "group"
              }
              Enum.each(group.members, fn member ->
                RevoluchatWeb.Endpoint.broadcast(
                  "user:#{member.user_id}",
                  "conversation_updated",
                  update_payload
                )
              end)

            _ ->
              :ok
          end
        else
          update_payload = %{
            conversation_id: call.conversation_id,
            type: "direct"
          }
          RevoluchatWeb.Endpoint.broadcast("user:#{call.caller_id}", "conversation_updated", update_payload)

          if call.receiver_id && call.receiver_id != 0,
            do:
              RevoluchatWeb.Endpoint.broadcast(
                "user:#{call.receiver_id}",
                "conversation_updated",
                update_payload
              )
        end

      _ ->
        Logger.error("UserChannel: Failed to insert call summary message for Call #{call.id}")
    end
  end

  defp format_message(message, attachments) do
    status = if not is_nil(message.read_at), do: "read", else: "sent"

    attachments_list = if is_list(attachments), do: attachments, else: []

    %{
      id: message.id,
      type: message.type,
      body: message.body,
      status: status,
      is_encrypted: message.is_encrypted,
      sender_id: message.sender_id,
      conversation_id: message.conversation_id,
      reply_to_id: message.reply_to_id,
      client_id: message.client_id,
      attachment: attachments_list |> List.first() |> format_attachment(),
      attachments: Enum.map(attachments_list, &format_attachment/1),
      delivered_at: format_dt(message.delivered_at),
      read_at: format_dt(message.read_at),
      deleted_at: format_dt(message.deleted_at),
      inserted_at: format_dt(message.inserted_at)
    }
  end

  defp format_attachment(nil), do: nil

  defp format_attachment(att) do
    %{
      id: att.id,
      url: "/api/a/v1/attachments/#{att.id}/show",
      mime_type: att.mime_type,
      size: att.size,
      metadata: att.metadata
    }
  end

  defp format_dt(nil), do: nil
  defp format_dt(dt), do: DateTime.to_iso8601(dt)

  def handle_in("call:upgrade_request", %{"call_id" => call_id, "type" => type}, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id

    Logger.info(
      "UserChannel: Received call:upgrade_request to #{type} for call #{call_id} from user #{user_id}"
    )

    if Calls.is_participant?(app_id, call_id, user_id) do
      case Calls.get_call(app_id, call_id) do
        nil ->
          Logger.error("UserChannel: upgrade_request failed - call #{call_id} not found")
          {:reply, {:error, %{reason: "not_found"}}, socket}

        call ->
          payload = %{"call_id" => call_id, "type" => type, "from_id" => user_id}
          # Broadcast to other party
          target_id =
            if to_string(call.caller_id) == to_string(user_id),
              do: call.receiver_id,
              else: call.caller_id

          if target_id && target_id != 0 do
            Logger.info("UserChannel: Broadcasting upgrade_request to user:#{target_id}")
            RevoluchatWeb.Endpoint.broadcast("user:#{target_id}", "call:upgrade_request", payload)
          end

          {:reply, :ok, socket}
      end
    else
      Logger.warning(
        "UserChannel: Unauthorized upgrade_request from user #{user_id} for call #{call_id}"
      )

      {:reply, {:error, %{reason: "unauthorized"}}, socket}
    end
  end

  def handle_in(
        "call:upgrade_response",
        %{"call_id" => call_id, "accepted" => accepted, "type" => type},
        socket
      ) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id

    Logger.info(
      "UserChannel: Received call:upgrade_response (accepted: #{accepted}) for call #{call_id} from user #{user_id}"
    )

    if Calls.is_participant?(app_id, call_id, user_id) do
      case Calls.get_call(app_id, call_id) do
        nil ->
          Logger.error("UserChannel: upgrade_response failed - call #{call_id} not found")
          {:reply, {:error, %{reason: "not_found"}}, socket}

        call ->
          payload = %{
            "call_id" => call_id,
            "accepted" => accepted,
            "type" => type,
            "responder_id" => user_id
          }

          # Broadcast to other party (the requester)
          target_id =
            if to_string(call.caller_id) == to_string(user_id),
              do: call.receiver_id,
              else: call.caller_id

          if target_id && target_id != 0 do
            Logger.info("UserChannel: Broadcasting upgrade_response to user:#{target_id}")

            RevoluchatWeb.Endpoint.broadcast(
              "user:#{target_id}",
              "call:upgrade_response",
              payload
            )
          end

          {:reply, :ok, socket}
      end
    else
      Logger.warning(
        "UserChannel: Unauthorized upgrade_response from user #{user_id} for call #{call_id}"
      )

      {:reply, {:error, %{reason: "unauthorized"}}, socket}
    end
  end

  @impl true
  def handle_in(event, payload, socket) do
    user_id = socket.assigns.user_id

    Logger.info(
      "UserChannel: Received unhandled event '#{event}' from user #{user_id}. Payload: #{inspect(payload)}"
    )

    {:noreply, socket}
  end

  defp insert_call_summary(call, socket) do
    payload = Calls.generate_summary_payload(call)
    app_id = socket.assigns.app_id

    case Chat.insert_message(payload) do
      {:ok, message, attachments} ->
        # Broadcast to all participants via their User Channels
        msg_payload = format_message(message, attachments, socket)

        # 1. Broadcast to Room
        target_topic =
          cond do
            call.group_id && call.group_id != "" ->
              gid =
                if String.starts_with?(call.group_id, "group_"),
                  do: call.group_id,
                  else: "group_#{call.group_id}"

              "tenant:#{app_id}:group:#{gid}"

            true ->
              "tenant:#{app_id}:room:#{call.conversation_id}"
          end

        RevoluchatWeb.Endpoint.broadcast(target_topic, "new_message", msg_payload)

        # 2. Broadcast to participants
        is_group = call.group_id && call.group_id != ""

        if is_group do
          case Chat.get_group(app_id, call.group_id) do
            {:ok, group} ->
              Enum.each(group.members, fn member ->
                RevoluchatWeb.Endpoint.broadcast(
                  "user:#{member.user_id}",
                  "new_message",
                  msg_payload
                )
              end)

            _ ->
              :ok
          end
        else
          RevoluchatWeb.Endpoint.broadcast("user:#{call.caller_id}", "new_message", msg_payload)

          if call.receiver_id && call.receiver_id != 0,
            do:
              RevoluchatWeb.Endpoint.broadcast(
                "user:#{call.receiver_id}",
                "new_message",
                msg_payload
              )
        end

        # 3. Broadcast conversation_updated to participants
        if is_group do
          case Chat.get_group(app_id, call.group_id) do
            {:ok, group} ->
              update_payload = %{
                conversation_id: call.group_id,
                type: "group"
              }
              Enum.each(group.members, fn member ->
                RevoluchatWeb.Endpoint.broadcast(
                  "user:#{member.user_id}",
                  "conversation_updated",
                  update_payload
                )
              end)

            _ ->
              :ok
          end
        else
          update_payload = %{
            conversation_id: call.conversation_id,
            type: "direct"
          }
          RevoluchatWeb.Endpoint.broadcast("user:#{call.caller_id}", "conversation_updated", update_payload)

          if call.receiver_id && call.receiver_id != 0,
            do:
              RevoluchatWeb.Endpoint.broadcast(
                "user:#{call.receiver_id}",
                "conversation_updated",
                update_payload
              )
        end

      _ ->
        Logger.error("UserChannel: Failed to insert call summary message for Call #{call.id}")
    end
  end

  # Helper to format message for broadcast (copied from ChatChannel logic)
  defp format_message(message, attachments, _socket) do
    %{
      id: message.id,
      conversation_id: message.conversation_id,
      group_id: message.group_id,
      sender_id: message.sender_id,
      type: message.type,
      body: message.body,
      is_encrypted: message.is_encrypted,
      client_id: message.client_id,
      inserted_at: format_dt(message.inserted_at),
      attachments: Enum.map(attachments, &normalize_attachment/1)
    }
  end

  defp normalize_attachment(att) do
    %{
      id: att.id,
      uploader_id: att.uploader_id,
      storage_key: att.storage_key,
      mime_type: att.mime_type,
      size: att.size,
      status: att.status,
      metadata: att.metadata
    }
  end

  defp initiate_and_broadcast_call(
         app_id,
         conversation_id,
         group_id,
         user_id,
         receiver_id,
         call_type,
         socket
       ) do
    case Calls.initiate_call(app_id, conversation_id, user_id, receiver_id, call_type, group_id) do
      {:ok, call, caller_identity} ->
        # Enrichment from local DB if remote identity is generic
        caller_identity =
          case Accounts.get_registered_user(app_id, user_id) do
            nil -> caller_identity
            u -> %{name: u.name || u.phone, photo: u.avatar_url, phone: u.phone}
          end

        payload = %{
          "call_id" => call.id,
          "type" => call_type,
          "caller_id" => user_id,
          "caller_name" => caller_identity.name,
          "caller_photo" => caller_identity.photo,
          "phone_number" => caller_identity.phone,
          "conversation_id" => conversation_id,
          "group_id" => group_id
        }

        # Enrich group info if present
        payload =
          if group_id do
            case Chat.get_group(app_id, group_id) do
              {:ok, g} ->
                Map.merge(payload, %{
                  "group_name" => g.name,
                  "group_photo" => g.avatar_url
                })

              _ ->
                payload
            end
          else
            payload
          end

        # 1. Broadcast to Room/Group Topic
        room_topic =
          cond do
            group_id -> "tenant:#{app_id}:group:#{group_id}"
            true -> "tenant:#{app_id}:room:#{conversation_id}"
          end

        RevoluchatWeb.Endpoint.broadcast(room_topic, "call:incoming", payload)

        # 2. Global signaling
        cond do
          !is_nil(receiver_id) ->
            # 1-on-1: Notify specific receiver
            RevoluchatWeb.Endpoint.broadcast("user:#{receiver_id}", "call:incoming", payload)
            # Push notification if receiver is offline
            handle_offline_call_push(app_id, conversation_id, receiver_id, payload)

          !is_nil(group_id) ->
            # Group Call (Advance Tier): Notify all members globally
            case Chat.get_group(app_id, group_id) do
              {:ok, group} ->
                Enum.each(group.members, fn member ->
                  if to_string(member.user_id) != to_string(user_id) do
                    RevoluchatWeb.Endpoint.broadcast(
                      "user:#{member.user_id}",
                      "call:incoming",
                      payload
                    )
                  end
                end)

              _ ->
                :ok
            end

          true ->
            :ok
        end

        {:reply, {:ok, %{call_id: call.id}}, socket}

      {:error, reason} ->
        Logger.error("UserChannel: initiate_call failed: #{inspect(reason)}")
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  defp handle_offline_call_push(_app_id, _conversation_id, _receiver_id, _payload) do
    # Placeholder for FCM/Push logic
    :ok
  end

  def terminate(_reason, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id

    Logger.info("UserChannel: User #{user_id} disconnected")

    try do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Update last_seen_at in user_chats (local Elixir table, not the external users table)
      import Ecto.Query
      Revoluchat.Repo.update_all(
        from(uc in Revoluchat.Accounts.UserChat,
          where: uc.user_id == ^to_string(user_id) and uc.app_id == ^app_id),
        set: [last_seen_at: now]
      )

      tier = to_string(Application.get_env(:revoluchat, :tier_type))
      allow_last_seen =
        if tier == "advance" do
          case Revoluchat.Grpc.UserClient.get_user(user_id) do
            {:ok, user} ->
              last_seen = Map.get(user.privacy_settings || %{}, "last_seen", "Everyone")
              last_seen != 3
            _ -> true
          end
        else
          true
        end

      last_seen_iso = if allow_last_seen, do: DateTime.to_iso8601(now), else: nil

      # Broadcast to rooms
      conversations = Revoluchat.Chat.list_user_conversations(app_id, user_id)
      Enum.each(conversations, fn c ->
        room_topic =
          if c.type == "group" or not is_nil(c.group) do
            "tenant:#{app_id}:group:#{c.id}"
          else
            "tenant:#{app_id}:room:#{c.id}"
          end

        RevoluchatWeb.Endpoint.broadcast(room_topic, "user_status_changed", %{
          "room_id" => c.id,
          "user_id" => user_id,
          "is_online" => false,
          "last_seen_at" => last_seen_iso
        })
      end)
    rescue
      e -> Logger.error("Failed to handle user disconnect: #{inspect(e)}")
    end

    :ok
  end

  defp clean_id(id) when is_binary(id) do
    id
    |> String.replace("group_", "")
    |> String.replace("room_", "")
  end
  defp clean_id(id), do: id

  defp format_dt(nil), do: nil
  defp format_dt(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
end
