defmodule Revoluchat.Accounts.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_keys" do
    field(:name, :string)
    field(:key, :string)
    field(:status, :string, default: "active")
    field(:app_id, :string, default: "default_app")

    timestamps()
  end

  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :key, :status, :app_id])
    |> validate_required([:name, :key, :status])
    |> ensure_app_id()
    |> unique_constraint(:key)
  end

  defp ensure_app_id(changeset) do
    if get_field(changeset, :app_id) == "default_app" or is_nil(get_field(changeset, :app_id)) do
      put_change(changeset, :app_id, generate_app_id())
    else
      changeset
    end
  end

  def generate_key do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64()
  end

  def generate_app_id do
    "app_" <> (:crypto.strong_rand_bytes(8) |> Base.url_encode64() |> String.slice(0..11))
  end
end
