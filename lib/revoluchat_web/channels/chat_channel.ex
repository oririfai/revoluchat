defmodule RevoluchatWeb.ChatChannel do
  use Phoenix.Channel

  alias Revoluchat.{Chat, Calls, Accounts}
  alias RevoluchatWeb.{Presence, Plugs.RateLimiter}

  require Logger

  # ─── JOIN ───────────────────────────────────────────────────────────────────

  @impl true
  def join(topic, _params, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id

    Logger.info("ChatChannel: join topic=#{topic} user_id=#{user_id}")

    try do
      case String.split(topic, ":") do
        ["tenant", topic_app_id, "room", conversation_id] ->
          if topic_app_id != app_id do
            Logger.error(
              "ChatChannel JOIN FAILED: Tenant mismatch. Socket app_id=#{app_id}, Topic app_id=#{topic_app_id}"
            )

            {:error, %{reason: "tenant_mismatch"}}
          else
            join_conversation(topic_app_id, conversation_id, app_id, user_id, socket)
          end

        ["tenant", topic_app_id, "group", group_id] ->
          if topic_app_id != app_id do
            Logger.error(
              "ChatChannel JOIN FAILED: Tenant mismatch. Socket app_id=#{app_id}, Topic app_id=#{topic_app_id}"
            )

            {:error, %{reason: "tenant_mismatch"}}
          else
            join_group(topic_app_id, group_id, app_id, user_id, socket)
          end

        _ ->
          Logger.warning("ChatChannel: Invalid topic format: #{topic}")
          {:error, %{reason: "invalid_topic_format"}}
      end
    rescue
      e ->
        Logger.error(
          "ChatChannel: CRASH during join/3 for User #{user_id} on topic #{topic}. Error: #{inspect(e)}"
        )

        {:error, %{reason: "internal_server_error"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    user_id = socket.assigns.user_id

    tier = to_string(Application.get_env(:revoluchat, :tier_type))

    allow_presence =
      if tier == "advance" do
        case Revoluchat.Grpc.UserClient.get_user(user_id) do
          {:ok, user} ->
            last_seen = Map.get(user.privacy_settings || %{}, "last_seen", "Everyone")
            last_seen not in ["Tidak ada", "Nobody", "nobody"]
          _ -> true
        end
      else
        true
      end

    if allow_presence do
      case Presence.track(socket, user_id, %{
             online_at: DateTime.utc_now() |> DateTime.to_iso8601(),
             typing: false
           }) do
        {:ok, _} ->
          Logger.info("ChatChannel: Presence tracked for User #{user_id}")
          push(socket, "presence_state", Presence.list(socket))

        {:error, reason} ->
          Logger.error(
            "ChatChannel: Failed to track presence for User #{user_id}: #{inspect(reason)}"
          )
      end
    else
      Logger.info("ChatChannel: Presence bypassed for User #{user_id} due to privacy settings")
      # Still push the list of OTHERS to this user, even if they are invisible themselves
      push(socket, "presence_state", Presence.list(socket))
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(msg, socket) do
    Logger.debug("ChatChannel: Received unhandled info message: #{inspect(msg)}")
    {:noreply, socket}
  end

  # ─── INBOUND EVENTS ──────────────────────────────────────────────────────────

  @impl true
  def handle_in("new_message", payload, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id
    conversation_id = socket.assigns[:conversation_id]
    group_id = socket.assigns[:group_id]

    # Re-validate membership or presence
    case {conversation_id, group_id} do
      {conv_id, nil} when not is_nil(conv_id) ->
        case Chat.get_conversation_for_user(app_id, conv_id, user_id) do
          {:ok, _} ->
            check_rate_and_process(payload, conv_id, nil, user_id, socket)

          {:error, :not_found} ->
            {:reply, {:error, %{reason: "unauthorized"}}, socket}
        end

      {nil, grp_id} when not is_nil(grp_id) ->
        # For groups, we delegate validation to the backend
        check_rate_and_process(payload, nil, grp_id, user_id, socket)

      _ ->
        {:reply, {:error, %{reason: "unauthorized"}}, socket}
    end
  end

  @impl true
  def handle_in("typing_start", _payload, socket) do
    if_authorized(socket, fn ->
      user_id = socket.assigns.user_id

      try do
        Presence.update(socket, user_id, fn meta ->
          Map.put(meta, :typing, true)
        end)
      rescue
        _ -> :ok
      end

      broadcast_from!(socket, "user_typing", %{
        user_id: user_id,
        typing: true
      })

      {:noreply, socket}
    end)
  end

  @impl true
  def handle_in("typing_stop", _payload, socket) do
    if_authorized(socket, fn ->
      user_id = socket.assigns.user_id

      try do
        Presence.update(socket, user_id, fn meta ->
          Map.put(meta, :typing, false)
        end)
      rescue
        _ -> :ok
      end

      broadcast_from!(socket, "user_typing", %{
        user_id: user_id,
        typing: false
      })

      {:noreply, socket}
    end)
  end

  @impl true
  def handle_in("mark_read", %{"message_id" => message_id}, socket) do
    if_authorized(socket, fn ->
      user_id = socket.assigns.user_id
      app_id = socket.assigns.app_id

      case Chat.mark_read(app_id, message_id, user_id) do
        {:ok, message} ->
          reader_user = Revoluchat.Accounts.get_registered_user(app_id, user_id)
          sender_user = Revoluchat.Accounts.get_registered_user(app_id, message.sender_id)

          reader_privacy = (reader_user && (Map.get(reader_user, :privacy_settings) || Map.get(reader_user, "privacy_settings"))) || %{}
          sender_privacy = (sender_user && (Map.get(sender_user, :privacy_settings) || Map.get(sender_user, "privacy_settings"))) || %{}

          reader_off = (Map.get(reader_privacy, "read_receipts") || Map.get(reader_privacy, :read_receipts)) in [false, "false", "Tidak", "tidak", "off", "nobody", "Nobody"]
          sender_off = (Map.get(sender_privacy, "read_receipts") || Map.get(sender_privacy, :read_receipts)) in [false, "false", "Tidak", "tidak", "off", "nobody", "Nobody"]

          if not is_nil(message.read_at) and not (reader_off or sender_off) do
            broadcast!(socket, "message_read", %{
              message_id: message_id,
              read_by: user_id,
              read_at: format_dt(message.read_at),
              status: get_status(message)
            })
          else
            if not is_nil(message.delivered_at) do
              broadcast!(socket, "message_delivered", %{
                message_id: message_id,
                delivered_to: user_id,
                delivered_at: format_dt(message.delivered_at),
                status: "delivered"
              })
            end
          end

          # Broadcast conversation_updated to participant user channels so their main chat lists refresh
          conversation_id = socket.assigns[:conversation_id]
          group_id = socket.assigns[:group_id]

          if conversation_id do
            case Chat.get_conversation_for_user(app_id, clean_id(conversation_id), user_id) do
              {:ok, conversation} ->
                update_payload = %{
                  conversation_id: conversation_id,
                  type: "direct"
                }

                RevoluchatWeb.Endpoint.broadcast(
                  "user:#{conversation.user_a_id}",
                  "conversation_updated",
                  update_payload
                )

                RevoluchatWeb.Endpoint.broadcast(
                  "user:#{conversation.user_b_id}",
                  "conversation_updated",
                  update_payload
                )

              _ ->
                nil
            end
          else
            if group_id do
              case Chat.get_group(app_id, clean_id(group_id)) do
                {:ok, group} ->
                  update_payload = %{
                    conversation_id: group_id,
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
                  nil
              end
            end
          end

          {:reply, :ok, socket}

        {:error, reason} ->
          {:reply, {:error, %{reason: "not_found"}}, socket}
      end
    end)
  end

  @impl true
  def handle_in("mark_delivered", %{"message_id" => message_id}, socket) do
    if_authorized(socket, fn ->
      user_id = socket.assigns.user_id
      app_id = socket.assigns.app_id

      case Chat.mark_delivered(app_id, message_id, user_id) do
        {:ok, message} ->
          conv_or_group_id = message.conversation_id || message.group_id || socket.assigns[:conversation_id] || socket.assigns[:group_id]
          payload = %{
            message_id: message_id,
            conversation_id: conv_or_group_id,
            room_id: conv_or_group_id,
            delivered_to: user_id,
            delivered_at: format_dt(message.delivered_at),
            status: get_status(message)
          }

          broadcast!(socket, "message_delivered", payload)

          if message.sender_id do
            RevoluchatWeb.Endpoint.broadcast("user:#{message.sender_id}", "message_delivered", payload)
          end

          {:reply, :ok, socket}

        {:error, _} ->
          {:reply, {:error, %{reason: "not_found"}}, socket}
      end
    end)
  end

  @impl true
  def handle_in("delete_message", %{"message_id" => message_id}, socket) do
    if_authorized(socket, fn ->
      user_id = socket.assigns.user_id
      app_id = socket.assigns.app_id

      Logger.info("ChatChannel: User #{user_id} requesting delete for message #{message_id}")

      case Chat.soft_delete_message(app_id, message_id, user_id) do
        {:ok, message} ->
          Logger.info("ChatChannel: Message #{message_id} soft deleted successfully")

          broadcast!(socket, "message_deleted", %{
            message_id: message_id,
            deleted_at: DateTime.to_iso8601(message.deleted_at)
          })

          {:reply, :ok, socket}

        {:error, :unauthorized} ->
          Logger.warning(
            "ChatChannel: Unauthorized delete attempt by User #{user_id} for message #{message_id}"
          )

          {:reply, {:error, %{reason: "unauthorized"}}, socket}

        {:error, reason} ->
          Logger.error(
            "ChatChannel: Failed to delete message #{message_id}. Reason: #{inspect(reason)}"
          )

          {:reply, {:error, %{reason: "not_found"}}, socket}
      end
    end)
  end

  @impl true
  def handle_in("delete_messages", %{"message_ids" => message_ids}, socket) do
    if_authorized(socket, fn ->
      user_id = socket.assigns.user_id
      app_id = socket.assigns.app_id

      Logger.info(
        "ChatChannel: User #{user_id} requesting bulk delete for #{length(message_ids)} messages"
      )

      case Chat.soft_delete_messages(app_id, message_ids, user_id) do
        {:ok, count} ->
          Logger.info("ChatChannel: #{count} messages soft deleted successfully")

          # Broadcast the deletion to all participants
          broadcast!(socket, "messages_deleted", %{
            message_ids: message_ids,
            deleted_at: DateTime.utc_now() |> DateTime.to_iso8601()
          })

          {:reply, :ok, socket}

        {:error, reason} ->
          Logger.error("ChatChannel: Bulk delete failed: #{inspect(reason)}")
          {:reply, {:error, %{reason: "delete_failed"}}, socket}
      end
    end)
  end

  @impl true
  def handle_in("search_messages", %{"query" => query} = params, socket) do
    if_authorized(socket, fn ->
      app_id = socket.assigns.app_id
      conversation_id = socket.assigns[:conversation_id]
      group_id = socket.assigns[:group_id]
      limit = params["limit"] || 20

      opts = [
        group_id: group_id,
        search: query,
        limit: limit
      ]

      messages = Chat.list_messages(app_id, conversation_id, socket.assigns.user_id, opts)

      # Enrichment logic similar to finish_join
      sender_ids = Enum.map(messages, & &1.sender_id) |> Enum.uniq()
      users_data = Revoluchat.Accounts.list_registered_users_by_ids(app_id, sender_ids)
      users_map = Revoluchat.Accounts.build_users_map(users_data)

      all_attachment_ids =
        messages
        |> Enum.flat_map(&(&1.attachment_ids || []))
        |> Enum.concat(Enum.map(messages, & &1.attachment_id))
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      attachments_map =
        if all_attachment_ids != [] do
          Chat.list_attachments_by_ids(app_id, all_attachment_ids)
          |> Map.new(fn a -> {a.id, a} end)
        else
          %{}
        end

      formatted_messages =
        Enum.map(messages, fn m ->
          m_atts =
            (m.attachment_ids || [])
            |> Enum.map(&Map.get(attachments_map, &1))
            |> Enum.concat([Map.get(attachments_map, m.attachment_id)])
            |> Enum.reject(&is_nil/1)
            |> Enum.uniq_by(& &1.id)

          format_message_with_user(m, users_map, m_atts, socket)
        end)

      {:reply, {:ok, %{messages: formatted_messages}}, socket}
    end)
  end

  # ─── CALL SIGNALING (WebRTC) ────────────────────────────────────────────────

  @impl true
  def handle_in("call:request", %{"type" => call_type} = params, socket) do
    if_authorized(socket, fn ->
      user_id = socket.assigns.user_id
      app_id = socket.assigns.app_id
      conversation_id = socket.assigns[:conversation_id]
      group_id = socket.assigns[:group_id]
      receiver_id = params["receiver_id"]

      # Ensure receiver_id is a string (since schema now uses :string universally)
      receiver_id = if is_binary(receiver_id), do: receiver_id, else: to_string(receiver_id)

      # Security: Verify membership or group status
      case {conversation_id, group_id} do
        {conv_id, nil} when not is_nil(conv_id) ->
          # 1-on-1 Call
          case Chat.get_conversation_for_user(app_id, conv_id, user_id) do
            {:ok, conversation} ->
              # Automatically identify receiver if not provided by SDK
              receiver_id =
                receiver_id ||
                  if conversation.user_a_id == user_id,
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

        {nil, grp_id} when not is_nil(grp_id) ->
          # Group Call
          initiate_and_broadcast_call(app_id, nil, grp_id, user_id, nil, call_type, socket)

        _ ->
          {:reply, {:error, %{reason: "invalid_context"}}, socket}
      end
    end)
  end

  @impl true
  def handle_in("call:ringing", %{"call_id" => call_id}, socket) do
    with_call_auth(socket, call_id, fn ->
      app_id = socket.assigns.app_id
      Calls.set_ringing(app_id, call_id)
      broadcast_from!(socket, "call:ringing", %{call_id: call_id})
      {:reply, :ok, socket}
    end)
  end

  @impl true
  def handle_in("call:respond", %{"call_id" => call_id, "response" => action}, socket) do
    with_call_auth(socket, call_id, fn ->
      app_id = socket.assigns.app_id

      case action do
        "accept" ->
          case Calls.accept_call(app_id, call_id) do
            {:ok, call} ->
              # Fetch identities from local cache safely
              caller = Accounts.get_registered_user(app_id, call.caller_id)
              receiver = Accounts.get_registered_user(app_id, call.receiver_id)

              caller_display_name =
                if(caller && caller.name && caller.name != "",
                  do: caller.name,
                  else: (caller && caller.phone) || "User"
                )

              receiver_display_name =
                if(receiver && receiver.name && receiver.name != "",
                  do: receiver.name,
                  else: (receiver && receiver.phone) || "User"
                )

              # Generate LiveKit Tokens
              livekit_url =
                Application.get_env(:revoluchat, :livekit)[:url] || System.get_env("LIVEKIT_URL") ||
                  "ws://localhost:7880"

              # Unified token generation: caller always gets one, receiver gets one if present
              {:ok, caller_token} =
                Revoluchat.LiveKit.Token.generate(call_id, call.caller_id, caller_display_name)

              # For Group Calls, call.receiver_id is 0 or nil.
              # We generate a token for the CURRENT user who is accepting.
              current_user_id = socket.assigns.user_id
              # This was fetched based on current_user in Calls.accept_call context
              current_user_name = receiver_display_name

              {:ok, current_user_token} =
                Revoluchat.LiveKit.Token.generate(call_id, current_user_id, current_user_name)

              # Generate CoTURN credentials dynamically
              coturn_caller = Revoluchat.RTC.TurnCredentials.generate(call.caller_id)
              coturn_receiver = Revoluchat.RTC.TurnCredentials.generate(current_user_id)

              payload = %{
                "call_id" => call_id,
                "status" => "connected",
                "caller_id" => call.caller_id,
                "caller_name" => caller_display_name,
                "receiver_id" => current_user_id,
                "receiver_name" => current_user_name,
                "livekit_url" => livekit_url,
                "livekit_token_caller" => caller_token,
                "livekit_token_receiver" => current_user_token,
                "is_group" => not is_nil(call.group_id),
                "coturn_host" => coturn_caller.host,
                "coturn_port" => coturn_caller.port,
                "coturn_username_caller" => coturn_caller.username,
                "coturn_credential_caller" => coturn_caller.credential,
                "coturn_username_receiver" => coturn_receiver.username,
                "coturn_credential_receiver" => coturn_receiver.credential
              }

              # 1. Broadast to Room (for everyone in conversation/group)
              broadcast!(socket, "call:accepted", payload)

              # 2. Force broadcast to Caller's Private Channel (so caller can connect to LiveKit)
              caller_topic = "user:#{call.caller_id}"
              RevoluchatWeb.Endpoint.broadcast!(caller_topic, "call:accepted", payload)

              # 3. If 1-on-1, also notify the specific receiver channel (redundant but safe)
              if call.receiver_id && call.receiver_id != 0 do
                receiver_topic = "user:#{call.receiver_id}"
                RevoluchatWeb.Endpoint.broadcast!(receiver_topic, "call:accepted", payload)
              end

              {:reply, :ok, socket}

            {:error, :invalid_status} ->
              {:reply, {:error, %{reason: "invalid_state"}}, socket}

            error ->
              Logger.error("ChatChannel: Failed to accept call #{call_id}: #{inspect(error)}")
              {:reply, {:error, %{reason: "failed"}}, socket}
          end

        "reject" ->
          case Calls.reject_call(app_id, call_id) do
            {:ok, call} ->
              payload = %{
                "call_id" => call_id,
                "caller_id" => call.caller_id,
                "receiver_id" => call.receiver_id
              }

              # 1. Broadcast to Room
              broadcast_from!(socket, "call:rejected", payload)

              # 2. Force broadcast to Caller's Private Channel (for UI updates)
              target_topic = "user:#{call.caller_id}"
              Logger.info("ChatChannel: Broadcasting call:rejected to #{target_topic}")
              RevoluchatWeb.Endpoint.broadcast!(target_topic, "call:rejected", payload)

              # Emit summary message for rejected call
              insert_call_summary(call, socket)

              {:reply, :ok, socket}

            _ ->
              {:reply, {:error, %{reason: "failed"}}, socket}
          end
      end
    end)
  end

  @impl true
  def handle_in("call:hangup", %{"call_id" => call_id} = _payload, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id
    Logger.info("ChatChannel: Received call:hangup for call #{call_id} from user #{user_id}")

    case String.starts_with?(call_id, "pending-") do
      true ->
        # For pending calls, notify room and all participants globally
        app_id = socket.assigns.app_id
        group_id = socket.assigns[:group_id]
        user_id = socket.assigns.user_id
        payload = %{call_id: call_id, status: "missed"}

        broadcast_from!(socket, "call:hangup", payload)

        if group_id do
          case Chat.get_group(app_id, group_id) do
            {:ok, group} ->
              Enum.each(group.members, fn member ->
                if to_string(member.user_id) != to_string(user_id) do
                  RevoluchatWeb.Endpoint.broadcast(
                    "user:#{member.user_id}",
                    "call:hangup",
                    payload
                  )
                end
              end)

            _ ->
              :ok
          end
        end

        {:reply, :ok, socket}

      false ->
        with_call_auth(socket, call_id, fn ->
          app_id = socket.assigns.app_id

          case Calls.complete_call(app_id, call_id) do
            {:ok, call} ->
              # 1. Broadcast to Room
              payload = %{
                "call_id" => call_id,
                "status" => call.status,
                "conversation_id" => call.conversation_id
              }

              Logger.info("ChatChannel: Broadcasting call:hangup to room. Status: #{call.status}")
              broadcast_from!(socket, "call:hangup", payload)

              # 2. Global signaling for all participants
              is_group = call.group_id && call.group_id != ""

              Logger.info(
                "ChatChannel: Global signaling. IsGroup: #{is_group}, GroupID: #{call.group_id}"
              )

              if is_group do
                case Chat.get_group(app_id, call.group_id) do
                  {:ok, group} ->
                    members = Enum.map(group.members, fn m -> to_string(m.user_id) end)
                    Logger.info("ChatChannel: Group members for hangup: #{inspect(members)}")

                    Enum.each(group.members, fn member ->
                      topic = "user:#{member.user_id}"

                      Logger.info(
                        "ChatChannel: Broadcasting hangup to group member topic: #{topic}"
                      )

                      RevoluchatWeb.Endpoint.broadcast(topic, "call:hangup", payload)
                    end)

                  _ ->
                    Logger.warning(
                      "ChatChannel: Group #{call.group_id} not found for hangup signaling"
                    )
                end
              else
                caller_topic = "user:#{call.caller_id}"
                receiver_topic = "user:#{call.receiver_id}"

                Logger.info(
                  "ChatChannel: Broadcasting hangup to private topics: #{caller_topic} and #{receiver_topic}"
                )

                RevoluchatWeb.Endpoint.broadcast!(caller_topic, "call:hangup", payload)

                if call.receiver_id && call.receiver_id != 0 do
                  RevoluchatWeb.Endpoint.broadcast!(receiver_topic, "call:hangup", payload)
                end
              end

              # Emit summary message for completed call
              insert_call_summary(call, socket)

              {:reply, :ok, socket}
          end
        end)
    end
  end

  @impl true
  def handle_in("call:cancel", %{"call_id" => call_id} = _payload, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id
    Logger.info("ChatChannel: Received call:cancel for call #{call_id} from user #{user_id}")

    case String.starts_with?(call_id, "pending-") do
      true ->
        # For pending calls, we still want to notify the other party
        app_id = socket.assigns.app_id
        conversation_id = socket.assigns[:conversation_id]
        user_id = socket.assigns.user_id

        cancel_payload = %{call_id: call_id, status: "missed"}
        broadcast_from!(socket, "call:cancel", cancel_payload)

        if conversation_id do
          case Chat.get_conversation_for_user(app_id, conversation_id, user_id) do
            {:ok, conv} ->
              receiver_id = if conv.user_a_id == user_id, do: conv.user_b_id, else: conv.user_a_id

              RevoluchatWeb.Endpoint.broadcast!(
                "user:#{receiver_id}",
                "call:cancel",
                cancel_payload
              )

            _ ->
              :ok
          end
        end

        group_id = socket.assigns[:group_id]

        if group_id do
          case Chat.get_group(app_id, group_id) do
            {:ok, group} ->
              Enum.each(group.members, fn member ->
                if to_string(member.user_id) != to_string(user_id) do
                  RevoluchatWeb.Endpoint.broadcast(
                    "user:#{member.user_id}",
                    "call:cancel",
                    cancel_payload
                  )
                end
              end)

            _ ->
              :ok
          end
        end

        {:reply, :ok, socket}

      false ->
        with_call_auth(socket, call_id, fn ->
          app_id = socket.assigns.app_id

          case Calls.cancel_call(app_id, call_id) do
            {:ok, call} ->
              payload = %{
                "call_id" => call_id,
                "status" => "missed",
                "conversation_id" => call.conversation_id
              }

              Logger.info("ChatChannel: Broadcasting call:cancel to room. Status: missed")
              broadcast_from!(socket, "call:cancel", payload)

              # Notify other parties globally
              is_group = call.group_id && call.group_id != ""

              Logger.info(
                "ChatChannel: Global cancel signaling. IsGroup: #{is_group}, GroupID: #{call.group_id}"
              )

              if is_group do
                case Chat.get_group(app_id, call.group_id) do
                  {:ok, group} ->
                    members = Enum.map(group.members, fn m -> to_string(m.user_id) end)
                    Logger.info("ChatChannel: Group members for cancel: #{inspect(members)}")

                    Enum.each(group.members, fn member ->
                      topic = "user:#{member.user_id}"

                      Logger.info(
                        "ChatChannel: Broadcasting cancel to group member topic: #{topic}"
                      )

                      RevoluchatWeb.Endpoint.broadcast(topic, "call:cancel", payload)
                    end)

                  _ ->
                    Logger.warning(
                      "ChatChannel: Group #{call.group_id} not found for cancel signaling"
                    )
                end
              else
                Logger.info(
                  "ChatChannel: Broadcasting cancel to private topic user:#{call.receiver_id}"
                )

                if call.receiver_id != 0,
                  do:
                    RevoluchatWeb.Endpoint.broadcast!(
                      "user:#{call.receiver_id}",
                      "call:cancel",
                      payload
                    )

                if call.caller_id != 0,
                  do:
                    RevoluchatWeb.Endpoint.broadcast!(
                      "user:#{call.caller_id}",
                      "call:cancel",
                      payload
                    )
              end

              insert_call_summary(call, socket)
              {:reply, :ok, socket}
          end
        end)
    end
  end

  # --- GROUP MANAGEMENT EVENTS ---

  @impl true
  def handle_in("create_group", params, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id

    # Enforce current user as admin
    admin_ids = params["admin_ids"] || []
    admin_ids = if Enum.member?(admin_ids, user_id), do: admin_ids, else: [user_id | admin_ids]
    params = params |> Map.put("admin_ids", admin_ids) |> Map.put(:creator_id, user_id)

    case Chat.create_group(app_id, params) do
      {:ok, group} ->
        # Notify all members about the new group - format per user to ensure correct my_status (pending vs accepted)
        Enum.each(group.members, fn member ->
          formatted_group =
            RevoluchatWeb.GroupController.format_group(group, app_id, member.user_id)

          RevoluchatWeb.Endpoint.broadcast("user:#{member.user_id}", "conversation_updated", %{
            conversation_id: group.id,
            type: "group",
            group: formatted_group
          })
        end)

        # For the creator's reply, use their own formatted group
        creator_formatted = RevoluchatWeb.GroupController.format_group(group, app_id, user_id)
        {:reply, {:ok, creator_formatted}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  @impl true
  def handle_in("add_members", %{"group_id" => group_id, "user_ids" => user_ids} = params, socket) do
    app_id = socket.assigns.app_id
    role = params["role"] || "member"

    raw_id = clean_id(group_id)

    # Sync members to Advance tier first synchronously
    Enum.each(user_ids, fn uid ->
      Revoluchat.Accounts.sync_user_profile_to_advance_tier_sync(app_id, uid)
    end)

    case Chat.add_members(app_id, raw_id, user_ids, role) do
      {:ok, _} ->
        # Notify existing room
        broadcast!(socket, "members_added", %{group_id: group_id, user_ids: user_ids, role: role})

        # Notify new members via their personal channels
        case Chat.get_group(app_id, raw_id) do
          {:ok, group} ->
            Enum.each(user_ids, fn member_id ->
              formatted_for_member =
                RevoluchatWeb.GroupController.format_group(group, app_id, member_id)

              RevoluchatWeb.Endpoint.broadcast("user:#{member_id}", "conversation_updated", %{
                conversation_id: group_id,
                type: "group",
                group: formatted_for_member
              })
            end)

          _ ->
            :ok
        end

        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  @impl true
  def handle_in("remove_member", %{"group_id" => group_id, "user_id" => target_id}, socket) do
    app_id = socket.assigns.app_id

    case Chat.remove_member(app_id, group_id, target_id) do
      {:ok, _} ->
        broadcast!(socket, "member_removed", %{group_id: group_id, user_id: target_id})
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  @impl true
  def handle_in("update_group", %{"group_id" => group_id} = params, socket) do
    app_id = socket.assigns.app_id

    case Chat.update_group(app_id, group_id, params) do
      {:ok, group} ->
        formatted_group =
          RevoluchatWeb.GroupController.format_group(group, app_id, socket.assigns.user_id)

        broadcast!(socket, "group_updated", formatted_group)
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  @impl true
  def handle_in("leave_group", %{"group_id" => group_id}, socket) do
    app_id = socket.assigns.app_id
    user_id = socket.assigns.user_id

    case Chat.leave_group(app_id, group_id, user_id) do
      :ok ->
        broadcast!(socket, "member_left", %{group_id: group_id, user_id: user_id})
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  def handle_in("accept_group", %{"group_id" => group_id}, socket) do
    app_id = socket.assigns.app_id
    user_id = socket.assigns.user_id

    case Chat.accept_group_invitation(app_id, group_id, user_id) do
      :ok ->
        broadcast!(socket, "member_joined", %{group_id: group_id, user_id: user_id})
        # Notify user to refresh their conversation list (so status changes from pending)
        RevoluchatWeb.Endpoint.broadcast("user:#{user_id}", "conversation_updated", %{
          conversation_id: group_id,
          type: "group"
        })

        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  @impl true
  def handle_in("mute_group", %{"group_id" => group_id, "mute" => mute}, socket) do
    app_id = socket.assigns.app_id
    user_id = socket.assigns.user_id

    case Chat.mute_group(app_id, group_id, user_id, mute) do
      :ok ->
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  @impl true
  def handle_in("delete_group", %{"group_id" => group_id}, socket) do
    app_id = socket.assigns.app_id

    case Chat.delete_group(app_id, group_id) do
      {:ok, _} ->
        broadcast!(socket, "group_deleted", %{group_id: group_id})
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  # ─── PRIVATE HELPERS ─────────────────────────────────────────────────────────

  defp if_authorized(socket, callback) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id
    conversation_id = socket.assigns[:conversation_id]
    group_id = socket.assigns[:group_id]

    case conversation_id do
      nil ->
        # Check group authorization
        # For now, we trust the socket if join_group succeeded
        callback.()

      conv_id ->
        case Chat.get_conversation_for_user(app_id, conv_id, user_id) do
          {:ok, _} -> callback.()
          {:error, :not_found} -> {:reply, {:error, %{reason: "unauthorized"}}, socket}
        end
    end
  end

  defp clean_id(id) when is_binary(id) do
    id |> String.replace(~r/^(group_|room_)/, "")
  end

  defp clean_id(id), do: id

  defp join_conversation(_topic_app_id, conversation_id, app_id, user_id, socket) do
    raw_id = clean_id(conversation_id)

    if String.starts_with?(conversation_id, "group_") do
      case Chat.get_group(app_id, raw_id) do
        {:ok, group} ->
          case Enum.find(group.members, &(&1.user_id == user_id)) do
            member when not is_nil(member) ->
              socket = assign(socket, :group_id, conversation_id)
              messages = Chat.list_messages(app_id, nil, user_id, group_id: raw_id, limit: 50)
              formatted_group = RevoluchatWeb.GroupController.format_group(group, app_id, user_id)

              finish_join(messages, app_id, nil, user_id, socket, %{
                group: formatted_group,
                my_status: member.status
              })

            nil ->
              {:error, %{reason: "unauthorized"}}
          end

        _ ->
          {:error, %{reason: "group_not_found"}}
      end
    else
      case Chat.get_conversation_for_user(app_id, raw_id, user_id) do
        {:ok, _conversation} ->
          socket = assign(socket, :conversation_id, conversation_id)
          messages = Chat.list_messages(app_id, raw_id, user_id, limit: 50)

          # Reuse common join logic
          finish_join(messages, app_id, conversation_id, user_id, socket, %{})

        {:error, :not_found} ->
          Logger.warning("ChatChannel: User #{user_id} unauthorized for room #{conversation_id}")
          {:error, %{reason: "unauthorized"}}
      end
    end
  end

  defp join_group(_topic_app_id, group_id, app_id, user_id, socket) do
    raw_id = clean_id(group_id)
    socket = assign(socket, :group_id, group_id)
    messages = Chat.list_messages(app_id, nil, user_id, group_id: raw_id, limit: 50)

    # Fetch group metadata to return to client
    group_meta =
      case Chat.get_group(app_id, raw_id) do
        {:ok, g} ->
          formatted = RevoluchatWeb.GroupController.format_group(g, app_id, user_id)
          %{group: formatted, my_status: formatted.my_status}

        _ ->
          %{}
      end

    finish_join(messages, app_id, group_id, user_id, socket, group_meta)
  end

  defp finish_join(messages, app_id, target_id, user_id, socket, extra_meta) do
    sender_ids = Enum.map(messages, & &1.sender_id) |> Enum.uniq()
    users_data = Revoluchat.Accounts.list_registered_users_by_ids(app_id, sender_ids)
    users_map = Revoluchat.Accounts.build_users_map(users_data)

    all_attachment_ids =
      messages
      |> Enum.flat_map(&(&1.attachment_ids || []))
      |> Enum.concat(Enum.map(messages, & &1.attachment_id))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    attachments_map =
      if all_attachment_ids != [] do
        Chat.list_attachments_by_ids(app_id, all_attachment_ids)
        |> Map.new(fn a -> {a.id, a} end)
      else
        %{}
      end

    send(self(), :after_join)
    Logger.info("ChatChannel: User #{user_id} joined #{target_id}")

    reply =
      extra_meta
      |> Map.put(
        :messages,
        Enum.map(messages, fn m ->
          m_atts =
            (m.attachment_ids || [])
            |> Enum.map(&Map.get(attachments_map, &1))
            |> Enum.concat([Map.get(attachments_map, m.attachment_id)])
            |> Enum.reject(&is_nil/1)
            |> Enum.uniq_by(& &1.id)

          format_message_with_user(m, users_map, m_atts, socket)
        end)
      )

    {:ok, reply, socket}
  end

  defp process_new_message(payload, conversation_id, group_id, user_id, socket) do
    app_id = socket.assigns.app_id

    # Extract attachment_ids as a list
    attachment_ids =
      (Map.get(payload, "attachment_ids") || [])
      |> List.wrap()
      |> Enum.reject(&is_nil/1)

    # Legacy support: if singular id provided but plural empty
    attachment_ids =
      if attachment_ids == [] and Map.has_key?(payload, "attachment_id") do
        [Map.get(payload, "attachment_id")]
      else
        attachment_ids
      end

    attachment_id = List.first(attachment_ids)

    # Auto-detect type if not provided but attachment exists
    type = Map.get(payload, "type")
    type = if is_nil(type) && attachment_ids != [], do: "attachment", else: type || "text"

    attrs = %{
      app_id: app_id,
      conversation_id: conversation_id,
      group_id: group_id,
      sender_id: user_id,
      type: type,
      body: Map.get(payload, "body"),
      is_encrypted: Map.get(payload, "is_encrypted", false) || Map.has_key?(payload, "e2ee_recipients"),
      attachment_id: attachment_id,
      attachment_ids: attachment_ids,
      reply_to_id: Map.get(payload, "reply_to_id"),
      client_id: Map.get(payload, "client_id"),
      # Store per-recipient E2EE ciphertexts in metadata so each recipient can retrieve their own
      metadata: case Map.get(payload, "e2ee_recipients") do
        recipients when is_map(recipients) and map_size(recipients) > 0 ->
          %{"e2ee_recipients" => recipients, "e2ee_type" => Map.get(payload, "e2ee_type", 5)}
        _ -> nil
      end
    }

    Logger.debug("ChatChannel: Processing new message with attrs: #{inspect(attrs)}")

    Logger.debug("ChatChannel: Processing new_message payload: #{inspect(payload)}")

    case Chat.insert_message(attrs) do
      {:ok, message, attachments} ->
        Logger.info("ChatChannel: Successfully inserted message #{message.id}")
        Logger.debug("ChatChannel: Message inserted. Attachments count: #{length(attachments)}")

        # Fetch sender info for broadcast from local DB (cache)
        user = Revoluchat.Accounts.get_registered_user(app_id, message.sender_id)
        current_user_id = socket && socket.assigns[:user_id]
        is_self = to_string(message.sender_id) == to_string(current_user_id)
        target_privacy = (user && (Map.get(user, :privacy_settings) || Map.get(user, "privacy_settings"))) || %{}
        target_photo = Map.get(target_privacy, "profile_photo") || Map.get(target_privacy, :profile_photo)
        hide_photo = not is_self and target_photo in ["Tidak ada", "Nobody", "nobody"]

        raw_avatar = if(user, do: resolve_group_avatar(user.avatar_url), else: nil)
        avatar_url = if hide_photo, do: nil, else: raw_avatar

        formatted_message =
          message
          |> format_message(attachments, socket)
          |> Map.put(:user, %{
            id: if(user, do: user.user_id, else: message.sender_id),
            name: (user && user.name) || "Unknown",
            phone: if(user, do: user.phone, else: nil),
            avatar_url: avatar_url
          })

        # Broadcast ke semua (termasuk sender untuk konfirmasi visual real-time)
        broadcast!(socket, "new_message", formatted_message)

        # 3. Broadcast conversation_updated or group_updated
        if conversation_id do
          {:ok, conversation} = Chat.get_conversation_for_user(app_id, conversation_id, user_id)

          update_payload = %{
            conversation_id: conversation_id,
            last_message: formatted_message,
            unread_count_update: 1
          }

          RevoluchatWeb.Endpoint.broadcast(
            "user:#{conversation.user_a_id}",
            "conversation_updated",
            update_payload
          )

          RevoluchatWeb.Endpoint.broadcast(
            "user:#{conversation.user_b_id}",
            "conversation_updated",
            update_payload
          )

          # FCM Push for Conversations (only if receiver is offline)
          receiver_id =
            if message.sender_id == conversation.user_a_id,
              do: conversation.user_b_id,
              else: conversation.user_a_id

          topic_name = "tenant:#{app_id}:room:#{conversation_id}"
          presence_list = Presence.list(topic_name)

          is_receiver_online =
            Map.has_key?(presence_list, receiver_id) ||
              Map.has_key?(presence_list, to_string(receiver_id))

          if not is_receiver_online do
            %{
              "app_id" => app_id,
              "user_id" => receiver_id,
              "conversation_id" => conversation_id,
              "message" => formatted_message
            }
            |> Revoluchat.Workers.FcmPushWorker.new()
            |> Oban.insert()
          end
        else
          # Group Update
          # We need to notify all members so their conversation list updates (unread count, last message)
          formatted_group_id =
            if String.starts_with?(group_id, "group_"), do: group_id, else: "group_#{group_id}"

          {:ok, group} = Chat.get_group(app_id, group_id)

          update_payload = %{
            conversation_id: formatted_group_id,
            last_message: formatted_message,
            unread_count_update: 1,
            type: "group"
          }

          Enum.each(group.members, fn member ->
            # Don't broadcast to sender if they are already in the room (optional, but consistent)
            RevoluchatWeb.Endpoint.broadcast(
              "user:#{member.user_id}",
              "conversation_updated",
              update_payload
            )
          end)

          # FCM Push for Offline Group Members
          clean_grp_id = clean_id(group_id)
          group_topic = "tenant:#{app_id}:group:#{clean_grp_id}"
          room_topic = "tenant:#{app_id}:room:group_#{clean_grp_id}"

          group_presence = Presence.list(group_topic)
          room_presence = Presence.list(room_topic)

          is_member_online = fn m_id ->
            m_id_str = to_string(m_id)
            Map.has_key?(group_presence, m_id_str) or Map.has_key?(room_presence, m_id_str)
          end

          resolved_avatar = resolve_group_avatar(group.avatar_url)

          Enum.each(group.members, fn member ->
            # Don't send push to the sender
            if to_string(member.user_id) != to_string(message.sender_id) do
              if not is_member_online.(member.user_id) do
                # Retrieve recipient-specific E2EE ciphertext from message metadata
                e2ee_recipients = get_in(message, [Access.key(:metadata, %{}), "e2ee_recipients"]) || %{}
                member_id_str = to_string(member.user_id)
                recipient_cipher = Map.get(e2ee_recipients, member_id_str)

                base_job = %{
                  "app_id" => app_id,
                  "user_id" => member.user_id,
                  "conversation_id" => formatted_group_id,
                  "message" => formatted_message,
                  "conversation_name" => group.name,
                  "sender_avatar_url" => resolved_avatar
                }

                # Include recipient's specific ciphertext so FCM worker can deliver encrypted_body
                job_args = if recipient_cipher do
                  Map.put(base_job, "encrypted_body", recipient_cipher)
                else
                  base_job
                end

                job_args
                |> Revoluchat.Workers.FcmPushWorker.new()
                |> Oban.insert()
              end
            end
          end)
        end

        # --- Observability ---
        latency_ms = DateTime.diff(DateTime.utc_now(), message.inserted_at, :millisecond)
        :telemetry.execute([:revoluchat, :messages, :delivered], %{count: 1}, %{app_id: app_id})

        :telemetry.execute([:revoluchat, :messages, :latency], %{ms: latency_ms}, %{
          app_id: app_id
        })

        {:reply, {:ok, %{message_id: message.id}}, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_errors(changeset)
        {:reply, {:error, %{reason: "validation_failed", errors: errors}}, socket}
    end
  end

  defp format_message_with_user(message, users_map, attachments, socket) do
    sender_id_str = to_string(message.sender_id)
    user = Map.get(users_map, sender_id_str) || Map.get(users_map, message.sender_id)

    current_user_id = socket && socket.assigns[:user_id]
    current_user = Map.get(users_map, to_string(current_user_id)) || Map.get(users_map, current_user_id)

    is_self = sender_id_str == to_string(current_user_id)
    target_privacy = (user && (Map.get(user, :privacy_settings) || Map.get(user, "privacy_settings"))) || %{}
    current_privacy = (current_user && (Map.get(current_user, :privacy_settings) || Map.get(current_user, "privacy_settings"))) || %{}

    target_photo = Map.get(target_privacy, "profile_photo") || Map.get(target_privacy, :profile_photo)
    current_photo = Map.get(current_privacy, "profile_photo") || Map.get(current_privacy, :profile_photo)

    target_photo_disabled = target_photo in ["Tidak ada", "Nobody", "nobody"]
    current_photo_disabled = current_photo in ["Tidak ada", "Nobody", "nobody"]

    hide_photo = not is_self and (target_photo_disabled or current_photo_disabled)

    raw_avatar = if(user, do: resolve_group_avatar(user.avatar_url), else: nil)
    avatar_url = if hide_photo, do: nil, else: raw_avatar

    message
    |> format_message(attachments, socket)
    |> Map.put(:user, %{
      id: if(user, do: user.id, else: message.sender_id),
      name: if(user, do: user.name, else: "Unknown"),
      phone: if(user, do: user.phone, else: nil),
      avatar_url: avatar_url
    })
  end

  defp format_message(message, attachments, socket) do
    status =
      cond do
        not is_nil(message.read_at) -> "read"
        not is_nil(message.delivered_at) -> "delivered"
        true -> "sent"
      end

    # If attachments list not provided, try to use singular or fetch plural
    attachments_list =
      cond do
        is_list(attachments) ->
          attachments

        not is_nil(message.attachment) ->
          [message.attachment]

        is_list(message.attachment_ids) and message.attachment_ids != [] ->
          # Fallback fetch (slow, but should be preloaded by caller)
          Chat.list_attachments_by_ids(message.app_id, message.attachment_ids)

        true ->
          []
      end

    e2ee_recipients = get_in(message, [Access.key(:metadata, %{}), "e2ee_recipients"]) ||
      get_in(message, [Access.key(:metadata, %{}), :e2ee_recipients]) || %{}

    %{
      id: message.id,
      type: message.type,
      body: message.body,
      status: status,
      is_encrypted: message.is_encrypted,
      sender_id: message.sender_id,
      conversation_id: message.conversation_id,
      group_id: message.group_id,
      reply_to_id: message.reply_to_id,
      client_id: message.client_id,
      attachment: attachments_list |> List.first() |> format_attachment(socket),
      attachments: Enum.map(attachments_list, &format_attachment(&1, socket)),
      delivered_at: format_dt(message.delivered_at),
      read_at: format_dt(message.read_at),
      deleted_at: format_dt(message.deleted_at),
      inserted_at: format_dt(message.inserted_at),
      # Per-recipient E2EE ciphertexts — each client picks their own entry
      e2ee_recipients: if(map_size(e2ee_recipients) > 0, do: e2ee_recipients, else: nil)
    }
  end

  defp format_attachment(%Ecto.Association.NotLoaded{}, _socket), do: nil
  defp format_attachment(nil, _socket), do: nil

  defp format_attachment(att, socket) do
    # Generate full authenticated proxy URL
    base_url = RevoluchatWeb.Endpoint.url()
    token = socket.assigns.token
    api_key = socket.assigns.api_key

    url = "#{base_url}/api/a/v1/attachments/#{att.id}/show?token=#{token}&api_key=#{api_key}"

    type =
      cond do
        String.starts_with?(att.mime_type || "", "image/") -> "image"
        String.starts_with?(att.mime_type || "", "video/") -> "video"
        String.starts_with?(att.mime_type || "", "audio/") -> "audio"
        true -> "file"
      end

    %{
      id: att.id,
      url: url,
      mime_type: att.mime_type,
      type: type,
      filename: Map.get(att.metadata || %{}, "filename") || "file",
      size: att.size,
      metadata: att.metadata
    }
  end

  defp with_call_auth(socket, call_id, callback) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id

    try do
      if Calls.is_participant?(app_id, call_id, user_id) do
        callback.()
      else
        Logger.warning("Unauthorized signaling attempt by User #{user_id} for Call #{call_id}")
        {:reply, {:error, %{reason: "unauthorized_signaling"}}, socket}
      end
    rescue
      e ->
        Logger.error("Signaling internal error for Call #{call_id}: #{inspect(e)}")
        {:reply, {:error, %{reason: "internal_error"}}, socket}
    end
  end

  defp insert_call_summary(call, socket) do
    payload = Calls.generate_summary_payload(call)
    app_id = socket.assigns.app_id

    case Chat.insert_message(payload) do
      {:ok, message, attachments} ->
        broadcast!(socket, "new_message", format_message(message, attachments, socket))

        # Broadcast conversation_updated to participants
        is_group = call.group_id && call.group_id != ""

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
        Logger.error("Failed to insert call summary message for Call #{call.id}")
    end
  end

  defp format_dt(nil), do: nil
  defp format_dt(dt), do: DateTime.to_iso8601(dt)

  defp get_status(message) do
    cond do
      not is_nil(message.read_at) -> "read"
      not is_nil(message.delivered_at) -> "delivered"
      true -> "sent"
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp check_rate_and_process(payload, conversation_id, group_id, user_id, socket) do
    case RateLimiter.check_message_rate(user_id) do
      {:error, :rate_limited} ->
        {:reply, {:error, %{reason: "rate_limited", retry_after: 10}}, socket}

      :ok ->
        if group_id do
          case Chat.get_group(socket.assigns.app_id, group_id) do
            {:ok, %{is_locked: true}} ->
              {:reply, {:error, %{reason: "group_locked"}}, socket}

            _ ->
              process_new_message(payload, nil, group_id, user_id, socket)
          end
        else
          process_new_message(payload, conversation_id, nil, user_id, socket)
        end
    end
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

        # Broadcast within room/group
        broadcast!(socket, "call:incoming", payload)

        # Global signaling
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
        Logger.error("Failed to initiate call: #{inspect(reason)}")
        {:reply, {:error, %{reason: "failed_to_initiate"}}, socket}
    end
  end

  defp handle_offline_call_push(app_id, conversation_id, receiver_id, payload) do
    topic_name = "tenant:#{app_id}:room:#{conversation_id}"
    presence_list = Presence.list(topic_name)

    is_receiver_online =
      Map.has_key?(presence_list, receiver_id) ||
        Map.has_key?(presence_list, to_string(receiver_id))

    if not is_receiver_online do
      %{"app_id" => app_id, "user_id" => receiver_id, "call" => payload}
      |> Revoluchat.Workers.FcmPushWorker.new()
      |> Oban.insert()
    end
  end

  defp resolve_group_avatar(nil), do: nil
  defp resolve_group_avatar(""), do: nil

  defp resolve_group_avatar(url) do
    if String.match?(url, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i) do
      "/api/a/v1/attachments/#{url}/show"
    else
      url
    end
  end
end
