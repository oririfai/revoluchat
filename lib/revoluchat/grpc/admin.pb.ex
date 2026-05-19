defmodule Admin.V1.ListUsersRequest do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.ListUsersRequest",
    protoc_gen_elixir_version: "0.16.0",
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
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :users, 1, repeated: true, type: Admin.V1.AdminUser
  field :total_count, 2, type: :int32, json_name: "totalCount"
  field :total_pages, 3, type: :int32, json_name: "totalPages"
end

defmodule Admin.V1.AdminUser do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.AdminUser",
    protoc_gen_elixir_version: "0.16.0",
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
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :user_id, 1, type: :string, json_name: "userId"
  field :duration, 2, type: :string
  field :reason, 3, type: :string
end

defmodule Admin.V1.UnsuspendUserRequest do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.UnsuspendUserRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :user_id, 1, type: :string, json_name: "userId"
end

defmodule Admin.V1.ActionResponse do
  @moduledoc false

  use Protobuf,
    full_name: "admin.v1.ActionResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :success, 1, type: :bool
  field :message, 2, type: :string
end

defmodule Admin.V1.AdminService.Service do
  @moduledoc false

  use GRPC.Service, name: "admin.v1.AdminService", protoc_gen_elixir_version: "0.16.0"

  rpc :ListUsers, Admin.V1.ListUsersRequest, Admin.V1.ListUsersResponse

  rpc :SuspendUser, Admin.V1.SuspendUserRequest, Admin.V1.ActionResponse

  rpc :UnsuspendUser, Admin.V1.UnsuspendUserRequest, Admin.V1.ActionResponse
end

defmodule Admin.V1.AdminService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Admin.V1.AdminService.Service
end
