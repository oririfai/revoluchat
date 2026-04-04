defmodule Revoluchat.Accounts.UserChat do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_chats" do
    field :user_id, :integer
    field :chat_id, Ecto.UUID
    field :app_id, :string
    field :name, :string
    field :phone, :string
    field :avatar_url, :string

    timestamps()
  end

  @doc false
  def changeset(user_chat, attrs) do
    user_chat
    |> cast(attrs, [:user_id, :chat_id, :app_id, :name, :phone, :avatar_url])
    |> validate_required([:user_id, :chat_id, :app_id])
    |> unique_constraint([:user_id, :app_id], name: :user_id_app_id_unique)
  end
end
