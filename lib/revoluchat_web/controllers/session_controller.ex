defmodule RevoluchatWeb.SessionController do
  use RevoluchatWeb, :controller

  alias Revoluchat.Accounts.Admin
  alias Revoluchat.Repo

  def create(conn, %{"auth" => %{"email" => email, "password" => password}}) do
    admin = Repo.get_by(Admin, email: email)

    if admin && Admin.verify_password(password, admin) do
      conn
      |> put_session(:admin_id, admin.id)
      |> configure_session(renew: true)
      |> redirect(to: "/admin")
    else
      conn
      |> put_flash(:error, "Invalid email or password")
      |> redirect(to: "/admin/login")
    end
  end

  def delete(conn, _params) do
    conn
    |> clear_session()
    |> configure_session(drop: true)
    |> redirect(to: "/admin/login")
  end
end
