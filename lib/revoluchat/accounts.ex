defmodule Revoluchat.Accounts do
  @moduledoc """
  Context untuk autentikasi — microservice mode.
  Revoluchat TIDAK menerbitkan token. Hanya verifikasi JWT dari user service
  dan cek user exist via gRPC call ke User Service.
  """

  alias Revoluchat.Accounts.{User, Token}
  alias Revoluchat.Grpc.UserClient

  # ─── Token Verification ───────────────────────────────────────────────────────

  @doc """
  Verifikasi JWT RS256 dari user service.
  Returns {:ok, user_id} dimana user_id adalah integer.
  """
  def verify_token(token_string) do
    Token.verify_access_token(token_string)
  end

  # ─── User Verification ────────────────────────────────────────────────────────

  @doc """
  Cek apakah user terdaftar dan aktif via gRPC ke User Service.
  Returns {:ok, user} atau {:error, :user_not_found}.
  """
  def verify_user_exists(user_id) do
    case UserClient.get_user(user_id) do
      {:ok, user} ->
        {:ok, user}

      {:error, :not_found} ->
        {:error, :user_not_found}

      {:error, _reason} ->
        {:error, :user_not_found}
    end
  end

  @doc """
  Ambil data user via gRPC dari User Service.
  """
  def get_user(user_id) do
    UserClient.get_user(user_id)
  end
end
