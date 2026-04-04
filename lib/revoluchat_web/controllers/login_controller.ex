defmodule RevoluchatWeb.LoginController do
  use RevoluchatWeb, :controller

  def index(conn, _params) do
    conn
    |> put_layout(html: {RevoluchatWeb.Layouts, :auth})
    |> render(:index, page_title: "Admin Login", error_message: nil)
  end
end
