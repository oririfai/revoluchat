defmodule RevoluchatWeb.CallController do
  use RevoluchatWeb, :controller

  alias Revoluchat.Calls

  def history(conn, params) do
    user_id = conn.assigns.current_user_id
    app_id = conn.assigns.current_app_id
    
    # Ensure user_id is an integer
    user_id_int = if is_binary(user_id), do: String.to_integer(user_id), else: user_id
    
    # Support optional filtering by contact_id (for Detail View timeline)
    other_party_id = params["contact_id"]
    
    opts = if other_party_id, do: [other_party_id: other_party_id], else: []

    # Fetch history using the context function
    history = Calls.list_call_history(app_id, user_id_int, opts)

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

  def delete_history(conn, params) do
    user_id = conn.assigns.current_user_id
    app_id = conn.assigns.current_app_id
    
    # Accept ids from either Body (JSON) or Query Parameters
    ids = params["ids"] || []
    
    # Ensure user_id is an integer for the query
    user_id_int = if is_binary(user_id), do: String.to_integer(user_id), else: user_id

    require Logger
    Logger.debug("Deleting call history for user #{user_id_int} (App: #{app_id}). IDs: #{inspect(ids)}")

    {count, _} = Calls.delete_call_history(app_id, user_id_int, ids)

    Logger.debug("Deleted #{count} records.")

    json(conn, %{data: %{status: "ok", deleted_count: count}})
  end
end
