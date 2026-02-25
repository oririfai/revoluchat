defmodule Revoluchat.Licensing.License do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ["active", "expired", "revoked"]

  schema "licenses" do
    field :license_key, :string
    field :status, :string, default: "active"
    field :valid_until, :utc_datetime
    field :features, :map, default: %{}
    field :raw_jwt, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(license, attrs) do
    license
    |> cast(attrs, [:license_key, :status, :valid_until, :features, :raw_jwt])
    |> validate_required([:license_key, :status, :valid_until])
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint(:license_key)
  end
end
