defmodule Revoluchat.Release do
  @moduledoc """
  Helper module untuk administrasi release (migration, rollback).
  """
  @app :revoluchat

  def migrate do
    load_app()

    # Migrasi Repo utama (Postgres)

    repo = Revoluchat.Repo

    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
  end

  def rollback(version) do
    load_app()
    repo = Revoluchat.Repo
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    load_app()

    repo = Revoluchat.Repo

    Ecto.Migrator.with_repo(repo, fn _repo ->
      path = Application.app_dir(:revoluchat, "priv/repo/seeds.exs")
      Code.eval_file(path)
    end)
  end

  defp load_app do
    Application.load(@app)
  end
end
