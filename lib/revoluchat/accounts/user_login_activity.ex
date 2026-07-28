defmodule Revoluchat.Accounts.UserLoginActivity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_login_activities" do
    field :user_id, :string
    field :name, :string
    field :phone, :string
    field :ip_address, :string
    field :user_agent, :string
    field :device_os, :string
    field :device_browser, :string
    field :status, :string, default: "success"

    timestamps(type: :utc_datetime)
  end

  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:user_id, :name, :phone, :ip_address, :user_agent, :device_os, :device_browser, :status])
    |> validate_required([:user_id, :ip_address, :user_agent, :device_os, :device_browser, :status])
  end
end
