defmodule RevoluchatWeb.StatusController do
  use RevoluchatWeb, :controller

  alias Revoluchat.Chat.Adapters.Grpc, as: ChatAdapter
  require Logger

  action_fallback RevoluchatWeb.FallbackController

  def create(conn, params) do
    user_id = conn.assigns[:current_user_id] || conn.assigns[:current_numeric_user_id]
    app_id = conn.assigns[:current_app_id]

    attrs = %{
      app_id: app_id,
      user_id: user_id,
      type: params["type"] || "text",
      content: params["content"],
      attachment_id: params["attachment_id"],
      background_color: params["background_color"],
      font_style: params["font_style"],
      ttl_seconds: params["ttl_seconds"]
    }

    with {:ok, status} <- ChatAdapter.create_status(attrs) do
      # Broadcast event via Endpoint
      RevoluchatWeb.Endpoint.broadcast!(
        "user:#{user_id}",
        "status_created",
        %{status: status}
      )
      
      # Also broadcast to app wide or contacts? Usually status is seen by contacts.
      # If we have a contact system, we broadcast to contacts, but currently Revoluchat
      # relies on client side polling or specific subscriptions. Let's broadcast to a global
      # or contact specific topic if available. For now `user:#{user_id}` is fine.

      conn
      |> put_status(:created)
      |> json(%{success: true, data: status})
    end
  end

  def index(conn, params) do
    requestor_id = conn.assigns[:current_user_id] || to_string(conn.assigns[:current_numeric_user_id] || "")
    app_id = conn.assigns[:current_app_id]
    contact_ids = params["contact_ids"] || []

    statuses = ChatAdapter.list_statuses(app_id, requestor_id, contact_ids)
    formatted = Enum.map(statuses, &format_status/1)
    
    conn
    |> put_status(:ok)
    |> json(%{success: true, data: formatted})
  end

  def view(conn, %{"id" => status_id}) do
    viewer_id = conn.assigns[:current_user_id] || to_string(conn.assigns[:current_numeric_user_id] || "")
    app_id = conn.assigns[:current_app_id]

    Logger.info("[StatusController] Marking status #{status_id} viewed by viewer_id=#{inspect(viewer_id)} app_id=#{inspect(app_id)}")

    case ChatAdapter.view_status(app_id, status_id, viewer_id) do
      {:ok, _} ->
        conn |> put_status(:ok) |> json(%{success: true})
      {:error, reason} ->
        Logger.error("[StatusController] view_status failed: #{inspect(reason)}")
        conn |> put_status(:bad_request) |> json(%{success: false, error: inspect(reason)})
    end
  end

  defp format_status(s) do
    raw_views = Map.get(s, :views) || Map.get(s, "views") || []

    views =
      if is_list(raw_views) do
        Enum.map(raw_views, fn v ->
          viewer_id = Map.get(v, :viewer_id) || Map.get(v, "viewer_id") || Map.get(v, "viewerId") || ""
          viewed_at = Map.get(v, :viewed_at) || Map.get(v, "viewed_at") || Map.get(v, "viewedAt") || ""
          %{
            viewer_id: to_string(viewer_id),
            viewed_at: to_string(viewed_at)
          }
        end)
      else
        []
      end

    %{
      id: to_string(Map.get(s, :id) || Map.get(s, "id") || ""),
      app_id: to_string(Map.get(s, :app_id) || Map.get(s, "app_id") || ""),
      user_id: to_string(Map.get(s, :user_id) || Map.get(s, "user_id") || ""),
      type: to_string(Map.get(s, :type) || Map.get(s, "type") || "text"),
      content: to_string(Map.get(s, :content) || Map.get(s, "content") || ""),
      attachment_id: to_string(Map.get(s, :attachment_id) || Map.get(s, "attachment_id") || ""),
      background_color: to_string(Map.get(s, :background_color) || Map.get(s, "background_color") || ""),
      font_style: to_string(Map.get(s, :font_style) || Map.get(s, "font_style") || ""),
      expires_at: to_string(Map.get(s, :expires_at) || Map.get(s, "expires_at") || ""),
      created_at: to_string(Map.get(s, :created_at) || Map.get(s, "created_at") || ""),
      views: views
    }
  end

  def delete(conn, %{"id" => status_id}) do
    user_id = conn.assigns[:current_user_id] || conn.assigns[:current_numeric_user_id]
    app_id = conn.assigns[:current_app_id]

    case ChatAdapter.delete_status(app_id, status_id, user_id) do
      {:ok, _} ->
        RevoluchatWeb.Endpoint.broadcast(
          "user:#{user_id}",
          "status_deleted",
          %{status_id: status_id, user_id: user_id}
        )

        conn |> put_status(:ok) |> json(%{success: true})
      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{success: false, error: inspect(reason)})
    end
  end
end
