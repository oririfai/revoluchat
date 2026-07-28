defmodule Admin.V1.ListUsersRequest do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.ListUsersRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :query, 1, type: :string
  field :page, 2, type: :int32
  field :limit, 3, type: :int32
  field :status_filter, 4, type: :string, json_name: "statusFilter"
end

defmodule Admin.V1.ListUsersResponse do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.ListUsersResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :users, 1, repeated: true, type: Admin.V1.AdminUser
  field :total_count, 2, type: :int32, json_name: "totalCount"
  field :total_pages, 3, type: :int32, json_name: "totalPages"
end

defmodule Admin.V1.AdminUser do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.AdminUser",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :id, 1, type: :string
  field :uuid, 2, type: :string
  field :name, 3, type: :string
  field :phone, 4, type: :string
  field :status, 5, type: :string
  field :inserted_at, 6, type: :string, json_name: "insertedAt"
  field :is_kyc, 7, type: :bool, json_name: "isKyc"
end

defmodule Admin.V1.SuspendUserRequest do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.SuspendUserRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :user_id, 1, type: :string, json_name: "userId"
  field :duration, 2, type: :string
  field :reason, 3, type: :string
end

defmodule Admin.V1.UnsuspendUserRequest do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.UnsuspendUserRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :user_id, 1, type: :string, json_name: "userId"
end

defmodule Admin.V1.ActionResponse do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.ActionResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :success, 1, type: :bool
  field :message, 2, type: :string
end

defmodule Admin.V1.GetGlobalChatStatsRequest do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.GetGlobalChatStatsRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3
end

defmodule Admin.V1.MessageVolumeStat do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.MessageVolumeStat",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :date, 1, type: :string
  field :count, 2, type: :int64
end

defmodule Admin.V1.GetGlobalChatStatsResponse do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.GetGlobalChatStatsResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :total_messages, 1, type: :int64, json_name: "totalMessages"
  field :total_conversations, 2, type: :int64, json_name: "totalConversations"

  field :message_volume_stats, 3,
    repeated: true,
    type: Admin.V1.MessageVolumeStat,
    json_name: "messageVolumeStats"

  field :total_connected_users, 4, type: :int64, json_name: "totalConnectedUsers"
end

defmodule Admin.V1.Wallpaper do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.Wallpaper",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :id, 1, type: :string
  field :url, 2, type: :string
  field :is_active, 3, type: :bool, json_name: "isActive"
  field :created_at, 4, type: :string, json_name: "createdAt"
end

defmodule Admin.V1.SetAppPreferenceRequest do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.SetAppPreferenceRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule Admin.V1.GetAppPreferencesRequest do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.GetAppPreferencesRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :keys, 1, repeated: true, type: :string
end

defmodule Admin.V1.GetAppPreferencesResponse.PreferencesEntry do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.GetAppPreferencesResponse.PreferencesEntry",
    map: true,
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule Admin.V1.GetAppPreferencesResponse do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.GetAppPreferencesResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :preferences, 1,
    repeated: true,
    type: Admin.V1.GetAppPreferencesResponse.PreferencesEntry,
    map: true
end

defmodule Admin.V1.AddWallpaperRequest do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.AddWallpaperRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :url, 1, type: :string
end

defmodule Admin.V1.DeleteWallpaperRequest do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.DeleteWallpaperRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :id, 1, type: :string
end

defmodule Admin.V1.GetWallpapersRequest do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.GetWallpapersRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :active_only, 1, type: :bool, json_name: "activeOnly"
end

defmodule Admin.V1.GetWallpapersResponse do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.GetWallpapersResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field :wallpapers, 1, repeated: true, type: Admin.V1.Wallpaper
end

defmodule Admin.V1.AdminService.Service do
  @moduledoc false

  use GRPC.Service, name: "admin.v1.AdminService", protoc_gen_elixir_version: "0.17.0"

  rpc :ListUsers, Admin.V1.ListUsersRequest, Admin.V1.ListUsersResponse

  rpc :SuspendUser, Admin.V1.SuspendUserRequest, Admin.V1.ActionResponse

  rpc :UnsuspendUser, Admin.V1.UnsuspendUserRequest, Admin.V1.ActionResponse

  rpc :GetGlobalChatStats, Admin.V1.GetGlobalChatStatsRequest, Admin.V1.GetGlobalChatStatsResponse

  rpc :AddWallpaper, Admin.V1.AddWallpaperRequest, Admin.V1.Wallpaper

  rpc :DeleteWallpaper, Admin.V1.DeleteWallpaperRequest, Admin.V1.ActionResponse

  rpc :GetWallpapers, Admin.V1.GetWallpapersRequest, Admin.V1.GetWallpapersResponse

  rpc :SetAppPreference, Admin.V1.SetAppPreferenceRequest, Admin.V1.ActionResponse

  rpc :GetAppPreferences, Admin.V1.GetAppPreferencesRequest, Admin.V1.GetAppPreferencesResponse
end

defmodule Admin.V1.AdminService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Admin.V1.AdminService.Service
end
