defmodule RevoluchatWeb.CallController do
  use RevoluchatWeb, :controller

  alias Revoluchat.Calls

  def history(conn, _params) do
    user_id = conn.assigns.current_user_id
    app_id = conn.assigns.current_app_id

    # Fetch history using the context function
    history = Calls.list_call_history(app_id, user_id)

    # Format the response
    data = Enum.map(history, fn rec ->
      %{
        id: rec.id,
        direction: rec.direction,
        type: rec.type,
        status: rec.status,
        duration_seconds: rec.duration_seconds,
        started_at: rec.started_at,
        inserted_at: rec.inserted_at,
        conversation_id: rec.conversation_id,
        other_party: %{
          id: rec.other_party_id,
          name: rec.other_party_name,
          avatar_url: rec.other_party_avatar,
          phone: rec.other_party_phone
        }
      }
    end)

    json(conn, %{data: data})
  end
end
