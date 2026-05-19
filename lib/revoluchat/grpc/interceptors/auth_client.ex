defmodule Revoluchat.Grpc.Interceptors.AuthClient do
  @moduledoc """
  Helper for gRPC Clients to inject authentication metadata.
  """


  @doc """
  Returns metadata with x-server-key for outbound calls.
  """
  def get_auth_metadata do
    case get_active_key() do
      nil -> %{}
      key -> %{"x-server-key" => key}
    end
  end

  def get_auth_metadata(user_id, app_id) do
    metadata = get_auth_metadata()

    metadata =
      if user_id, do: Map.put(metadata, "x-user-id", to_string(user_id)), else: metadata

    metadata = if app_id, do: Map.put(metadata, "x-app-id", app_id), else: metadata

    metadata
  end

  defp get_active_key do
    case Revoluchat.Accounts.get_active_server_key() do
      nil -> nil
      sk -> sk.key
    end
  end
end
