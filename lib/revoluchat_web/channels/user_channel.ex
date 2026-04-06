defmodule RevoluchatWeb.UserChannel do
  use Phoenix.Channel
  require Logger
  alias Revoluchat.{Calls, Accounts}

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

                payload = %{
                  "call_id" => call_id,
                  "status" => "connected",
                  "caller_id" => call.caller_id,
                  "caller_name" => caller_name,
                  "receiver_id" => call.receiver_id,
                  "receiver_name" => receiver_name
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
                payload = %{ "call_id" => call_id, "status" => "rejected" }
                # Broadcast to Room and Participants
                RevoluchatWeb.Endpoint.broadcast!("tenant:#{app_id}:room:#{call.conversation_id}", "call:rejected", payload)
                RevoluchatWeb.Endpoint.broadcast!("user:#{call.caller_id}", "call:rejected", payload)
                
                {:reply, :ok, socket}
              error ->
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

  # FAST PATH SIGNALING: WebRTC signals (offer/answer/ICE) via User Channel
  # Allows caller and receiver to exchange SDP without requiring both to be in the room channel
  def handle_in("call:signal", %{"call_id" => call_id, "signal" => signal, "target_user_id" => target_user_id}, socket) do
    user_id = socket.assigns.user_id
    app_id = socket.assigns.app_id

    try do
      if Calls.is_participant?(app_id, call_id, user_id) do
        payload = %{
          "call_id" => call_id,
          "signal" => signal
        }
        RevoluchatWeb.Endpoint.broadcast!("user:#{target_user_id}", "call:signal", payload)
        {:reply, :ok, socket}
      else
        {:reply, {:error, %{reason: "unauthorized"}}, socket}
      end
    rescue
      e ->
        Logger.error("UserChannel signal error: #{inspect(e)}")
        {:reply, {:error, %{reason: "internal_error"}}, socket}
    end
  end
end
