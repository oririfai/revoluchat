defmodule Revoluchat.Grpc.UserClient do
  @moduledoc """
  gRPC Client for fetching user data from User Service.
  """

  alias User.V1.{
    GetUserRequest, 
    SearchUserByPhoneRequest, 
    AddContactRequest, 
    ListContactsRequest, 
    RemoveContactRequest,
    UserService.Stub
  }

  @doc """
  Search user by phone number (Advance Tier).
  """
  def search_user_by_phone(app_id, phone) do
    endpoint = System.get_env("USER_SERVICE_GRPC_ENDPOINT", "localhost:50051")
    request = %SearchUserByPhoneRequest{app_id: app_id, phone: phone}
    metadata = Revoluchat.Grpc.Interceptors.AuthClient.get_auth_metadata()

    case GRPC.Stub.connect(endpoint) do
      {:ok, channel} ->
        case Stub.search_user_by_phone(channel, request, metadata: metadata) do
          {:ok, response} -> {:ok, response}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Add contact (Advance Tier).
  """
  def add_contact(app_id, owner_id, contact_id) do
    endpoint = System.get_env("USER_SERVICE_GRPC_ENDPOINT", "localhost:50051")
    request = %AddContactRequest{app_id: app_id, owner_id: owner_id, contact_id: contact_id}
    metadata = Revoluchat.Grpc.Interceptors.AuthClient.get_auth_metadata()

    case GRPC.Stub.connect(endpoint) do
      {:ok, channel} ->
        case Stub.add_contact(channel, request, metadata: metadata) do
          {:ok, response} -> {:ok, response}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List contacts (Advance Tier).
  """
  def list_contacts(app_id, user_id) do
    endpoint = System.get_env("USER_SERVICE_GRPC_ENDPOINT", "localhost:50051")
    request = %ListContactsRequest{app_id: app_id, user_id: user_id}
    metadata = Revoluchat.Grpc.Interceptors.AuthClient.get_auth_metadata()

    case GRPC.Stub.connect(endpoint) do
      {:ok, channel} ->
        case Stub.list_contacts(channel, request, metadata: metadata) do
          {:ok, response} -> {:ok, response.contacts}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Remove contact (Advance Tier).
  """
  def remove_contact(app_id, owner_id, contact_id) do
    endpoint = System.get_env("USER_SERVICE_GRPC_ENDPOINT", "localhost:50051")
    request = %RemoveContactRequest{app_id: app_id, owner_id: owner_id, contact_id: contact_id}
    metadata = Revoluchat.Grpc.Interceptors.AuthClient.get_auth_metadata()

    case GRPC.Stub.connect(endpoint) do
      {:ok, channel} ->
        case Stub.remove_contact(channel, request, metadata: metadata) do
          {:ok, response} -> {:ok, response}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetch user details by ID.
  """
  require Logger

  def get_user(user_id) do
    endpoint = System.get_env("USER_SERVICE_GRPC_ENDPOINT", "localhost:50051")
    Logger.debug("[gRPC] Connecting to User Service at #{endpoint}")
    
    # Ensure id is a string
    id =
      case user_id do
        id when is_binary(id) -> id
        id when is_integer(id) -> Integer.to_string(id)
        _ -> ""
      end

    request = %GetUserRequest{id: id}
    metadata = Revoluchat.Grpc.Interceptors.AuthClient.get_auth_metadata()

    case GRPC.Stub.connect(endpoint) do
      {:ok, channel} ->
        case Stub.get_user(channel, request, metadata: metadata) do
          {:ok, response} ->
            Logger.debug("[gRPC] Success fetching user #{id}")
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
