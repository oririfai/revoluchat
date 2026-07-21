defmodule Revoluchat.Workers.MessageTtlSweeper do
  use Oban.Worker, queue: :default, max_attempts: 1
  require Logger
  import Ecto.Query
  alias Revoluchat.Repo
  alias Revoluchat.Chat.Message

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("[MessageTtlSweeper] Memulai proses pembersihan pesan yang kadaluarsa (TTL)")

    # Cari pesan yang memiliki ttl_seconds > 0
    # Dan umur pesan (berdasarkan inserted_at) + ttl_seconds sudah berlalu
    # Note: Kita menggunakan fragment PostgreSQL untuk melakukan penambahan interval detik
    query =
      from m in Message,
        where: m.ttl_seconds > 0,
        where: is_nil(m.deleted_at),
        where: fragment("? + (? * interval '1 second') < now()", m.inserted_at, m.ttl_seconds)

    # Soft delete (set deleted_at) untuk pesan-pesan tersebut
    {deleted_count, _} =
      Repo.update_all(query, set: [deleted_at: DateTime.utc_now()])

    if deleted_count > 0 do
      Logger.info("[MessageTtlSweeper] Berhasil menghapus #{deleted_count} pesan kadaluarsa.")
      # TODO: Trigger channel broadcast agar klien menghapus pesan dari UI
    else
      Logger.debug("[MessageTtlSweeper] Tidak ada pesan yang perlu dihapus.")
    end

    :ok
  end
end
