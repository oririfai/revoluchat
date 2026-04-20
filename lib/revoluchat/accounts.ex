defmodule Revoluchat.Accounts do
  @moduledoc """
  Context untuk autentikasi — microservice mode.
  Revoluchat TIDAK menerbitkan token. Hanya verifikasi JWT dari user service
  dan cek user exist via gRPC call ke User Service.
  """

  alias Revoluchat.Accounts.{Token, ApiKey, ServerKey, UserChat, Contact}
  alias Revoluchat.Grpc.UserClient
  alias Revoluchat.Repo
  import Ecto.Query
  require Logger

  # ─── API Key Management ─────────────────────────────────────────────────────

  def list_api_keys do
    Repo.all(ApiKey)
  end

  def create_api_key(name, app_id \\ "default_app") do
    %ApiKey{}
    |> ApiKey.changeset(%{
      name: name,
      key: ApiKey.generate_key(),
      status: "active",
      app_id: app_id
    })
    |> Repo.insert()
  end

  def revoke_api_key(id) do
    case Repo.get(ApiKey, id) do
      nil ->
        {:error, :not_found}

      api_key ->
        api_key
        |> ApiKey.changeset(%{status: "revoked"})
        |> Repo.update()
    end
  end

  def delete_api_key(id) do
    case Repo.get(ApiKey, id) do
      nil -> {:error, :not_found}
      api_key -> Repo.delete(api_key)
    end
  end

  def get_api_key_by_key(key) do
    from(a in ApiKey, where: a.key == ^key and a.status == "active")
    |> Repo.one()
  end

  # ─── Server Key Management ──────────────────────────────────────────────────

  def list_server_keys do
    from(s in ServerKey, order_by: [desc: s.inserted_at])
    |> Repo.all()
  end

  def create_server_key(name) do
    result =
      %ServerKey{}
      |> ServerKey.changeset(%{
        name: name,
        status: "active"
      })
      |> Repo.insert()

    result
  end

  def revoke_server_key(id) do
    case Repo.get(ServerKey, id) do
      nil -> {:error, :not_found}
      server_key ->
        server_key
        |> ServerKey.changeset(%{status: "revoked"})
        |> Repo.update()
    end
  end

  def delete_server_key(id) do
    case Repo.get(ServerKey, id) do
      nil -> {:error, :not_found}
      server_key ->
        result = Repo.delete(server_key)
        result
    end
  end

  def get_active_server_key do
    from(s in ServerKey, where: s.status == "active", order_by: [desc: s.inserted_at], limit: 1)
    |> Repo.one()
  end

  def set_active_server_key(id) do
    Repo.transaction(fn ->
      # Set all to inactive
      from(s in ServerKey, where: s.status == "active")
      |> Repo.update_all(set: [status: "inactive"])

      # Set target to active
      case Repo.get(ServerKey, id) do
        nil -> Repo.rollback(:not_found)
        key ->
          key
          |> ServerKey.changeset(%{status: "active"})
          |> Repo.update!()
      end
    end)
    |> case do
      {:ok, result} ->
        {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Mencoba melakukan koneksi JWKS secara manual.
  Jika berhasil, set key ini sebagai active.
  """
  def connect_server_key(id) do
    case Repo.get(ServerKey, id) do
      nil -> {:error, :not_found}
      server_key ->
        base_url = Application.get_env(:revoluchat, :jwks_url) || System.get_env("JWKS_URL")
        uri = URI.parse(base_url)
        query = URI.decode_query(uri.query || "") |> Map.put("server_key", server_key.key)
        full_url = URI.to_string(%URI{uri | query: URI.encode_query(query)})

        Logger.info("Memulai verifikasi manual JWKS: #{inspect(server_key)}")
        Logger.info("Full JWKS URL: #{full_url}")
        Logger.info("Mengirim permintaan ke JWKS dengan server_key: #{inspect(server_key.key)}")

        # Verify the server key by fetching signers from JWKS endpoint
        case JokenJwks.HttpFetcher.fetch_signers(full_url, []) do
          {:ok, signers} when is_list(signers) ->
            Logger.info("Verifikasi manual berhasil! Menemukan #{length(signers)} penandatangan.")
            # Set sebagai active setelah verifikasi sukses
            set_active_server_key(id)
            # Cache signers immediately to JwksStrategy to ensure they are available for token validation
            # This avoids a second redundant HTTP fetch
            Revoluchat.Accounts.JwksStrategy.update_signers(signers)
            {:ok, signers}

          {:ok, signers} when is_map(signers) ->
            Logger.info("Verifikasi manual berhasil! Menemukan #{map_size(signers)} penandatangan.")
            # Set sebagai active setelah verifikasi sukses
            set_active_server_key(id)
            # Cache signers immediately to JwksStrategy
            Revoluchat.Accounts.JwksStrategy.update_signers(signers)
            {:ok, signers}

          {:error, reason} ->
            Logger.error("Verifikasi manual gagal: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  def restart_jwks_strategy do
    if Process.whereis(Revoluchat.Accounts.JwksStrategy) do
      # Note: The strategy tree is named Revoluchat.Accounts.JwksStrategy.Supervisor
      # JokenJwks registers the hook under its own internal process but we can just restart it
      # by terminating and restarting the child in the main supervisor tree, or simply rely on
      # Application supervisor. But technically `JwksStrategy` is supervised directly.
      Supervisor.terminate_child(Revoluchat.Supervisor, Revoluchat.Accounts.JwksStrategy)
      Supervisor.restart_child(Revoluchat.Supervisor, Revoluchat.Accounts.JwksStrategy)
    end
  end

  # ─── Token Verification ───────────────────────────────────────────────────────

  @doc """
  Verifikasi JWT RS256 dari user service.
  Returns {:ok, user_id} dimana user_id adalah integer.
  """
  def verify_token(token_string) do
    Logger.info("Memulai validasi token: #{inspect(token_string)}")

    case Token.verify_access_token(token_string) do
      {:ok, claims} ->
        Logger.info("Token valid dengan klaim: #{inspect(claims)}")
        {:ok, claims}

      {:error, reason} ->
        Logger.error("Validasi token gagal: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ─── User Verification ────────────────────────────────────────────────────────

  @doc """
  Cek apakah user terdaftar dan aktif via gRPC ke User Service.
  Returns {:ok, user} atau {:error, :user_not_found}.
  """
  def verify_user_exists(user_id) do
    case UserClient.get_user(user_id) do
      {:ok, user} ->
        {:ok, user}

      {:error, :not_found} ->
        {:error, :user_not_found}

      {:error, _reason} ->
        {:error, :user_not_found}
    end
  end

  @doc """
  Ambil data user via gRPC dari User Service.
  """
  def get_user(user_id) do
    UserClient.get_user(user_id)
  end

  @doc """
  Ambil data user dari DB lokal (cache).
  """
  def get_registered_user(app_id, user_id) do
    case Repo.get_by(UserChat, app_id: app_id, user_id: user_id) do
      nil -> nil
      uc ->
        if is_nil(uc.name) or is_nil(uc.avatar_url) do
          schedule_profile_sync(app_id, user_id)
        end
        uc
    end
  end

  defp schedule_profile_sync(app_id, user_id) do
    %{app_id: app_id, user_id: user_id}
    |> Revoluchat.Workers.UserProfileSyncWorker.new()
    |> Oban.insert()
  rescue
    _ -> :ok # Avoid crashing if Oban is not ready
  end

  @doc """
  Ambil daftar user dari DB lokal berdasarkan list ID.
  """
  def list_registered_users_by_ids(app_id, user_ids) do
    user_chats = 
      from(uc in UserChat, where: uc.app_id == ^app_id and uc.user_id in ^user_ids)
      |> Repo.all()

    # Proactive Caching check
    Enum.each(user_chats, fn uc ->
      if is_nil(uc.name) or is_nil(uc.avatar_url) do
        schedule_profile_sync(app_id, uc.user_id)
      end
    end)

    Enum.map(user_chats, fn uc ->
      %{
        id: uc.user_id,
        chat_id: uc.chat_id,
        name: uc.name || "Unknown",
        phone: uc.phone,
        avatar_url: uc.avatar_url
      }
    end)
  end

  # ─── User Chat Registration ──────────────────────────────────────────────────

  @doc """
  Memastikan user terdaftar di tabel user_chats. 
  Jika belum ada, buat record baru dengan chat_id (UUID).
  """
  def ensure_user_chat_registered(user_id, app_id, profile_attrs \\ %{}) do
    attrs = 
      profile_attrs
      |> Map.take([:name, :phone, :avatar_url, "name", "phone", "avatar_url"])
      |> Map.merge(%{user_id: user_id, app_id: app_id})

    case Repo.get_by(UserChat, user_id: user_id, app_id: app_id) do
      nil ->
        attrs = Map.put_new(attrs, :chat_id, Ecto.UUID.generate())
        %UserChat{}
        |> UserChat.changeset(attrs)
        |> Repo.insert()

      user_chat ->
        user_chat
        |> UserChat.changeset(attrs)
        |> Repo.update()
    end
  end

  # ─── Contact Management ──────────────────────────────────────────────────────

  @doc """
  Menambah kontak berdasarkan nomor HP.
  Mencari user di user_chats berdasarkan phone dan app_id.
  """
  def add_contact_by_phone(app_id, owner_id, phone) do
    case Repo.get_by(UserChat, app_id: app_id, phone: phone) do
      nil ->
        {:error, :user_not_found}

      target_user ->
        if target_user.user_id == owner_id do
          {:error, :cannot_add_self}
        else
          %Contact{}
          |> Contact.changeset(%{
            owner_id: owner_id,
            contact_id: target_user.user_id,
            app_id: app_id,
            status: "added"
          })
          |> Repo.insert()
        end
    end
  end

  @doc """
  Cek apakah owner_id sudah menambahkan contact_id sebagai kontak.
  """
  def is_contact?(app_id, owner_id, contact_id) do
    Repo.exists?(
      from(c in Contact,
        where: c.app_id == ^app_id and c.owner_id == ^owner_id and c.contact_id == ^contact_id
      )
    )
  end

  @doc """
  Mengambil daftar user yang TERDAFTAR SEBAGAI KONTAK dari owner_id.
  """
  def list_registered_users(app_id, owner_id) do
    query =
      from(uc in UserChat,
        join: c in Contact,
        on: uc.user_id == c.contact_id and uc.app_id == c.app_id,
        where: c.owner_id == ^owner_id and c.app_id == ^app_id,
        select: uc
      )

    user_chats = Repo.all(query)

    Enum.map(user_chats, fn uc ->
      %{
        id: uc.user_id,
        chat_id: uc.chat_id,
        name: uc.name || "Unknown",
        phone: uc.phone,
        avatar_url: uc.avatar_url
      }
    end)
  end
end
