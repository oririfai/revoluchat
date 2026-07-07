defmodule Revoluchat.E2EE do
  @moduledoc """
  The E2EE context for managing Public Key Infrastructure (PKI) required by the Signal Protocol.
  """

  import Ecto.Query, warn: false
  alias Revoluchat.Repo

  alias Revoluchat.E2EE.Device
  alias Revoluchat.E2EE.SignedPreKey
  alias Revoluchat.E2EE.OneTimePreKey

  def register_keys(app_id, user_id, device_id, registration_id, identity_key_public, signed_pre_key, one_time_pre_keys) do
    Repo.transaction(fn ->
      # Upsert Device
      device_attrs = %{
        "app_id" => app_id,
        "user_id" => user_id,
        "device_id" => device_id,
        "registration_id" => registration_id,
        "identity_key_public" => identity_key_public
      }

      device = 
        case Repo.get_by(Device, app_id: app_id, user_id: user_id, device_id: device_id) do
          nil -> %Device{}
          existing -> existing
        end
        |> Device.changeset(device_attrs)
        |> Repo.insert_or_update!()

      # Delete old signed pre keys for this device (or keep history if desired, but we overwrite for simplicity)
      Repo.delete_all(from s in SignedPreKey, where: s.device_uuid == ^device.id)
      
      # Insert new signed pre key
      %SignedPreKey{}
      |> SignedPreKey.changeset(%{
        "app_id" => app_id,
        "device_uuid" => device.id,
        "key_id" => signed_pre_key["key_id"],
        "public_key" => signed_pre_key["public_key"],
        "signature" => signed_pre_key["signature"]
      })
      |> Repo.insert!()

      # Delete old one time pre keys
      Repo.delete_all(from o in OneTimePreKey, where: o.device_uuid == ^device.id)

      # Insert new one time pre keys
      now = DateTime.truncate(DateTime.utc_now(), :second)
      otpk_entries = Enum.map(one_time_pre_keys, fn otpk ->
        %{
          id: Ecto.UUID.generate(),
          app_id: app_id,
          device_uuid: device.id,
          key_id: otpk["key_id"],
          public_key: otpk["public_key"],
          inserted_at: now,
          updated_at: now
        }
      end)

      Repo.insert_all(OneTimePreKey, otpk_entries)

      device
    end)
  end

  def get_pre_key_bundle(app_id, user_id, device_id \\ nil) do
    # If device_id is nil, just get the primary/first device for the user for now
    query = if device_id do
      from d in Device,
        where: d.app_id == ^app_id and d.user_id == ^user_id and d.device_id == ^device_id,
        preload: [:signed_pre_keys]
    else
      from d in Device,
        where: d.app_id == ^app_id and d.user_id == ^user_id,
        order_by: [desc: d.updated_at],
        limit: 1,
        preload: [:signed_pre_keys]
    end
      
    case Repo.one(query) do
      nil -> {:error, :not_found}
      device ->
        # Get one OTPK and delete it
        otpk = get_and_delete_one_time_pre_key(device.id)
        
        signed_pre_key = List.first(device.signed_pre_keys)
        
        bundle = %{
          identity_key: device.identity_key_public,
          registration_id: device.registration_id,
          signed_pre_key: if(signed_pre_key, do: %{
            key_id: signed_pre_key.key_id,
            public_key: signed_pre_key.public_key,
            signature: signed_pre_key.signature
          }, else: nil),
          pre_key: if(otpk, do: %{
            key_id: otpk.key_id,
            public_key: otpk.public_key
          }, else: nil)
        }
        
        {:ok, bundle}
    end
  end
  
  def replenish_one_time_pre_keys(app_id, user_id, device_id, one_time_pre_keys) do
    Repo.transaction(fn ->
      case Repo.get_by(Device, app_id: app_id, user_id: user_id, device_id: device_id) do
        nil -> Repo.rollback(:device_not_found)
        device ->
          now = DateTime.truncate(DateTime.utc_now(), :second)
          otpk_entries = Enum.map(one_time_pre_keys, fn otpk ->
            %{
              id: Ecto.UUID.generate(),
              app_id: app_id,
              device_uuid: device.id,
              key_id: otpk["key_id"],
              public_key: otpk["public_key"],
              inserted_at: now,
              updated_at: now
            }
          end)

          Repo.insert_all(OneTimePreKey, otpk_entries)
          {:ok, length(otpk_entries)}
      end
    end)
  end

  defp get_and_delete_one_time_pre_key(device_uuid) do
    Repo.transaction(fn ->
      query = from o in OneTimePreKey,
        where: o.device_uuid == ^device_uuid,
        limit: 1

      case Repo.one(query) do
        nil -> nil
        otpk ->
          Repo.delete!(otpk)
          otpk
      end
    end)
    |> case do
      {:ok, result} -> result
      _ -> nil
    end
  end
end
