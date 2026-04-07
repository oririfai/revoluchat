defmodule Revoluchat.Calls.CallHistory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "call_histories" do
    field(:app_id, :string)
    field(:user_id, :integer)
    field(:other_party_id, :integer)
    # "incoming", "outgoing"
    field(:direction, :string)
    # "audio", "video"
    field(:type, :string)
    # "missed", "rejected", "completed"
    field(:status, :string)
    field(:duration_seconds, :integer, default: 0)
    field(:started_at, :utc_datetime)

    belongs_to(:conversation, Revoluchat.Chat.Conversation)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(call_history, attrs) do
    call_history
    |> cast(attrs, [
      :app_id,
      :user_id,
      :other_party_id,
      :direction,
      :type,
      :status,
      :duration_seconds,
      :started_at,
      :conversation_id
    ])
    |> validate_required([
      :app_id,
      :user_id,
      :other_party_id,
      :direction,
      :type,
      :status,
      :started_at,
      :conversation_id
    ])
    |> validate_inclusion(:direction, ["incoming", "outgoing"])
    |> validate_inclusion(:type, ["audio", "video"])
    |> validate_inclusion(:status, ["missed", "rejected", "completed"])
  end
end
