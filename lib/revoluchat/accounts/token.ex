defmodule Revoluchat.Accounts.Token do
  @moduledoc """
  JWT verification menggunakan JWKS (JSON Web Key Set).
  Sangat cocok untuk arsitektur B2B / Enterprise di mana Chat SDK
  hanya memverifikasi token yang diterbitkan oleh sistem autentikasi tenant (Client).
  """

  use Joken.Config

  # Setup JWKS hook to dynamically fetch public keys
  add_hook(JokenJwks, strategy: Revoluchat.Accounts.JwksStrategy)

  @impl true
  def token_config do
    # Skip validasi :aud dan :iss karena JWT ini diterbitkan oleh
    # sistem eksternal (sistem Auth milik tenant/klien).
    default_claims(skip: [:aud, :iss])
  end

  @doc """
  Verifikasi JWT RS256 menggunakan JWKS dari user service/tenant.
  Returns {:ok, user_id} dimana user_id adalah string atau integer.
  """
  def verify_access_token(token_string) do
    # Karena JWKS hook sudah di setup, kita cukup call verify_and_validate
    # JWKS akan otomatis mencari key yang cocok (berdasarkan kid header)
    case verify_and_validate(token_string) do
      {:ok, %{"sub" => sub} = claims} ->
        user_id = parse_user_id(sub)
        app_id = Map.get(claims, "app_id")
        {:ok, %{user_id: user_id, app_id: app_id}}

      {:ok, _claims} ->
        {:error, :missing_sub_claim}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ─── Private ─────────────────────────────────────────────────────────────────

  # user_id bisa datang sebagai float64 (JSON number) atau string dari sistem tenant
  defp parse_user_id(sub) when is_float(sub), do: trunc(sub) |> to_string()
  defp parse_user_id(sub) when is_integer(sub), do: to_string(sub)
  defp parse_user_id(sub) when is_binary(sub), do: sub
end
