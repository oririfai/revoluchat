defmodule Revoluchat.Grpc.AdminClient do
  @moduledoc """
  gRPC Client for administrative operations.
  """
  require Logger

  alias Admin.V1.{
    ListUsersRequest,
    SuspendUserRequest,
    UnsuspendUserRequest,
    AdminService.Stub
  }

  defp endpoint, do: System.get_env("USER_SERVICE_GRPC_ENDPOINT", "localhost:50051")

  @doc """
  List users with pagination and search query.
  """
  def list_users(query, page, limit, status_filter \\ "all") do
    request = %ListUsersRequest{
      query: query,
      page: page,
      limit: limit,
      status_filter: status_filter
    }

    metadata = Revoluchat.Grpc.Interceptors.AuthClient.get_auth_metadata()

    case GRPC.Stub.connect(endpoint(), adapter_opts: [connect_timeout: 1000]) do
      {:ok, channel} ->
        case Stub.list_users(channel, request, metadata: metadata) do
          {:ok, response} ->
            {:ok, %{
              users: Enum.map(response.users, &parse_admin_user/1),
              total_count: response.total_count,
              total_pages: response.total_pages
            }}
          {:error, reason} ->
            Logger.error("[AdminClient] ListUsers error: #{inspect(reason)}")
            {:error, reason}
        end
      {:error, reason} ->
        Logger.error("[AdminClient] Failed to connect to gRPC: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Suspend a user.
  """
  def suspend_user(user_id, duration, reason) do
    request = %SuspendUserRequest{
      user_id: user_id,
      duration: duration,
      reason: reason
    }

    metadata = Revoluchat.Grpc.Interceptors.AuthClient.get_auth_metadata()

    case GRPC.Stub.connect(endpoint(), adapter_opts: [connect_timeout: 1000]) do
      {:ok, channel} ->
        case Stub.suspend_user(channel, request, metadata: metadata) do
          {:ok, response} -> {:ok, response}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Unsuspend a user.
  """
  def unsuspend_user(user_id) do
    request = %UnsuspendUserRequest{user_id: user_id}
    metadata = Revoluchat.Grpc.Interceptors.AuthClient.get_auth_metadata()

    case GRPC.Stub.connect(endpoint(), adapter_opts: [connect_timeout: 1000]) do
      {:ok, channel} ->
        case Stub.unsuspend_user(channel, request, metadata: metadata) do
          {:ok, response} -> {:ok, response}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_admin_user(user) do
    %{
      id: user.id,
      uuid: user.uuid,
      name: user.name,
      phone: user.phone,
      status: user.status,
      inserted_at: user.inserted_at,
      is_kyc: user.is_kyc
    }
  end
end
