defmodule RevoluchatWeb.AdminAuth do
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:default, _params, session, socket) do
    if admin_id = session["admin_id"] do
      {:cont, assign(socket, :current_admin_id, admin_id)}
    else
      {:halt, redirect(socket, to: "/admin/login")}
    end
  end
end
