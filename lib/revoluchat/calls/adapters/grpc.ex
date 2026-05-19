defmodule Revoluchat.Calls.Adapters.Grpc do
  @moduledoc """
  gRPC implementation of the Calls Adapter.
  """
  @behaviour Revoluchat.Calls.Adapter
  require Logger

  alias Revoluchat.Grpc.CallClient

  def get_call(app_id, id) do
    case CallClient.get_call(app_id, id) do
      {:ok, call} -> normalize_call(call)
      nil -> nil
      error -> error
    end
  end

  def is_participant?(app_id, call_id, user_id), do: CallClient.is_participant?(app_id, call_id, user_id)
  
  def create_call(attrs), do: CallClient.create_call(attrs)
  
  def update_call(call, attrs), do: CallClient.update_call(call, attrs)

  def initiate_call(app_id, conversation_id, caller_id, receiver_id, type, group_id \\ nil) do
    case CallClient.initiate_call(app_id, conversation_id, caller_id, receiver_id, type, group_id) do
      {:ok, call, identity} -> {:ok, normalize_call(call), identity}
      error -> error
    end
  end
  
  def set_ringing(app_id, call_id) do
    case CallClient.set_ringing(app_id, call_id) do
      {:ok, call} -> {:ok, normalize_call(call)}
      error -> error
    end
  end

  def accept_call(app_id, call_id) do
    case CallClient.accept_call(app_id, call_id) do
      {:ok, call} -> {:ok, normalize_call(call)}
      error -> error
    end
  end

  def reject_call(app_id, call_id) do
    case CallClient.reject_call(app_id, call_id) do
      {:ok, call} -> {:ok, normalize_call(call)}
      error -> error
    end
  end

  def complete_call(app_id, call_id) do
    case get_call(app_id, call_id) do
      nil -> 
        Logger.error("GrpcAdapter: complete_call failed - call #{call_id} not found")
        {:error, :not_found}
      
      {:error, reason} = err ->
        Logger.error("GrpcAdapter: complete_call failed - error fetching call: #{inspect(reason)}")
        err

      call ->
        Logger.info("GrpcAdapter: Found call #{call_id} for completion. Status: #{call.status}, Caller: #{call.caller_id}, Receiver: #{call.receiver_id}")
        # If call was answered (connected), mark as completed, else it's missed
        if call.status == "connected" do
          CallClient.complete_call(app_id, call_id)
        else
          CallClient.cancel_call(app_id, call_id)
        end
        |> case do
          {:ok, updated} -> {:ok, normalize_call(updated)}
          error -> 
            Logger.error("GrpcAdapter: CallClient failed to update status: #{inspect(error)}")
            error
        end
    end
  end

  def cancel_call(app_id, call_id) do
    case CallClient.cancel_call(app_id, call_id) do
      {:ok, call} -> {:ok, normalize_call(call)}
      error -> error
    end
  end
  
  def list_call_history(app_id, user_id, opts) do
    case CallClient.list_call_history(app_id, user_id, opts) do
      history_records when is_list(history_records) ->
        # Enrich with user profile data from Accounts
        other_party_ids = Enum.map(history_records, & &1.other_party_id) |> Enum.uniq()
        users_data = Revoluchat.Accounts.list_registered_users_by_ids(app_id, other_party_ids)
        users_map = Map.new(users_data, fn u -> {u.id, u} end)

        history_records
        |> Enum.map(fn rec ->
          other = Map.get(users_map, rec.other_party_id)
          rec
          |> normalize_history()
          |> Map.merge(%{
            other_party_name: (other && other.name) || "Unknown",
            other_party_avatar: (other && other.avatar_url),
            other_party_phone: (other && other.phone)
          })
        end)

      error ->
        Logger.error("GrpcAdapter: list_call_history failed for user #{user_id}: #{inspect(error)}")
        []
    end
  end

  def delete_call_history(app_id, user_id, ids), do: CallClient.delete_call_history(app_id, user_id, ids)

  # ─── Private Helpers ─────────────────────────────────────────────────────────

  defp normalize_call(nil), do: nil
  defp normalize_call(call) do
    group_id = if call.group_id == "", do: nil, else: call.group_id
    %{call |
      group_id: group_id,
      started_at: parse_dt(call.started_at),
      ended_at: parse_dt(call.ended_at)
    }
  end

  defp normalize_history(nil), do: nil
  defp normalize_history(rec) do
    raw_group_id = Map.get(rec, :group_id)
    group_id = if raw_group_id == "" || is_nil(raw_group_id), do: nil, else: raw_group_id
    %{rec |
      group_id: group_id,
      started_at: parse_dt(rec.started_at),
      inserted_at: parse_dt(rec.inserted_at) || DateTime.utc_now(),
      updated_at: parse_dt(rec.updated_at) || DateTime.utc_now()
    }
  end

  defp parse_dt(nil), do: nil
  defp parse_dt(""), do: nil
  defp parse_dt(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
  defp parse_dt(dt), do: dt
end
