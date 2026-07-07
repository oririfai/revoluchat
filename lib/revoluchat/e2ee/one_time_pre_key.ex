defmodule Revoluchat.E2EE.OneTimePreKey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "e2ee_one_time_pre_keys" do
    field :app_id, :string
    field :key_id, :integer
    field :public_key, :string

    belongs_to :device, Revoluchat.E2EE.Device, foreign_key: :device_uuid

    timestamps(type: :utc_datetime)
  end

  def changeset(one_time_pre_key, attrs) do
    one_time_pre_key
    |> cast(attrs, [:app_id, :device_uuid, :key_id, :public_key])
    |> validate_required([:app_id, :device_uuid, :key_id, :public_key])
    |> unique_constraint([:app_id, :device_uuid, :key_id])
  end
end
