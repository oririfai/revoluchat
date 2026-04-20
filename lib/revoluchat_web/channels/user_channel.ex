defmodule RevoluchatWeb.UserChannel do
  use Phoenix.Channel
  require Logger
  alias Revoluchat.{Calls, Accounts, Chat}

  def join("user:" <> user_id, _params, socket) do
    # Security check: User can only join their own topic
    authorized_user_id = to_string(socket.assigns.user_id)
    
    if user_id == authorized_user_id do
      Logger.info("UserChannel: User #{user_id} joined their private channel")
      {:ok, socket}
    else
      Logger.warning("UserChannel: User #{authorized_user_id} attempted to join private channel of user #{user_id}")
      {:error, %{reason: "unauthorized"}}
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
            case Calls.accept_call(call_id) do
              {:ok, call} ->
                # Build payload
                caller = Accounts.get_registered_user(app_id, call.caller_id)
                receiver = Accounts.get_registered_user(app_id, call.receiver_id)

                caller_name = if(caller && caller.name && caller.name != "", do: caller.name, else: (caller && caller.phone) || "User")
                receiver_name = if(receiver && receiver.name && receiver.name != "", do: receiver.name, else: (receiver && receiver.phone) || "User")

                # Generate LiveKit Tokens
                livekit_url = Application.get_env(:revoluchat, :livekit)[:url] || System.get_env("LIVEKIT_URL") || "ws://localhost:7880"
                {:ok, caller_token} = Revoluchat.LiveKit.Token.generate(call_id, call.caller_id, caller_name)
                {:ok, receiver_token} = Revoluchat.LiveKit.Token.generate(call_id, call.receiver_id, receiver_name)

                payload = %{
                  "call_id" => call_id,
                  "type" => call.type,
                  "status" => "connected",
                  "caller_id" => call.caller_id,
                  "caller_name" => caller_name,
                  "receiver_id" => call.receiver_id,
                  "receiver_name" => receiver_name,
                  "livekit_url" => livekit_url,
                  "livekit_token_caller" => caller_token,
                  "livekit_token_receiver" => receiver_token
                }

                # BROADCAST to ALL redundant paths
                # Room topic
                RevoluchatWeb.Endpoint.broadcast!("tenant:#{app_id}:room:#{call.conversation_id}", "call:accepted", payload)
                # Private topics (Global)
                RevoluchatWeb.Endpoint.broadcast!("user:#{call.caller_id}", "call:accepted", payload)
                RevoluchatWeb.Endpoint.broadcast!("user:#{call.receiver_id}", "call:accepted", payload)

                {:reply, :ok, socket}

              {:error, reason} ->
                Logger.error("UserChannel: Failed to accept call #{call_id}: #{inspect(reason)}")
                {:reply, {:error, %{reason: "failed_to_accept"}}, socket}
            end

          "reject" ->
            case Calls.reject_call(call_id) do
              {:ok, call} ->
                payload = %{ "call_id" => call_id, "status" => "rejected", "type" => call.type }
                # Broadcast to Room and Participants
                RevoluchatWeb.Endpoint.broadcast!("tenant:#{app_id}:room:#{call.conversation_id}", "call:rejected", payload)
                RevoluchatWeb.Endpoint.broadcast!("user:#{call.caller_id}", "call:rejected", payload)
                
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

  def handle_in("call:hangup", %{"call_id" => call_id}, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id
    try do
      if Calls.is_participant?(app_id, call_id, user_id) do
        case Calls.complete_call(call_id) do
          {:ok, call} ->
            payload = %{"call_id" => call_id, "status" => call.status, "type" => call.type}
            # Broadcast to Room and Participants
            RevoluchatWeb.Endpoint.broadcast!("tenant:#{app_id}:room:#{call.conversation_id}", "call:hangup", payload)
            RevoluchatWeb.Endpoint.broadcast!("user:#{call.caller_id}", "call:hangup", payload)
            RevoluchatWeb.Endpoint.broadcast!("user:#{call.receiver_id}", "call:hangup", payload)

            # Insert summary bubble
            insert_call_summary(call)
            
            {:reply, :ok, socket}
          _error ->
            {:reply, {:error, %{reason: "failed_to_hangup"}}, socket}
        end
      else
        {:reply, {:error, %{reason: "unauthorized"}}, socket}
      end
    rescue
      _ -> {:reply, {:error, %{reason: "internal_error"}}, socket}
    end
  end

  def handle_in("call:cancel", %{"call_id" => call_id}, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id
    try do
      if Calls.is_participant?(app_id, call_id, user_id) do
        case Calls.cancel_call(call_id) do
          {:ok, call} ->
            payload = %{"call_id" => call_id, "status" => "missed", "type" => call.type}
            # Broadcast to Room and Participants
            RevoluchatWeb.Endpoint.broadcast!("tenant:#{app_id}:room:#{call.conversation_id}", "call:cancel", payload)
            RevoluchatWeb.Endpoint.broadcast!("user:#{call.caller_id}", "call:cancel", payload)
            RevoluchatWeb.Endpoint.broadcast!("user:#{call.receiver_id}", "call:cancel", payload)

            # Insert summary bubble
            insert_call_summary(call)
            
            {:reply, :ok, socket}
          _error ->
            {:reply, {:error, %{reason: "failed_to_cancel"}}, socket}
        end
      else
        {:reply, {:error, %{reason: "unauthorized"}}, socket}
      end
    rescue
      _ -> {:reply, {:error, %{reason: "internal_error"}}, socket}
    end
  end


  def handle_in("call:ringing", %{"call_id" => call_id}, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id
    try do
      if Calls.is_participant?(app_id, call_id, user_id) do
        case Calls.get_call(call_id) do
          {:ok, call} ->
            # Update state in DB
            Calls.set_ringing(call_id)
            
            # Notify the caller specifically
            RevoluchatWeb.Endpoint.broadcast!("user:#{call.caller_id}", "call:ringing", %{"call_id" => call_id, "type" => call.type})
            
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
        room_topic = "tenant:#{call.app_id}:room:#{call.conversation_id}"
        RevoluchatWeb.Endpoint.broadcast!(room_topic, "new_message", format_message(message, attachments))

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
      url: "/api/v1/attachments/#{att.id}/show",
      mime_type: att.mime_type,
      size: att.size,
      metadata: att.metadata
    }
  end

  defp format_dt(nil), do: nil
  defp format_dt(dt), do: DateTime.to_iso8601(dt)

end
