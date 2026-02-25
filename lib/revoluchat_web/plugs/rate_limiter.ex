defmodule RevoluchatWeb.Plugs.RateLimiter do
  @moduledoc """
  Helper module for Rate Limiting in Channels/Contexts (non-Plug usage).
  """

  # 30 pesan per 10 detik
  @message_limit 30
  @message_scale 10_000

  def check_message_rate(user_id) do
    key = "ws_msg:#{user_id}"

    case Hammer.check_rate(key, @message_scale, @message_limit) do
      {:allow, _count} -> :ok
      {:deny, _limit} -> {:error, :rate_limited}
    end
  end
end
