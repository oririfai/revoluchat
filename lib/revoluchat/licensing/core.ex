defmodule Revoluchat.Licensing.Core do
  @moduledoc """
  Core Context for License Control in the Enterprise SDK.
  Provides cached reads and validation logic to intercept connections.
  """

  import Ecto.Query
  alias Revoluchat.Repo
  alias Revoluchat.Licensing.License
  require Logger

  @doc """
  Checks if the platform currently has a valid, active license.
  Returns boolean. Used heavily by Plugs and Channels as a Circuit Breaker.
  """
  def is_valid? do
    case get_active_license() do
      nil ->
        Logger.warning("License Circuit Breaker: No active license found.")
        false

      %License{status: "active", valid_until: valid_until} ->
        if DateTime.compare(valid_until, DateTime.utc_now()) == :gt do
          true
        else
          Logger.warning("License Circuit Breaker: License has expired at #{valid_until}.")
          false
        end

      %License{status: status} ->
        Logger.warning("License Circuit Breaker: License status is '#{status}'.")
        false
    end
  end

  @doc """
  Fetches the latest active license from the DB.
  """
  def get_active_license do
    # Usually there is only 1 license active per enterprise instance
    from(l in License, order_by: [desc: l.inserted_at], limit: 1)
    |> Repo.one()
  end

  @doc """
  Upserts a new license raw string into the DB after verification.
  """
  def apply_license(raw_jwt) do
    # In a real environment, we'd verify the JWT signed by central server via RSA/Ed25519 here.
    # For now, we simulate decoding and extracting claims.
    # We assume 'exp' is provided within the claims.

    # Mock extraction (replace with Joken verify in prod)
    case extract_mock_claims(raw_jwt) do
      {:ok, claims} ->
        exp_datetime = DateTime.from_unix!(claims["exp"])

        attrs = %{
          license_key: claims["jti"] || Ecto.UUID.generate(),
          status: "active",
          valid_until: exp_datetime,
          features: claims["features"] || %{},
          raw_jwt: raw_jwt
        }

        # Clear old active licenses
        Repo.update_all(License, set: [status: "expired"])

        %License{}
        |> License.changeset(attrs)
        |> Repo.insert()

      error ->
        error
    end
  end

  def revoke_license do
    from(l in License, where: l.status == "active")
    |> Repo.update_all(set: [status: "revoked"])
  end

  # --- Mock Validator ---
  defp extract_mock_claims(jwt) do
    # Assuming standard JWT format without actually verifying signature for this MVP Phase
    try do
      parts = String.split(jwt, ".")

      if length(parts) == 3 do
        claims_json = parts |> Enum.at(1) |> Base.decode64!(padding: false)
        claims = Jason.decode!(claims_json)

        if Map.has_key?(claims, "exp") do
          {:ok, claims}
        else
          {:error, "Missing 'exp' claim"}
        end
      else
        {:error, "Invalid JWT format"}
      end
    rescue
      _ -> {:error, "Malformed License JWT"}
    end
  end
end
