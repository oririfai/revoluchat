defmodule Revoluchat.Accounts.ServerKey do
  use Ecto.Schema
  import Ecto.Changeset

  schema "server_keys" do
    field :name, :string
    field :key, :string
    field :status, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(server_key, attrs) do
    server_key
    |> cast(attrs, [:name, :status])
    |> put_new_key()
    |> validate_required([:name, :key, :status])
    |> unique_constraint(:key)
  end

  defp put_new_key(changeset) do
    case get_field(changeset, :key) do
      nil -> put_change(changeset, :key, generate_key())
      _key -> changeset
    end
  end

  @doc """
  Generate a secure random string for Server Key.
  """
  def generate_key do
    :crypto.strong_rand_bytes(48) |> Base.url_encode64(padding: false)
  end
end
