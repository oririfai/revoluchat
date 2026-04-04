defmodule RevoluchatWeb.UserChannel do
  use Phoenix.Channel
  require Logger

  def join("user:" <> user_id, _params, socket) do
    # Security check: User can only join their own topic
    authorized_user_id = to_string(socket.assigns.user_id)
    
    if user_id == authorized_user_id do
      Logger.info("UserChannel: User #{user_id} joined their private channel")
      {:ok, socket}
    else
      Logger.warning("UserChannel: User #{authorized_user_id} attempted to join private channel of user #{user_id}")
      {:error, %{reason: "unauthorized"}}
    end
  end
end
