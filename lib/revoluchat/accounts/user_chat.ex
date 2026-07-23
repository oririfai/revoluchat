defmodule Revoluchat.Accounts.UserChat do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_chats" do
    field :user_id, :string
    field :chat_id, Ecto.UUID
    field :app_id, :string
    field :name, :string
    field :phone, :string
    field :avatar_url, :string
    field :is_active, :boolean, default: true
    field :suspended_until, :utc_datetime
    field :description, :string
    field :birth_date, :date
    field :last_seen_at, :utc_datetime
    field :privacy_settings, :map, virtual: true

    timestamps()
  end

  @doc false
  def changeset(user_chat, attrs) do
    user_chat
    |> cast(attrs, [:user_id, :chat_id, :app_id, :name, :phone, :avatar_url, :is_active, :suspended_until, :description, :birth_date, :last_seen_at])
    |> validate_required([:user_id, :chat_id, :app_id])
    |> unique_constraint([:user_id, :app_id], name: :user_id_app_id_unique)
  end
end
