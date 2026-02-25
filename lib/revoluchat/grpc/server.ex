defmodule Revoluchat.Grpc.Server do
  use GRPC.Server, service: Revoluchat.V1.ConversationService.Service

  alias Revoluchat.Chat
  alias Revoluchat.V1.{CreateConversationRequest, CreateConversationResponse}

  @doc """
  Create or get conversation via gRPC.
  """
  def create_conversation(
        %CreateConversationRequest{user_a_id: user_a, user_b_id: user_b},
        _stream
      ) do
    # Validasi input sederhana
    if user_a == 0 or user_b == 0 do
      raise GRPC.RPCError, status: :invalid_argument, message: "user_id cannot be 0"
    end

    # TODO: Extract from gRPC metadata in future updates
    app_id = "default_app"

    case Chat.get_or_create_conversation(app_id, user_a, user_b) do
      {:ok, conversation} ->
        # Cek apakah baru dibuat atau existing (berdasarkan inserted_at ~= updated_at)
        # Sederhananya kita return success saja, is_new logic bisa ditambahkan jika perlu
        is_new = conversation.inserted_at == conversation.updated_at

        response = %CreateConversationResponse{
          conversation_id: conversation.id,
          is_new: is_new
        }

        {:ok, response}

      {:error, _reason} ->
        raise GRPC.RPCError, status: :internal, message: "Failed to create conversation"
    end
  end
end
