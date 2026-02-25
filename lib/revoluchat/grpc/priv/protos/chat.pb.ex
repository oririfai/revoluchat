defmodule Revoluchat.V1.CreateConversationRequest do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.CreateConversationRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :user_a_id, 1, type: :uint64, json_name: "userAId"
  field :user_b_id, 2, type: :uint64, json_name: "userBId"
end

defmodule Revoluchat.V1.CreateConversationResponse do
  @moduledoc false

  use Protobuf,
    full_name: "revoluchat.v1.CreateConversationResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field :conversation_id, 1, type: :string, json_name: "conversationId"
  field :is_new, 2, type: :bool, json_name: "isNew"
end

defmodule Revoluchat.V1.ConversationService.Service do
  @moduledoc false

  use GRPC.Service, name: "revoluchat.v1.ConversationService", protoc_gen_elixir_version: "0.16.0"

  rpc(
    :CreateConversation,
    Revoluchat.V1.CreateConversationRequest,
    Revoluchat.V1.CreateConversationResponse
  )
end

defmodule Revoluchat.V1.ConversationService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Revoluchat.V1.ConversationService.Service
end
