defmodule Revoluchat.E2EE.SignedPreKey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "e2ee_signed_pre_keys" do
    field :app_id, :string
    field :key_id, :integer
    field :public_key, :string
    field :signature, :string

    belongs_to :device, Revoluchat.E2EE.Device, foreign_key: :device_uuid

    timestamps(type: :utc_datetime)
  end

  def changeset(signed_pre_key, attrs) do
    signed_pre_key
    |> cast(attrs, [:app_id, :device_uuid, :key_id, :public_key, :signature])
    |> validate_required([:app_id, :device_uuid, :key_id, :public_key, :signature])
    |> unique_constraint([:app_id, :device_uuid, :key_id])
  end
end
