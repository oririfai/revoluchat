defmodule RevoluchatWeb.E2EEController do
  use RevoluchatWeb, :controller

  alias Revoluchat.E2EE

  action_fallback RevoluchatWeb.FallbackController

  def register(conn, %{
        "device_id" => device_id,
        "registration_id" => registration_id,
        "identity_key_public" => identity_key_public,
        "signed_pre_key" => signed_pre_key,
        "one_time_pre_keys" => one_time_pre_keys
      }) do
    
    app_id = conn.assigns[:current_app_id]
    user_id = conn.assigns[:current_numeric_user_id] || conn.assigns[:current_user_id]

    case E2EE.register_keys(app_id, user_id, device_id, registration_id, identity_key_public, signed_pre_key, one_time_pre_keys) do
      {:ok, _device} ->
        json(conn, %{success: true, message: "Keys registered successfully"})
      _error ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, error: "Failed to register keys"})
    end
  end

  def get_bundle(conn, %{"user_id" => target_user_id} = params) do
    app_id = conn.assigns[:current_app_id]
    device_id = params["device_id"] # Optional, fetch specific device

    case E2EE.get_pre_key_bundle(app_id, target_user_id, device_id) do
      {:ok, bundle} ->
        json(conn, %{success: true, bundle: bundle})
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: "PreKey Bundle not found for user"})
    end
  end

  def replenish(conn, %{
        "device_id" => device_id,
        "one_time_pre_keys" => one_time_pre_keys
      }) do
    
    app_id = conn.assigns[:current_app_id]
    user_id = conn.assigns[:current_numeric_user_id] || conn.assigns[:current_user_id]

    case E2EE.replenish_one_time_pre_keys(app_id, user_id, device_id, one_time_pre_keys) do
      {:ok, {:ok, count}} ->
        json(conn, %{success: true, message: "Added #{count} One-Time PreKeys"})
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, error: "Failed to replenish keys"})
    end
  end
end
