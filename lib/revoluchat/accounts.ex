defmodule Revoluchat.Accounts do
  @moduledoc """
  Context untuk autentikasi — microservice mode.
  Revoluchat TIDAK menerbitkan token. Hanya verifikasi JWT dari user service
  dan cek user exist di MySQL user service DB.
  """

  alias Revoluchat.Accounts.{User, Token}
  alias Revoluchat.UserRepo

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
  Cek apakah user terdaftar dan aktif di user service DB (MySQL).
  Returns {:ok, user} atau {:error, :user_not_found}.
  """
  def verify_user_exists(user_id) do
    case UserRepo.get(User, user_id) do
      nil ->
        {:error, :user_not_found}

      %{deleted_at: deleted_at} when not is_nil(deleted_at) ->
        {:error, :user_not_found}

      user ->
        {:ok, user}
    end
  end

  @doc """
  Ambil data user dari MySQL user service DB.
  """
  def get_user(user_id) do
    case UserRepo.get(User, user_id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end
end
