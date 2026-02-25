defmodule Revoluchat.Accounts.User do
  @moduledoc """
  Read-only schema untuk tabel users di MySQL user service.
  Tidak ada migration — tabel ini dikelola oleh user service.
  Hanya dipakai untuk verifikasi user exist.
  """

  use Ecto.Schema

  # Primary key integer (uint dari Go/GORM)
  @primary_key {:id, :integer, autogenerate: false}

  # Tidak ada foreign_key_type karena ini read-only, tidak ada relasi ke sini

  schema "users" do
    field :uuid, :string
    field :name, :string
    field :phone, :string
    field :status, :string
    field :is_kyc, :boolean, source: :is_kyc
    field :fcm, :string
  end
end
