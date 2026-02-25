defmodule Revoluchat.Grpc.UserClient do
  @moduledoc """
  gRPC Client for fetching user data from User Service.
  """

  alias User.V1.{GetUserRequest, UserService.Stub}

  @doc """
  Fetch user details by ID.
  """
  def get_user(user_id) do
    endpoint = System.get_env("USER_SERVICE_GRPC_ENDPOINT", "localhost:50051")
    request = %GetUserRequest{id: user_id}

    case GRPC.Stub.connect(endpoint) do
      {:ok, channel} ->
        case Stub.get_user(channel, request) do
          {:ok, response} ->
            {:ok, parse_response(response)}

          {:error, %{status: 5}} -> # NOT_FOUND
            {:error, :not_found}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
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
end
