defmodule Revoluchat.Accounts.Admin do
  use Ecto.Schema
  import Ecto.Changeset

  schema "admins" do
    field(:email, :string)
    field(:password, :string, virtual: true)
    field(:password_hash, :string)
    field(:role, :string, default: "custom")
    field(:permissions, {:array, :string}, default: [])
    field(:created_by, :string, default: "System")

    timestamps(type: :utc_datetime)
  end

  def changeset(admin, attrs) do
    admin
    |> cast(attrs, [:email, :password, :role, :permissions, :created_by])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_length(:password, min: 6)
    |> validate_inclusion(:role, ["super_admin", "custom"])
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp put_password_hash(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password -> put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
    end
  end

  def verify_password(password, %__MODULE__{password_hash: hash}) do
    Bcrypt.verify_pass(password, hash)
  end

  def has_permission?(%__MODULE__{role: "super_admin"}, _permission), do: true
  def has_permission?(%__MODULE__{permissions: permissions}, permission) when is_list(permissions) do
    permission in permissions
  end
  def has_permission?(_admin, _permission), do: false
end
