defmodule Revoluchat.Calls do
  @moduledoc """
  The Calls context.
  """

  import Ecto.Query, warn: false
  alias Revoluchat.Repo

  alias Revoluchat.Calls.{Call, CallHistory}
  alias Revoluchat.Accounts

  @doc """
  Gets a single call.
  """
  def get_call(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.get(Call, uuid)
      _ -> nil
    end
  end

  @doc """
  Verifies if a user is a participant of a call.
  """
  def is_participant?(app_id, call_id, user_id) do
    case Ecto.UUID.cast(call_id) do
      {:ok, uuid} ->
        query =
          from(c in Call,
            where:
              c.app_id == ^app_id and c.id == ^uuid and
                (c.caller_id == ^user_id or c.receiver_id == ^user_id)
          )

        Repo.exists?(query)
      
      _ -> false
    end
  end

  @doc """
  Creates a call.
  """
  def create_call(attrs \\ %{}) do
    %Call{}
    |> Call.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a call.
  """
  def update_call(%Call{} = call, attrs) do
    call
    |> Call.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Initiates a call session.
  Returns {:ok, call, caller_identity}
  """
  def initiate_call(app_id, conversation_id, caller_id, receiver_id, type) do
    attrs = %{
      app_id: app_id,
      conversation_id: conversation_id,
      caller_id: caller_id,
      receiver_id: receiver_id,
      type: type,
      status: "dialing",
      started_at: DateTime.utc_now()
    }

    with {:ok, call} <- create_call(attrs) do
      # Use local cache for caller identity
      caller = Accounts.get_registered_user(app_id, caller_id)
      
      caller_identity = %{
        name: (caller && caller.name) || "Unknown",
        photo: (caller && caller.avatar_url),
        phone: (caller && caller.phone)
      }

      {:ok, call, caller_identity}
    end
  end

  def set_ringing(call_id) do
    case get_call(call_id) do
      nil -> {:error, :not_found}
      call -> update_call(call, %{status: "ringing"})
    end
  end

  def accept_call(call_id) do
    case get_call(call_id) do
      nil -> {:error, :not_found}
      call ->
        # Idempotent check: if already connected, just return ok
        if call.status == "connected" do
           {:ok, call}
        else
          # Only allow answering if dialed or ringing
          if call.status in ["dialing", "ringing"] do
            update_call(call, %{status: "connected", started_at: DateTime.utc_now()})
          else
            Logger.warning("Calls: Attempted to accept call #{call_id} in invalid state: #{call.status}")
            {:error, :invalid_status}
          end
        end
    end
  end

  def reject_call(call_id) do
    case get_call(call_id) do
      nil -> {:error, :not_found}
      call ->
        with {:ok, updated_call} <- update_call(call, %{status: "rejected", ended_at: DateTime.utc_now()}) do
          record_history(updated_call)
          {:ok, updated_call}
        end
    end
  end

  def complete_call(call_id) do
    case get_call(call_id) do
      nil -> {:error, :not_found}
      call ->
        ended_at = DateTime.utc_now()
        # If call was never connected, it's a missed/cancelled call
        new_status = if call.status == "connected", do: "completed", else: "missed"
        
        # Calculate duration server-side to prevent client manipulation
        # Duration is only relevant if it was actually connected
        duration = 
          if call.status == "connected" and call.started_at, 
            do: DateTime.diff(ended_at, call.started_at), 
            else: 0

        with {:ok, updated_call} <- update_call(call, %{
          status: new_status,
          ended_at: ended_at,
          duration_seconds: duration
        }) do
          record_history(updated_call)
          {:ok, updated_call}
        end
    end
  end

  @doc """
  Generates a system message summary for a finished call.
  """
  def generate_summary_payload(%Call{} = call) do
    duration_str = format_duration(call.duration_seconds || 0)
    type_label = if call.type == "video", do: "Panggilan video", else: "Panggilan suara"

    status_text =
      case call.status do
        "completed" -> "#{type_label} berakhir"
        "missed" -> "#{type_label} tidak terjawab"
        "rejected" -> "#{type_label} ditolak"
        _ -> "#{type_label} selesai"
      end

    %{
      app_id: call.app_id,
      conversation_id: call.conversation_id,
      # Always attribute to caller for system record
      sender_id: call.caller_id,
      type: "system_call_summary",
      body: "#{status_text} • #{duration_str}",
      metadata: %{
        "call_id" => call.id,
        "call_type" => call.type,
        "status" => call.status,
        "duration_seconds" => call.duration_seconds
      }
    }
  end

  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)

    if hours > 0 do
      "#{pad(hours)}:#{pad(minutes)}:#{pad(secs)}"
    else
      "#{pad(minutes)}:#{pad(secs)}"
    end
  end

  defp pad(num), do: num |> Integer.to_string() |> String.pad_leading(2, "0")

  def cancel_call(call_id) do
    case get_call(call_id) do
      nil -> {:error, :not_found}
      call ->
        with {:ok, updated_call} <- update_call(call, %{status: "missed", ended_at: DateTime.utc_now()}) do
          record_history(updated_call)
          {:ok, updated_call}
        end
    end
  end

  @doc """
  List call history for a specific user.
  Includes the "other party" identity for re-calling.
  """
  def list_call_history(app_id, user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    other_party_id = Keyword.get(opts, :other_party_id)

    query =
      from(ch in CallHistory,
        where: ch.app_id == ^app_id and ch.user_id == ^user_id,
        order_by: [desc: ch.inserted_at],
        limit: ^limit
      )

    query =
      if other_party_id do
        from(ch in query, where: ch.other_party_id == ^other_party_id)
      else
        query
      end

    history_records = Repo.all(query)
    other_party_ids = Enum.map(history_records, & &1.other_party_id) |> Enum.uniq()
    
    # Fetch user identities for the "other party"
    users_data = Accounts.list_registered_users_by_ids(app_id, other_party_ids)
    users_map = Map.new(users_data, fn u -> {u.id, u} end)

    Enum.map(history_records, fn rec ->
      other = Map.get(users_map, rec.other_party_id)
      Map.merge(rec, %{
        other_party_name: (other && other.name) || "Unknown",
        other_party_avatar: (other && other.avatar_url),
        other_party_phone: (other && other.phone)
      })
    end)
  end

  @doc """
  Deletes specific call history records for a user.
  """
  def delete_call_history(app_id, user_id, ids) when is_list(ids) do
    require Logger
    Logger.info("Calls: Deleting call history for user #{user_id} (App: #{app_id}). Count: #{length(ids)}")

    # Ensure IDs are valid UUIDs and cast them for the query
    valid_ids = 
      ids 
      |> Enum.map(fn id -> 
        case Ecto.UUID.cast(id) do
          {:ok, uuid} -> uuid
          _ -> 
            Logger.warning("Calls: Invalid UUID string received: #{inspect(id)}")
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(valid_ids) do
      Logger.warning("Calls: No valid UUIDs to delete.")
      {0, nil}
    else
      # Final security check: Ensure we are only deleting records belonging to the requester
      query =
        from(ch in CallHistory,
          where: ch.app_id == ^app_id and ch.user_id == ^user_id and ch.id in ^valid_ids
        )

      {count, result} = Repo.delete_all(query)
      Logger.info("Calls: Successfully deleted #{count} records from database.")
      {count, result}
    end
  end

  # ─── PRIVATE HELPERS ─────────────────────────────────────────────────────────

  defp record_history(%Call{} = call) do
    # Record history for BOTH participants
    
    # 1. Caller's record (Outgoing)
    caller_history = %{
      app_id: call.app_id,
      user_id: call.caller_id,
      other_party_id: call.receiver_id,
      direction: "outgoing",
      type: call.type,
      status: call.status,
      duration_seconds: call.duration_seconds || 0,
      started_at: call.started_at,
      conversation_id: call.conversation_id
    }

    # 2. Receiver's record (Incoming)
    receiver_history = %{
      app_id: call.app_id,
      user_id: call.receiver_id,
      other_party_id: call.caller_id,
      direction: "incoming",
      type: call.type,
      status: call.status,
      duration_seconds: call.duration_seconds || 0,
      started_at: call.started_at,
      conversation_id: call.conversation_id
    }

    %CallHistory{} |> CallHistory.changeset(caller_history) |> Repo.insert()
    %CallHistory{} |> CallHistory.changeset(receiver_history) |> Repo.insert()
  end
end
