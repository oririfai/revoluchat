defmodule Revoluchat.Calls.Adapter do
  @moduledoc """
  Behaviour for Calls storage adapters.
  """

  @callback get_call(String.t(), String.t()) :: any()
  @callback is_participant?(String.t(), String.t(), integer()) :: boolean()
  @callback create_call(map()) :: {:ok, any()} | {:error, any()}
  @callback update_call(any(), map()) :: {:ok, any()} | {:error, any()}
  @callback initiate_call(String.t(), String.t() | nil, integer(), integer() | nil, String.t(), String.t() | nil) :: {:ok, any(), map()} | {:error, any()}
  
  @callback set_ringing(String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  @callback accept_call(String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  @callback reject_call(String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  @callback complete_call(String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  @callback cancel_call(String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  
  @callback list_call_history(String.t(), integer(), keyword()) :: [any()]
  @callback delete_call_history(String.t(), integer(), [String.t()]) :: {integer(), nil}
end
