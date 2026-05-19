defmodule User.V1.GetUserRequest do
  @moduledoc false

  use Protobuf,
    full_name: "user.v1.GetUserRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :id, 1, type: :string
  field :app_id, 2, type: :string, json_name: "appId"
end

defmodule User.V1.GetUserResponse do
  @moduledoc false

  use Protobuf,
    full_name: "user.v1.GetUserResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :id, 1, type: :string
  field :uuid, 2, type: :string
  field :name, 3, type: :string
  field :phone, 4, type: :string
  field :status, 5, type: :string
  field :is_kyc, 6, type: :bool, json_name: "isKyc"
  field :avatar_url, 7, type: :string, json_name: "avatarUrl"
end

defmodule User.V1.SearchUserByPhoneRequest do
  @moduledoc false

  use Protobuf,
    full_name: "user.v1.SearchUserByPhoneRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :phone, 2, type: :string
end

defmodule User.V1.UserResponse do
  @moduledoc false

  use Protobuf,
    full_name: "user.v1.UserResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :id, 1, type: :string
  field :phone_number, 2, type: :string, json_name: "phoneNumber"
  field :full_name, 3, type: :string, json_name: "fullName"
  field :profile_photo, 4, type: :string, json_name: "profilePhoto"
  field :description, 5, type: :string
  field :birth_date, 6, type: :string, json_name: "birthDate"
  field :is_active, 7, type: :bool, json_name: "isActive"
end

defmodule User.V1.AddContactRequest do
  @moduledoc false

  use Protobuf,
    full_name: "user.v1.AddContactRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :owner_id, 2, type: :string, json_name: "ownerId"
  field :contact_id, 3, type: :string, json_name: "contactId"
end

defmodule User.V1.ListContactsRequest do
  @moduledoc false

  use Protobuf,
    full_name: "user.v1.ListContactsRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :user_id, 2, type: :string, json_name: "userId"
end

defmodule User.V1.ListContactsResponse do
  @moduledoc false

  use Protobuf,
    full_name: "user.v1.ListContactsResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :contacts, 1, repeated: true, type: User.V1.UserResponse
end

defmodule User.V1.RemoveContactRequest do
  @moduledoc false

  use Protobuf,
    full_name: "user.v1.RemoveContactRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :app_id, 1, type: :string, json_name: "appId"
  field :owner_id, 2, type: :string, json_name: "ownerId"
  field :contact_id, 3, type: :string, json_name: "contactId"
end

defmodule User.V1.ActionResponse do
  @moduledoc false

  use Protobuf,
    full_name: "user.v1.ActionResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :success, 1, type: :bool
  field :message, 2, type: :string
end

defmodule User.V1.UserService.Service do
  @moduledoc false

  use GRPC.Service, name: "user.v1.UserService", protoc_gen_elixir_version: "0.16.0"

  rpc :GetUser, User.V1.GetUserRequest, User.V1.GetUserResponse

  rpc :SearchUserByPhone, User.V1.SearchUserByPhoneRequest, User.V1.UserResponse

  rpc :AddContact, User.V1.AddContactRequest, User.V1.ActionResponse

  rpc :ListContacts, User.V1.ListContactsRequest, User.V1.ListContactsResponse

  rpc :RemoveContact, User.V1.RemoveContactRequest, User.V1.ActionResponse
end

defmodule User.V1.UserService.Stub do
  @moduledoc false

  use GRPC.Stub, service: User.V1.UserService.Service
end
