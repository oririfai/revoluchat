defmodule Revoluchat.E2EE.Device do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "e2ee_devices" do
    field :app_id, :string
    field :user_id, :string
    field :device_id, :string
    field :registration_id, :integer
    field :identity_key_public, :string

    has_many :signed_pre_keys, Revoluchat.E2EE.SignedPreKey, foreign_key: :device_uuid
    has_many :one_time_pre_keys, Revoluchat.E2EE.OneTimePreKey, foreign_key: :device_uuid

    timestamps(type: :utc_datetime)
  end

  def changeset(device, attrs) do
    device
    |> cast(attrs, [:app_id, :user_id, :device_id, :registration_id, :identity_key_public])
    |> validate_required([:app_id, :user_id, :device_id, :registration_id, :identity_key_public])
    |> unique_constraint([:app_id, :user_id, :device_id])
  end
end
