defmodule Revoluchat.Accounts.AdminLoginActivity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "admin_login_activities" do
    belongs_to :admin, Revoluchat.Accounts.Admin
    field :email, :string
    field :ip_address, :string
    field :user_agent, :string
    field :device_os, :string
    field :device_browser, :string
    field :status, :string # "success" | "failed"

    timestamps(type: :utc_datetime)
  end

  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:admin_id, :email, :ip_address, :user_agent, :device_os, :device_browser, :status])
    |> validate_required([:ip_address, :user_agent, :device_os, :device_browser, :status])
  end
end
