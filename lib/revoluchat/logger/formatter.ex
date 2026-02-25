defmodule Revoluchat.Logger.Formatter do
  def format(level, message, timestamp, metadata) do
    log =
      %{
        level: level,
        message: to_string(message),
        timestamp: format_timestamp(timestamp),
        request_id: Keyword.get(metadata, :request_id),
        user_id: Keyword.get(metadata, :user_id),
        conversation_id: Keyword.get(metadata, :conversation_id),
        message_id: Keyword.get(metadata, :message_id)
      }
      |> Map.reject(fn {_, v} -> is_nil(v) end)

    Jason.encode!(log) <> "\n"
  rescue
    _ -> "#{level}: #{message}\n"
  end

  defp format_timestamp({{y, m, d}, {h, min, s, ms}}) do
    "#{y}-#{pad(m)}-#{pad(d)}T#{pad(h)}:#{pad(min)}:#{pad(s)}.#{ms}Z"
  end

  defp pad(n), do: String.pad_leading(to_string(n), 2, "0")
end
