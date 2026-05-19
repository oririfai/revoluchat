defmodule Revoluchat.Calls do
  @moduledoc """
  The Calls context.
  Dispatcher between Postgres and gRPC adapters.
  """

  @doc """
  Returns the active storage adapter based on TIER_TYPE.
  """
  def adapter do
    case Application.get_env(:revoluchat, :tier_type) do
      "advance" -> Revoluchat.Calls.Adapters.Grpc
      _ -> Revoluchat.Calls.Adapters.Postgres
    end
  end

  # ─── Calls ────────────────────────────────────────────────────────────

  def get_call(app_id, id), do: adapter().get_call(app_id, id)
  def is_participant?(app_id, call_id, user_id), do: adapter().is_participant?(app_id, call_id, user_id)
  def create_call(attrs \\ %{}), do: adapter().create_call(attrs)
  def update_call(call, attrs), do: adapter().update_call(call, attrs)
  def initiate_call(app_id, conversation_id, caller_id, receiver_id, type, group_id \\ nil) do
    adapter().initiate_call(app_id, conversation_id, caller_id, receiver_id, type, group_id)
  end
  
  def set_ringing(app_id, call_id), do: adapter().set_ringing(app_id, call_id)
  def accept_call(app_id, call_id), do: adapter().accept_call(app_id, call_id)
  def reject_call(app_id, call_id), do: adapter().reject_call(app_id, call_id)
  def complete_call(app_id, call_id), do: adapter().complete_call(app_id, call_id)
  def cancel_call(app_id, call_id), do: adapter().cancel_call(app_id, call_id)
  
  def list_call_history(app_id, user_id, opts \\ []), do: adapter().list_call_history(app_id, user_id, opts)
  def delete_call_history(app_id, user_id, ids), do: adapter().delete_call_history(app_id, user_id, ids)

  # ─── Shared Logic (Formatters) ────────────────────────────────────────────────

  @doc """
  Generates a system message summary for a finished call.
  """
  def generate_summary_payload(call) do
    duration_str = format_duration(call.duration_seconds || 0)
    type_label = if call.type == "video", do: "Panggilan video", else: "Panggilan suara"

    status_text =
      case call.status do
        "completed" -> "#{type_label} berakhir"
        "missed" -> "#{type_label} tidak terjawab"
        "rejected" -> "#{type_label} ditolak"
        "canceled" -> "#{type_label} dibatalkan"
        _ -> "#{type_label} selesai"
      end

    %{
      app_id: call.app_id,
      conversation_id: call.conversation_id,
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
end
