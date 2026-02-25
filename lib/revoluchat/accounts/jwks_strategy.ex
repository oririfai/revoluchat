defmodule Revoluchat.Accounts.JwksStrategy do
  @moduledoc """
  Strategy untuk fetch JWKS ke endpoint server authentication punya client.
  """
  use JokenJwks.DefaultStrategyTemplate

  def init_opts(opts) do
    url = Application.get_env(:revoluchat, :jwks_url) || System.get_env("JWKS_URL")

    # Wajib ada URL, kalau tidak aplikasi akan error saat boot
    if is_nil(url) do
      raise """
      JWKS_URL tidak di-set di environment atau config.exs.
      Pastikan mengatur URL ke endpoint JWKS milik tenant.
      Contoh: JWKS_URL=https://auth.client-tenant.com/.well-known/jwks.json
      """
    end

    Keyword.merge(opts, jwks_url: url)
  end
end
