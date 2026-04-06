defmodule Revoluchat.Calls do
  @moduledoc """
  The Calls context.
  """

  import Ecto.Query, warn: false
  alias Revoluchat.Repo

  alias Revoluchat.Calls.Call
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
            update_call(call, %{status: "connected"})
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
      call -> update_call(call, %{status: "rejected", ended_at: DateTime.utc_now()})
    end
  end

  def complete_call(call_id) do
    case get_call(call_id) do
      nil -> {:error, :not_found}
      call ->
        ended_at = DateTime.utc_now()
        # Calculate duration server-side to prevent client manipulation
        duration = if call.started_at, do: DateTime.diff(ended_at, call.started_at), else: 0

        update_call(call, %{
          status: "completed",
          ended_at: ended_at,
          duration_seconds: duration
        })
    end
  end

  @doc """
  Generates a system message summary for a finished call.
  """
  def generate_summary_payload(%Call{} = call) do
    duration_str = format_duration(call.duration_seconds || 0)

    status_text =
      case call.status do
        "completed" -> "Panggilan berakhir"
        "missed" -> "Panggilan tidak terjawab"
        "rejected" -> "Panggilan ditolak"
        _ -> "Panggilan selesai"
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
      call -> update_call(call, %{status: "missed", ended_at: DateTime.utc_now()})
    end
  end
end
