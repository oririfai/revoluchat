defmodule RevoluchatWeb.AdminAuth do
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:default, _params, session, socket) do
    if admin_id = session["admin_id"] do
      case Revoluchat.Accounts.get_admin(admin_id) do
        nil ->
          {:halt, redirect(socket, to: "/admin/login")}
        admin ->
          {:cont, assign(socket, :current_admin, admin)}
      end
    else
      {:halt, redirect(socket, to: "/admin/login")}
    end
  end
end
