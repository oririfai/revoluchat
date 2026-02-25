defmodule RevoluchatWeb.Plugs.LicensePlug do
  @moduledoc """
  Circuit Breaker untuk REST API: Menolak semua request jika License SDK
  sudah kedaluwarsa atau tidak valid.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Revoluchat.Licensing.Core

  def init(opts), do: opts

  def call(conn, _opts) do
    if Core.is_valid?() do
      conn
    else
      conn
      |> put_status(:payment_required)
      |> json(%{
        error: "license_invalid",
        message: "Your Revoluchat Enterprise SDK License is expired or invalid."
      })
      |> halt()
    end
  end
end
