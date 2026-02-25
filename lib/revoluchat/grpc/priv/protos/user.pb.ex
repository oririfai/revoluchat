defmodule User.V1.GetUserRequest do
  @moduledoc false

  use Protobuf,
    full_name: "user.v1.GetUserRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :id, 1, type: :uint64
end

defmodule User.V1.GetUserResponse do
  @moduledoc false

  use Protobuf,
    full_name: "user.v1.GetUserResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :id, 1, type: :uint64
  field :uuid, 2, type: :string
  field :name, 3, type: :string
  field :phone, 4, type: :string
  field :status, 5, type: :string
  field :is_kyc, 6, type: :bool, json_name: "isKyc"
  field :avatar_url, 7, type: :string, json_name: "avatarUrl"
end

defmodule User.V1.UserService.Service do
  @moduledoc false

  use GRPC.Service, name: "user.v1.UserService", protoc_gen_elixir_version: "0.16.0"

  rpc :GetUser, User.V1.GetUserRequest, User.V1.GetUserResponse
end

defmodule User.V1.UserService.Stub do
  @moduledoc false

  use GRPC.Stub, service: User.V1.UserService.Service
end
