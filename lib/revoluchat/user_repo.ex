defmodule Revoluchat.UserRepo do
  @moduledoc """
  Read-only Ecto Repo untuk MySQL database user service.
  Hanya dipakai untuk verifikasi user exist — tidak ada write operation.
  """
  use Ecto.Repo,
    otp_app: :revoluchat,
    adapter: Ecto.Adapters.MyXQL
end
