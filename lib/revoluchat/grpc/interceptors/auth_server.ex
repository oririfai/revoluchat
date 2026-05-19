defmodule Revoluchat.Grpc.Interceptors.AuthServer do
  @moduledoc """
  gRPC Server Interceptor to validate the incoming `x-server-key` metadata.
  """
  @behaviour GRPC.ServerInterceptor

  import Ecto.Query
  alias Revoluchat.Repo
  alias Revoluchat.Accounts.ServerKey
  require Logger

  @impl true
  def init(_opts), do: nil

  @impl true
  def call(request, stream, next, _opts) do
    metadata = GRPC.Stream.get_headers(stream)
    server_key = Map.get(metadata, "x-server-key")

    if authorized?(server_key) do
      next.(request, stream)
    else
      Logger.warning("[gRPC] Unauthorized access attempt with key: #{inspect(server_key)}")
      raise GRPC.RPCError, status: :unauthenticated, message: "Invalid or missing x-server-key"
    end
  end

  defp authorized?(nil), do: false

  defp authorized?(key) do
    # Validate against database
    Repo.exists?(from(sk in ServerKey, where: sk.key == ^key and sk.status == "active"))
  end
end
