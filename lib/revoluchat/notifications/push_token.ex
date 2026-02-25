defmodule Revoluchat.Notifications.PushToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "push_tokens" do
    field :app_id, :string, default: "default_app"
    field :platform, :string
    field :token, :string
    field :user_id, :string

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(push_token, attrs) do
    push_token
    |> cast(attrs, [:app_id, :user_id, :platform, :token])
    |> validate_required([:app_id, :user_id, :platform, :token])
    |> validate_inclusion(:platform, ["fcm", "apns", "web", "ios", "android"])
    |> unique_constraint(:token)
  end
end
