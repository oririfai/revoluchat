defmodule RevoluchatWeb.ContactController do
  use RevoluchatWeb, :controller

  alias Revoluchat.Accounts

  @doc """
  List all registered contacts for the current user in the current app.
  """
  def index(conn, _params) do
    app_id = conn.assigns.current_app_id
    current_user_id = conn.assigns.current_user_id
    contacts = Accounts.list_registered_users(app_id, current_user_id)

    json(conn, %{contacts: contacts})
  end

  @doc """
  Add a contact by phone number.
  """
  def create(conn, %{"phone" => phone}) do
    app_id = conn.assigns.current_app_id
    current_user_id = conn.assigns.current_user_id

    case Accounts.add_contact_by_phone(app_id, current_user_id, phone) do
      {:ok, contact} ->
        # Fetch target user data to return to SDK
        user = Accounts.get_registered_user(app_id, contact.contact_id)
        
        conn
        |> put_status(:created)
        |> json(%{
          message: "Kontak berhasil ditambahkan",
          data: %{
            id: to_string(user.user_id),
            chat_id: user.chat_id,
            name: user.name || "User #{user.user_id}",
            phone: user.phone,
            avatar_url: user.avatar_url
          }
        })

      {:error, :user_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Nomor HP tidak terdaftar di chat"})

      {:error, :cannot_add_self} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "bad_request", message: "Tidak bisa menambahkan diri sendiri"})

      {:error, _reason} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "conflict", message: "Kontak sudah ada di daftar Anda"})
    end
  end

  @doc """
  Sync phone contacts and return registered users.
  Expects %{"phones" => ["0812...", "0813..."]}
  """
  def sync(conn, %{"phones" => phones}) when is_list(phones) do
    app_id = conn.assigns.current_app_id
    users = Accounts.sync_contacts(app_id, phones)

    json(conn, %{contacts: users})
  end

  def sync(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: "Parameter 'phones' harus berupa list"})
  end
end
