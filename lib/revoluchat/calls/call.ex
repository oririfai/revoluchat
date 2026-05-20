defmodule Revoluchat.Calls.Call do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "calls" do
    field(:app_id, :string)
    field(:caller_id, :string)
    field(:receiver_id, :string)
    # "audio", "video"
    field(:type, :string)
    # "dialing", "ringing", "connected", "missed", "rejected", "completed"
    field(:status, :string)
    field(:started_at, :utc_datetime)
    field(:ended_at, :utc_datetime)
    field(:duration_seconds, :integer)
    field(:group_id, :string)

    belongs_to(:conversation, Revoluchat.Chat.Conversation)

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(call, attrs) do
    call
    |> cast(attrs, [
      :app_id,
      :conversation_id,
      :caller_id,
      :receiver_id,
      :type,
      :status,
      :started_at,
      :ended_at,
      :duration_seconds,
      :group_id
    ])
    |> validate_required([:app_id, :caller_id, :type, :status])
    |> validate_inclusion(:type, ["audio", "video"])
    |> validate_inclusion(:status, [
      "dialing",
      "ringing",
      "connected",
      "missed",
      "rejected",
      "completed"
    ])
  end
end
