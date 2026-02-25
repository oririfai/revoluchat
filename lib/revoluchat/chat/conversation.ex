defmodule Revoluchat.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conversations" do
    field :last_activity_at, :utc_datetime_usec
    field :app_id, :string
    # user_id adalah integer (uint dari MySQL user service)
    field :user_a_id, :integer
    field :user_b_id, :integer

    belongs_to :user_a, Revoluchat.Accounts.User, foreign_key: :user_a_id, define_field: false
    belongs_to :user_b, Revoluchat.Accounts.User, foreign_key: :user_b_id, define_field: false

    belongs_to :last_message, Revoluchat.Chat.Message
    has_many :messages, Revoluchat.Chat.Message

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:app_id, :user_a_id, :user_b_id])
    |> validate_required([:app_id, :user_a_id, :user_b_id])
    |> validate_number(:user_a_id, greater_than: 0)
    |> validate_number(:user_b_id, greater_than: 0)
    |> validate_different_users()
    |> unique_constraint([:user_a_id, :user_b_id],
      message: "conversation sudah ada"
    )
  end

  def activity_changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:last_message_id, :last_activity_at])
  end

  defp validate_different_users(changeset) do
    a = get_field(changeset, :user_a_id)
    b = get_field(changeset, :user_b_id)

    if a && b && a == b do
      add_error(changeset, :user_b_id, "tidak bisa conversation dengan diri sendiri")
    else
      changeset
    end
  end
end
