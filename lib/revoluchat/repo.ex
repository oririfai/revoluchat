defmodule Revoluchat.Repo do
  use Ecto.Repo,
    otp_app: :revoluchat,
    adapter: Ecto.Adapters.Postgres
end
