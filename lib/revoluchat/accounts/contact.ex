defmodule Revoluchat.Accounts.Contact do
  use Ecto.Schema
  import Ecto.Changeset

  schema "contacts" do
    field :owner_id, :integer
    field :contact_id, :integer
    field :app_id, :string
    field :status, :string, default: "added"

    timestamps()
  end

  @doc false
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:owner_id, :contact_id, :app_id, :status])
    |> validate_required([:owner_id, :contact_id, :app_id])
    |> unique_constraint([:owner_id, :contact_id, :app_id], name: :contacts_owner_id_contact_id_app_id_index)
  end
end
