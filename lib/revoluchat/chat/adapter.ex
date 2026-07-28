defmodule Revoluchat.Chat.Adapter do
  @moduledoc """
  Behaviour for Chat storage adapters (Postgres or gRPC).
  """

  @callback get_or_create_conversation(String.t(), integer(), integer()) :: {:ok, any()} | {:error, any()}
  @callback get_conversation_for_user(String.t(), String.t(), integer()) :: {:ok, any()} | {:error, any()}
  @callback list_user_conversations(String.t(), integer(), keyword()) :: [any()]
  @callback get_conversation!(String.t(), String.t()) :: any()
  @callback delete_conversation(String.t(), [String.t()] | String.t(), integer()) :: :ok | {:error, any()}

  @callback insert_message(map()) :: {:ok, any(), [any()]} | {:error, any()}
  @callback list_messages(String.t(), String.t(), integer(), keyword()) :: [any()]
  @callback list_messages_by_ids(String.t(), [String.t()]) :: [any()]
  @callback get_message!(String.t()) :: any()
  @callback get_message_with_conversation!(String.t()) :: any()

  @callback mark_read(String.t(), String.t(), integer()) :: {:ok, any()} | {:error, any()}
  @callback mark_delivered(String.t(), String.t(), integer()) :: {:ok, any()} | {:error, any()}
  @callback soft_delete_message(String.t(), String.t(), integer()) :: {:ok, any()} | {:error, any()}
  @callback soft_delete_messages(String.t(), [String.t()], integer()) :: {:ok, integer()} | {:error, any()}

  @callback get_attachment!(String.t()) :: any()
  @callback create_attachment_init(map()) :: {:ok, any(), map()} | {:error, any()}
  @callback confirm_attachment(String.t(), String.t(), integer()) :: {:ok, any()} | {:error, any()}
  @callback get_attachment_download_url(String.t(), String.t(), integer()) :: {:ok, String.t()} | {:error, any()}
  @callback list_attachments_by_ids(String.t(), [String.t()]) :: [any()]

  @callback count_messages_for_app(String.t()) :: integer()
  @callback count_active_conversations(String.t()) :: integer()

  # --- GROUPS (ADVANCE TIER) ---
  @callback create_group(binary(), map()) :: {:ok, any()} | {:error, any()}
  @callback get_group(binary(), binary()) :: {:ok, any()} | {:error, any()}
  @callback add_members(binary(), binary(), [integer()], binary()) :: {:ok, any()} | {:error, any()}
  @callback remove_member(String.t(), String.t(), integer()) :: {:ok, any()} | {:error, any()}
  @callback update_group(String.t(), String.t(), map()) :: {:ok, any()} | {:error, any()}
  @callback leave_group(String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  @callback delete_group(String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  @callback mute_group(String.t(), String.t(), boolean()) :: {:ok, any()} | {:error, any()}
end
