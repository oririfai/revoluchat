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
  def get_call!(id), do: Repo.get!(Call, id)

  @doc """
  Verifies if a user is a participant of a call.
  """
  def is_participant?(call_id, user_id) do
    query =
      from(c in Call,
        where: c.id == ^call_id and (c.caller_id == ^user_id or c.receiver_id == ^user_id)
      )

    Repo.exists?(query)
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

    with {:ok, call} <- create_call(attrs),
         {:ok, caller} <- Accounts.get_user(caller_id) do
      caller_identity = %{
        name: caller.name,
        photo: caller.avatar_url,
        phone: caller.phone
      }

      {:ok, call, caller_identity}
    end
  end

  def set_ringing(call_id) do
    call = get_call!(call_id)
    update_call(call, %{status: "ringing"})
  end

  def accept_call(call_id) do
    call = get_call!(call_id)
    # Only allow answering if dialed or ringing
    if call.status in ["dialing", "ringing"] do
      update_call(call, %{status: "connected"})
    else
      {:error, :invalid_status}
    end
  end

  def reject_call(call_id) do
    call = get_call!(call_id)
    update_call(call, %{status: "rejected", ended_at: DateTime.utc_now()})
  end

  def complete_call(call_id) do
    call = get_call!(call_id)
    ended_at = DateTime.utc_now()

    # Calculate duration server-side to prevent client manipulation
    duration = if call.started_at, do: DateTime.diff(ended_at, call.started_at), else: 0

    update_call(call, %{
      status: "completed",
      ended_at: ended_at,
      duration_seconds: duration
    })
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
    call = get_call!(call_id)
    update_call(call, %{status: "missed", ended_at: DateTime.utc_now()})
  end
end
