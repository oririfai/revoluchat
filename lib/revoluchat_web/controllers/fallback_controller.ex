defmodule RevoluchatWeb.FallbackController do
  @moduledoc """
  Controller fallback terpusat untuk error handling.
  Semua controller yang pakai `action_fallback` akan routing error ke sini.
  """

  use RevoluchatWeb, :controller

  # Ecto changeset errors
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    errors = format_changeset_errors(changeset)

    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_failed", errors: errors})
  end

  # Not found
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "not_found"})
  end

  # Auth errors
  def call(conn, {:error, :invalid_credentials}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "invalid_credentials", message: "Email atau password salah"})
  end

  def call(conn, {:error, :invalid_token}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "invalid_token"})
  end

  def call(conn, {:error, :token_revoked}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "token_revoked", message: "Token sudah direvoke, silakan login ulang"})
  end

  def call(conn, {:error, :token_expired}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "token_expired"})
  end

  # Authorization
  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "forbidden"})
  end

  # gRPC errors
  def call(conn, {:error, %GRPC.RPCError{status: 2, message: "no rows in result set"}}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "not_found", message: "Data tidak ditemukan di backend Go"})
  end

  def call(conn, {:error, %GRPC.RPCError{} = error}) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{error: "grpc_error", message: error.message})
  end

  # Generic
  def call(conn, {:error, reason}) when is_atom(reason) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: to_string(reason)})
  end

  def call(conn, {:error, message}) when is_binary(message) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: message})
  end

  # ─── Private ─────────────────────────────────────────────────────────────────

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts
        |> Keyword.get(String.to_existing_atom(key), key)
        |> to_string()
      end)
    end)
  end
end
