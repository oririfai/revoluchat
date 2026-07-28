defmodule Revoluchat.Grpc.AdminClient do
  @moduledoc """
  gRPC Client for administrative operations.
  """
  require Logger

  alias Admin.V1.{
    ListUsersRequest,
    SuspendUserRequest,
    UnsuspendUserRequest,
    GetGlobalChatStatsRequest,
    AddWallpaperRequest,
    DeleteWallpaperRequest,
    GetWallpapersRequest,
    SetAppPreferenceRequest,
    GetAppPreferencesRequest,
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

  @doc """
  Get global chat stats for Admin Dashboard.
  """
  def get_global_stats do
    request = %GetGlobalChatStatsRequest{}
    
    # Use Chat service endpoint because stats is implemented in chatcx-be
    # although it's an AdminService. If chatcx-be is the single backend,
    # we can use CHAT_SERVICE_GRPC_ENDPOINT which points to chatcx-be (port 50055).
    chat_endpoint = System.get_env("CHAT_SERVICE_GRPC_ENDPOINT", "localhost:50055")
    metadata = Revoluchat.Grpc.Interceptors.AuthClient.get_auth_metadata()

    case GRPC.Stub.connect(chat_endpoint, adapter_opts: [connect_timeout: 1000]) do
      {:ok, channel} ->
        case Stub.get_global_chat_stats(channel, request, metadata: metadata) do
          {:ok, response} ->
            stats = %{
              total_messages: response.total_messages,
              total_conversations: response.total_conversations,
              total_connected_users: response.total_connected_users,
              message_volume_stats: Enum.map(response.message_volume_stats, fn stat ->
                %{date: stat.date, count: stat.count}
              end)
            }
            {:ok, stats}
          {:error, reason} ->
            Logger.error("[AdminClient] GetGlobalChatStats error: #{inspect(reason)}")
            {:error, reason}
        end
      {:error, reason} ->
        Logger.error("[AdminClient] Failed to connect to gRPC: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Add a new wallpaper.
  """
  def add_wallpaper(url) do
    request = %AddWallpaperRequest{url: url}
    chat_endpoint = System.get_env("CHAT_SERVICE_GRPC_ENDPOINT", "localhost:50055")
    metadata = Revoluchat.Grpc.Interceptors.AuthClient.get_auth_metadata()

    case GRPC.Stub.connect(chat_endpoint, adapter_opts: [connect_timeout: 1000]) do
      {:ok, channel} ->
        case Stub.add_wallpaper(channel, request, metadata: metadata) do
          {:ok, response} -> {:ok, response}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Delete a wallpaper by ID.
  """
  def delete_wallpaper(id) do
    request = %DeleteWallpaperRequest{id: id}
    chat_endpoint = System.get_env("CHAT_SERVICE_GRPC_ENDPOINT", "localhost:50055")
    metadata = Revoluchat.Grpc.Interceptors.AuthClient.get_auth_metadata()

    case GRPC.Stub.connect(chat_endpoint, adapter_opts: [connect_timeout: 1000]) do
      {:ok, channel} ->
        case Stub.delete_wallpaper(channel, request, metadata: metadata) do
          {:ok, response} -> {:ok, response}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get all wallpapers.
  """
  def get_wallpapers(active_only \\ false) do
    request = %GetWallpapersRequest{active_only: active_only}
    chat_endpoint = System.get_env("CHAT_SERVICE_GRPC_ENDPOINT", "localhost:50055")
    metadata = Revoluchat.Grpc.Interceptors.AuthClient.get_auth_metadata()

    case GRPC.Stub.connect(chat_endpoint, adapter_opts: [connect_timeout: 1000]) do
      {:ok, channel} ->
        case Stub.get_wallpapers(channel, request, metadata: metadata) do
          {:ok, response} -> {:ok, response.wallpapers}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Set an application preference via Go gRPC.
  """
  def set_app_preference(key, value) do
    request = %SetAppPreferenceRequest{
      key: key,
      value: value
    }

    metadata = Revoluchat.Grpc.Interceptors.AuthClient.get_auth_metadata()

    case GRPC.Stub.connect(endpoint(), adapter_opts: [connect_timeout: 1000]) do
      {:ok, channel} ->
        case Stub.set_app_preference(channel, request, metadata: metadata) do
          {:ok, response} ->
            {:ok, %{success: response.success, message: response.message}}
          {:error, reason} ->
            Logger.error("[AdminClient] SetAppPreference error: #{inspect(reason)}")
            {:error, reason}
        end
      {:error, reason} ->
        Logger.error("[AdminClient] Failed to connect to gRPC: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get multiple application preferences by keys via Go gRPC.
  """
  def get_app_preferences(keys) do
    request = %GetAppPreferencesRequest{
      keys: keys
    }

    metadata = Revoluchat.Grpc.Interceptors.AuthClient.get_auth_metadata()

    case GRPC.Stub.connect(endpoint(), adapter_opts: [connect_timeout: 1000]) do
      {:ok, channel} ->
        case Stub.get_app_preferences(channel, request, metadata: metadata) do
          {:ok, response} ->
            {:ok, response.preferences}
          {:error, reason} ->
            Logger.error("[AdminClient] GetAppPreferences error: #{inspect(reason)}")
            {:error, reason}
        end
      {:error, reason} ->
        Logger.error("[AdminClient] Failed to connect to gRPC: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
