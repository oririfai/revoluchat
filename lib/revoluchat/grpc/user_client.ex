defmodule Revoluchat.Grpc.UserClient do
  @moduledoc """
  gRPC Client for fetching user data from User Service.
  """

  alias User.V1.{GetUserRequest, UserService.Stub}

  @doc """
  Fetch user details by ID.
  """
  require Logger

  def get_user(user_id) do
    endpoint = System.get_env("USER_SERVICE_GRPC_ENDPOINT", "localhost:50051")
    Logger.debug("[gRPC] Connecting to User Service at #{endpoint}")
    
    # Ensure id is an integer for Protobuf uint64
    id =
      case user_id do
        id when is_binary(id) -> String.to_integer(id)
        id when is_integer(id) -> id
        _ -> 0
      end

    request = %GetUserRequest{id: id}

    case GRPC.Stub.connect(endpoint) do
      {:ok, channel} ->
        case Stub.get_user(channel, request) do
          {:ok, response} ->
            {:ok, parse_response(response)}

          {:error, %{status: 5}} -> # NOT_FOUND
            Logger.error("[gRPC] User ID #{id} NOT_FOUND in User Service")
            {:error, :not_found}

          {:error, reason} ->
            Logger.error("[gRPC] Error from User Service: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("[gRPC] Failed to connect to User Service: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_response(response) do
    %{
      id: response.id,
      uuid: response.uuid,
      name: response.name,
      phone: response.phone,
      status: response.status,
      is_kyc: response.is_kyc,
      avatar_url: response.avatar_url
    }
  end

  def get_users(user_ids) do
    user_ids
    |> Task.async_stream(fn id -> get_user(id) end, max_concurrency: 10)
    |> Enum.map(fn
      {:ok, {:ok, user}} -> user
      _ -> nil
    end)
    |> Enum.filter(& &1)
  end
end
