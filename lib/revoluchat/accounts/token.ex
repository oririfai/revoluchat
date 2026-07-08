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

      {:error, :no_kid_in_token_header} ->
        require Logger
        Logger.warning("verify_access_token: Token missing kid. Attempting to verify with all available signers...")
        
        # Coba fallback manual tanpa mengecek kid (coba semua kunci publik yang ada)
        case fallback_verify_without_kid(token_string) do
          {:ok, %{"sub" => sub} = claims} ->
            user_id = parse_user_id(sub)
            app_id = Map.get(claims, "app_id")
            {:ok, %{user_id: user_id, app_id: app_id}}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, :no_signers_fetched} ->
        require Logger
        Logger.warning("verify_access_token: No signers fetched. Attempting synchronous refresh of JWKS keys...")
        
        # Synchronously refresh the signers in JwksStrategy
        Revoluchat.Accounts.JwksStrategy.refresh_signers()

        # Retry verification after refresh
        case verify_and_validate(token_string) do
          {:ok, %{"sub" => sub} = claims} ->
            user_id = parse_user_id(sub)
            app_id = Map.get(claims, "app_id")
            {:ok, %{user_id: user_id, app_id: app_id}}

          {:error, reason} ->
            Logger.error("verify_access_token: Retry failed after refresh. Reason: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ─── Private ─────────────────────────────────────────────────────────────────

  # user_id bisa datang sebagai float64 (JSON number) atau string dari sistem tenant
  defp parse_user_id(sub) when is_float(sub), do: trunc(sub) |> to_string()
  defp parse_user_id(sub) when is_integer(sub), do: to_string(sub)
  defp parse_user_id(sub) when is_binary(sub), do: sub

  defp fallback_verify_without_kid(token_string) do
    case Revoluchat.Accounts.JwksStrategy.list_signers() do
      {:ok, signers} when is_map(signers) and map_size(signers) > 0 ->
        # Coba verifikasi token dengan setiap public key (signer) yang ada
        Enum.reduce_while(Map.values(signers), {:error, :signature_error}, fn signer, _acc ->
          case Revoluchat.Accounts.Token.Fallback.verify_and_validate(token_string, signer) do
            {:ok, claims} -> {:halt, {:ok, claims}}
            {:error, reason} -> {:cont, {:error, reason}}
          end
        end)

      _ ->
        {:error, :no_signers_fetched}
    end
  end
end

defmodule Revoluchat.Accounts.Token.Fallback do
  @moduledoc false
  use Joken.Config

  @impl true
  def token_config do
    # Konfigurasi sama dengan modul utama, tapi tanpa hook JokenJwks
    default_claims(skip: [:aud, :iss])
  end
end
