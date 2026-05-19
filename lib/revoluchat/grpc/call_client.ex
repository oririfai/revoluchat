defmodule Revoluchat.Grpc.CallClient do
  @moduledoc """
  gRPC Client for Call operations in Advance Tier.
  """
  require Logger
  alias Revoluchat.Grpc.Interceptors.AuthClient
  alias Revoluchat.V1.{
    CallService.Stub,
    InitiateCallRequest,
    GetCallRequest,
    UpdateCallStatusRequest,
    ListCallHistoryRequest,
    DeleteCallHistoryRequest
  }

  defp endpoint, do: System.get_env("CHAT_SERVICE_GRPC_ENDPOINT", "localhost:50051")

  defp connect do
    case GRPC.Stub.connect(endpoint()) do
      {:ok, channel} -> {:ok, channel}
      {:error, reason} ->
        Logger.error("[gRPC] Failed to connect to Chat Service (Calls): #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp metadata(user_id \\ nil, app_id \\ nil) do
    base = AuthClient.get_auth_metadata()
    base = if user_id, do: Map.put(base, "x-user-id", to_string(user_id)), else: base
    if app_id, do: Map.put(base, "x-app-id", app_id), else: base
  end

  def get_call(app_id, id) do
    with {:ok, channel} <- connect() do
      req = %GetCallRequest{call_id: id, app_id: app_id}
      case Stub.get_call(channel, req, metadata: metadata()) do
        {:ok, resp} -> {:ok, resp.call}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def is_participant?(app_id, call_id, user_id) do
    case get_call(app_id, call_id) do
      {:ok, call} ->
        is_p = cond do
          # 1. Group Call
          call.group_id && call.group_id != "" ->
            Logger.info("Grpc CallClient: is_participant? checking group call. GroupID: #{call.group_id}")
            case Revoluchat.Chat.get_group(app_id, call.group_id) do
              {:ok, group} ->
                members = Enum.map(group.members, fn m -> to_string(m.user_id) end)
                Logger.info("Grpc CallClient: Group #{call.group_id} members: #{inspect(members)}")
                Enum.any?(group.members, fn m -> to_string(m.user_id) == to_string(user_id) end)
              _ -> 
                Logger.warning("Grpc CallClient: get_group #{call.group_id} failed for participant check")
                false
            end

          # 2. 1-on-1 Call
          true ->
            Logger.info("Grpc CallClient: is_participant? checking 1-on-1 call. Caller: #{call.caller_id}, Receiver: #{call.receiver_id}")
            to_string(call.caller_id) == to_string(user_id) || 
            to_string(call.receiver_id) == to_string(user_id)
        end
        Logger.info("Grpc CallClient: is_participant? for user #{user_id} on call #{call_id} result: #{is_p}")
        is_p
      error -> 
        Logger.error("Grpc CallClient: is_participant? failed to get_call #{call_id}: #{inspect(error)}")
        false
    end
  end

  def create_call(attrs) do
    # Usually calls are initiated via initiate_call
    {:ok, attrs}
  end

  def update_call(call, _attrs), do: {:ok, call}

  def initiate_call(app_id, conversation_id, caller_id, receiver_id, type, group_id \\ nil) do
    with {:ok, channel} <- connect() do
      req = %InitiateCallRequest{
        app_id: app_id,
        conversation_id: conversation_id,
        group_id: group_id,
        caller_id: to_string(caller_id),
        receiver_id: to_string(receiver_id || ""),
        type: type
      }
      case Stub.initiate_call(channel, req, metadata: metadata(caller_id, app_id)) do
        {:ok, resp} -> 
          # Enrichment: Fetch real identity from Accounts
          identity = 
            case Revoluchat.Accounts.get_registered_user(app_id, caller_id) do
              nil -> %{name: "User #{caller_id}", photo: nil, phone: nil}
              u -> %{name: u.name || u.phone, photo: u.avatar_url, phone: u.phone}
            end

          {:ok, resp.call, identity}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def set_ringing(app_id, call_id), do: update_status(app_id, call_id, "ringing")
  def accept_call(app_id, call_id), do: update_status(app_id, call_id, "connected")
  def reject_call(app_id, call_id), do: update_status(app_id, call_id, "rejected")
  def complete_call(app_id, call_id), do: update_status(app_id, call_id, "completed")
  def cancel_call(app_id, call_id), do: update_status(app_id, call_id, "canceled")

  defp update_status(app_id, call_id, status) do
    with {:ok, channel} <- connect() do
      req = %UpdateCallStatusRequest{app_id: app_id, call_id: call_id, status: status}
      case Stub.update_call_status(channel, req, metadata: metadata(nil, app_id)) do
        {:ok, resp} -> {:ok, resp.call}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def list_call_history(app_id, user_id, opts) do
    with {:ok, channel} <- connect() do
      req = %ListCallHistoryRequest{
        app_id: app_id,
        user_id: to_string(user_id),
        limit: opts[:limit] || 50,
        other_party_id: to_string(opts[:other_party_id] || "")
      }
      case Stub.list_call_history(channel, req, metadata: metadata(user_id, app_id)) do
        {:ok, resp} -> 
          Logger.info("[gRPC CallClient] list_call_history for user #{user_id} returned #{length(resp.records)} records")
          resp.records
        {:error, reason} -> 
          Logger.error("[gRPC CallClient] list_call_history failed for user #{user_id}: #{inspect(reason)}")
          []
      end
    end
  end

  def delete_call_history(app_id, user_id, ids) do
    with {:ok, channel} <- connect() do
      req = %DeleteCallHistoryRequest{app_id: app_id, user_id: to_string(user_id), ids: ids}
      case Stub.delete_call_history(channel, req, metadata: metadata(user_id, app_id)) do
        {:ok, resp} -> {resp.count, nil}
        {:error, _} -> {0, nil}
      end
    end
  end
end
