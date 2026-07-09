defmodule Revoluchat.Accounts do
  @moduledoc """
  Context untuk autentikasi — microservice mode.
  Revoluchat TIDAK menerbitkan token. Hanya verifikasi JWT dari user service
  dan cek user exist via gRPC call ke User Service.
  """

  alias Revoluchat.Accounts.{
    Token,
    ApiKey,
    ServerKey,
    UserChat,
    Contact,
    Admin,
    AdminLoginActivity
  }

  alias Revoluchat.Grpc.UserClient
  alias Revoluchat.Repo
  import Ecto.Query
  require Logger

  # ─── Summary Stats ──────────────────────────────────────────────────────────

  @doc """
  Returns aggregated user statistics for the admin dashboard summary page.
  Returns a map: %{total_users, active_users, suspended_users}.
  For Advance Tier, attempts to get stats via gRPC, falling back to local DB.
  For Normal Tier, queries local user_chats table directly.
  """
  def get_user_stats do
    now = DateTime.utc_now()

    if to_string(Application.get_env(:revoluchat, :tier_type)) == "advance" do
      # In Advance Tier, try gRPC — get total, active, suspended via list_users count trick
      # Fallback to local DB if gRPC is unavailable
      try do
        {:ok, all} = Revoluchat.Grpc.AdminClient.list_users("", 1, 1, "all")
        {:ok, active} = Revoluchat.Grpc.AdminClient.list_users("", 1, 1, "active")
        {:ok, suspended} = Revoluchat.Grpc.AdminClient.list_users("", 1, 1, "suspended")

        %{
          total_users: all.total_count,
          active_users: active.total_count,
          suspended_users: suspended.total_count
        }
      rescue
        _ -> get_user_stats_from_local(now)
      end
    else
      get_user_stats_from_local(now)
    end
  end

  defp get_user_stats_from_local(now) do
    total = Repo.aggregate(UserChat, :count, :id) || 0

    active =
      from(uc in UserChat,
        where:
          uc.is_active == true and
            (is_nil(uc.suspended_until) or uc.suspended_until < ^now)
      )
      |> Repo.aggregate(:count, :id) || 0

    suspended =
      from(uc in UserChat,
        where:
          uc.is_active == false or
            (not is_nil(uc.suspended_until) and uc.suspended_until >= ^now)
      )
      |> Repo.aggregate(:count, :id) || 0

    %{
      total_users: total,
      active_users: active,
      suspended_users: suspended
    }
  end

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
      nil ->
        {:error, :not_found}

      server_key ->
        server_key
        |> ServerKey.changeset(%{status: "revoked"})
        |> Repo.update()
    end
  end

  def delete_server_key(id) do
    case Repo.get(ServerKey, id) do
      nil ->
        {:error, :not_found}

      server_key ->
        result = Repo.delete(server_key)
        result
    end
  end

  def get_active_server_key do
    from(s in ServerKey, where: s.status == "active", order_by: [desc: s.inserted_at], limit: 1)
    |> Repo.one()
  end

  def check_active_server_key_connection do
    case get_active_server_key() do
      nil ->
        {:error, :no_active_key}

      server_key ->
        base_url =
          Application.get_env(:revoluchat, :jwks_url) || System.get_env("JWKS_URL") ||
            "http://localhost:8181/api/v1/jwks"

        uri = URI.parse(base_url)
        query = URI.decode_query(uri.query || "") |> Map.put("server_key", server_key.key)
        full_url = URI.to_string(%URI{uri | query: URI.encode_query(query)})

        url_charlist = String.to_charlist(full_url)

        case :httpc.request(
               :get,
               {url_charlist, []},
               [{:timeout, 500}, {:connect_timeout, 500}],
               []
             ) do
          {:ok, {{_, 200, _}, _, _}} -> {:ok, :connected}
          _ -> {:error, :disconnected}
        end
    end
  end

  def set_active_server_key(id) do
    Repo.transaction(fn ->
      # Set all to inactive
      from(s in ServerKey, where: s.status == "active")
      |> Repo.update_all(set: [status: "inactive"])

      # Set target to active
      case Repo.get(ServerKey, id) do
        nil ->
          Repo.rollback(:not_found)

        key ->
          key
          |> ServerKey.changeset(%{status: "active"})
          |> Repo.update!()
      end
    end)
    |> case do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Mencoba melakukan koneksi JWKS secara manual.
  Jika berhasil, set key ini sebagai active.
  """
  def connect_server_key(id) do
    case Repo.get(ServerKey, id) do
      nil ->
        {:error, :not_found}

      server_key ->
        base_url = Application.get_env(:revoluchat, :jwks_url) || System.get_env("JWKS_URL")
        uri = URI.parse(base_url)
        query = URI.decode_query(uri.query || "") |> Map.put("server_key", server_key.key)
        full_url = URI.to_string(%URI{uri | query: URI.encode_query(query)})

        Logger.debug("Memulai verifikasi manual JWKS")
        Logger.debug("Mengirim request ke JWKS URL")
        Logger.debug("Mengirim permintaan ke JWKS")

        case JokenJwks.HttpFetcher.fetch_signers(full_url,
               http_max_retries_per_fetch: 0,
               http_adapter:
                 {Tesla.Adapter.Hackney, [recv_timeout: 10000, connect_timeout: 10000]}
             ) do
          {:ok, signers} ->
            Logger.debug("Verifikasi manual berhasil! Jumlah signer: #{length(signers)}")

            if (is_list(signers) and length(signers) > 0) or
                 (is_map(signers) and map_size(signers) > 0) do
              set_active_server_key(id)
              Revoluchat.Accounts.JwksStrategy.update_signers(signers)
              {:ok, signers}
            else
              Logger.warning("Verifikasi berhasil tapi Go memberikan daftar kunci KOSONG.")
              {:error, :empty_signers}
            end

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
    Logger.debug("Memulai validasi token (length: #{String.length(token_string)})")

    case Token.verify_access_token(token_string) do
      {:ok, claims} ->
        Logger.debug("Token valid untuk user_id: #{claims[:user_id]}")
        {:ok, claims}

      {:error, reason} ->
        Logger.warning("Validasi token gagal: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ─── User Verification ────────────────────────────────────────────────────────

  @doc """
  Cek apakah user terdaftar dan aktif via gRPC ke User Service.
  Returns {:ok, user} atau {:error, :user_not_found}.
  """
  def verify_user_exists(user_id) do
    if to_string(Application.get_env(:revoluchat, :tier_type)) == "advance" do
      case UserClient.get_user(user_id) do
        {:ok, user} ->
          cond do
            user.status == "active" ->
              {:ok, user}

            String.starts_with?(user.status, "suspended:") ->
              "suspended:" <> suspended_until = user.status

              case DateTime.from_iso8601(suspended_until) do
                {:ok, suspended_until_dt, _offset} ->
                  if DateTime.compare(suspended_until_dt, DateTime.utc_now()) in [:lt, :eq] do
                    Logger.info(
                      "Advance suspension expired for user #{user_id}! Auto-reactivating..."
                    )

                    case Revoluchat.Grpc.AdminClient.unsuspend_user(user_id) do
                      {:ok, _} ->
                        {:ok, Map.put(user, :status, "active")}

                      _ ->
                        {:error, {:suspended, suspended_until}}
                    end
                  else
                    {:error, {:suspended, suspended_until}}
                  end

                _ ->
                  {:error, {:suspended, suspended_until}}
              end

            true ->
              {:error, {:suspended, nil}}
          end

        {:error, :not_found} ->
          {:error, :user_not_found}

        {:error, _reason} ->
          {:error, :user_not_found}
      end
    else
      # Normal tier: check local db
      case Repo.get_by(UserChat, user_id: to_string(user_id)) do
        nil ->
          # If not found locally, we let them connect
          {:ok, %{name: "User", phone: "", avatar_url: ""}}

        uc ->
          cond do
            uc.is_active ->
              if not is_nil(uc.suspended_until) and
                   DateTime.compare(uc.suspended_until, DateTime.utc_now()) == :gt do
                {:error, {:suspended, DateTime.to_iso8601(uc.suspended_until)}}
              else
                {:ok, uc}
              end

            true ->
              # Not active (is_active is false). Check if suspended_until has passed.
              if not is_nil(uc.suspended_until) and
                   DateTime.compare(uc.suspended_until, DateTime.utc_now()) == :lt do
                # Suspension expired! Auto-reactivate.
                uc
                |> UserChat.changeset(%{is_active: true, suspended_until: nil})
                |> Repo.update()

                {:ok, uc}
              else
                suspended_until_str =
                  if uc.suspended_until, do: DateTime.to_iso8601(uc.suspended_until), else: nil

                {:error, {:suspended, suspended_until_str}}
              end
          end
      end
    end
  end

  @doc """
  Ambil data user via gRPC dari User Service.
  """
  def get_user(user_id) do
    UserClient.get_user(user_id)
  end

  @doc """
  Ambil data user dari DB lokal (cache) atau remote gRPC jika advance tier.
  """
  def get_registered_user(app_id, user_id) do
    if to_string(Application.get_env(:revoluchat, :tier_type)) == "advance" do
      case UserClient.get_user(user_id) do
        {:ok, remote_user} ->
          target_id = remote_user.uuid || remote_user.id

          %Revoluchat.Accounts.UserChat{
            user_id: target_id,
            chat_id: target_id,
            name: remote_user.name,
            phone: remote_user.phone,
            avatar_url: remote_user.avatar_url
          }

        _ ->
          nil
      end
    else
      case Repo.get_by(UserChat, app_id: app_id, user_id: user_id) do
        nil ->
          nil

        uc ->
          if is_nil(uc.name) or is_nil(uc.avatar_url) do
            schedule_profile_sync(app_id, user_id)
          end

          uc
      end
    end
  end

  defp schedule_profile_sync(app_id, user_id) do
    %{app_id: app_id, user_id: user_id}
    |> Revoluchat.Workers.UserProfileSyncWorker.new()
    |> Oban.insert()
  rescue
    # Avoid crashing if Oban is not ready
    _ -> :ok
  end

  @doc """
  Ambil daftar user dari DB lokal berdasarkan list ID.
  """
  def list_registered_users_by_ids(app_id, user_ids) do
    valid_ids = Enum.filter(user_ids, fn id -> is_binary(id) && id != "" end)
    tier = to_string(Application.get_env(:revoluchat, :tier_type))

    if tier == "advance" do
      # Advance Tier: Fetch from Go Backend using get_users/1
      users = UserClient.get_users(valid_ids)

      Enum.map(users, fn u ->
        # Use uuid as primary ID to match conversation participants (UUID strings)
        target_id = u.uuid || u.id

        %{
          id: target_id,
          chat_id: target_id,
          name: u.name || "User #{target_id}",
          phone: u.phone,
          avatar_url: u.avatar_url
        }
      end)
    else
      # Normal Tier: Use local Elixir database
      from(uc in UserChat, where: uc.app_id == ^app_id and uc.user_id in ^valid_ids)
      |> Repo.all()
      |> Enum.map(fn uc ->
        %{
          id: uc.user_id,
          chat_id: uc.chat_id,
          name: uc.name || "User #{uc.user_id}",
          phone: uc.phone,
          avatar_url: uc.avatar_url
        }
      end)
    end
  end

  # ─── User Chat Registration ──────────────────────────────────────────────────

  @doc """
  Memastikan user terdaftar di tabel user_chats.
  Jika belum ada, buat record baru dengan chat_id (UUID).
  """
  def sync_user_profile_to_advance_tier(app_id, user_id) do
    if Application.get_env(:revoluchat, :tier_type) == "advance" do
      %{app_id: app_id, user_id: user_id}
      |> Revoluchat.Workers.UserProfileSyncWorker.new()
      |> Revoluchat.Repo.insert()
    end
  end

  @doc """
  Sync user profile to advance tier synchronously to ensure they exist in Go BE
  before running related gRPC calls (like group creation or adding members).
  """
  def sync_user_profile_to_advance_tier_sync(app_id, user_id) do
    if Application.get_env(:revoluchat, :tier_type) == "advance" do
      case get_user(user_id) do
        {:ok, user} ->
          ensure_user_chat_registered(user_id, app_id, user)
          :ok

        {:error, reason} ->
          {:error, reason}
      end
    else
      :ok
    end
  end

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

  def add_contact_by_phone(app_id, owner_id, phone) do
    if Application.get_env(:revoluchat, :tier_type) == "advance" do
      add_contact_advance(app_id, owner_id, phone)
    else
      add_contact_normal(app_id, owner_id, phone)
    end
  end

  defp add_contact_advance(app_id, owner_id, phone) do
    phone = normalize_phone(phone)

    case UserClient.search_user_by_phone(app_id, phone) do
      {:ok, user} ->
        case UserClient.add_contact(app_id, owner_id, user.id) do
          {:ok, _} -> {:ok, %{contact_id: user.id}}
          {:error, reason} -> {:error, reason}
        end

      {:error, _} ->
        {:error, :user_not_found}
    end
  end

  defp add_contact_normal(app_id, owner_id, phone) do
    phone = normalize_phone(phone)

    case Repo.get_by(UserChat, app_id: app_id, phone: phone) do
      nil ->
        # Jika tidak ada di lokal, coba cari di User Service (Go) - ini legacy logic
        case search_user_by_phone_remote(phone) do
          {:ok, remote_user} ->
            # Berhasil ketemu di Go, daftarkan ke lokal dulu
            case ensure_user_chat_registered(remote_user.id, app_id, remote_user) do
              {:ok, target_user} ->
                perform_add_contact(app_id, owner_id, target_user.user_id)

              {:error, _} ->
                {:error, :user_not_found}
            end

          {:error, _} ->
            {:error, :user_not_found}
        end

      target_user ->
        perform_add_contact(app_id, owner_id, target_user.user_id)
    end
  end

  def perform_add_contact(app_id, owner_id, target_id) do
    if target_id == owner_id do
      {:error, :cannot_add_self}
    else
      # Cek apakah sudah ada untuk menghindari duplicate key error
      case Repo.get_by(Contact, owner_id: owner_id, contact_id: target_id, app_id: app_id) do
        nil ->
          %Contact{}
          |> Contact.changeset(%{
            owner_id: owner_id,
            contact_id: target_id,
            app_id: app_id,
            status: "added"
          })
          |> Repo.insert()

        contact ->
          {:ok, contact}
      end
    end
  end

  defp search_user_by_phone_remote(phone) do
    phone = normalize_phone(phone)
    # Ambil base URL dari JWKS_URL
    jwks_url =
      Application.get_env(:revoluchat, :jwks_url) || System.get_env("JWKS_URL") ||
        "http://localhost:8181/api/v1/jwks"

    base_url = jwks_url |> String.replace("/jwks", "") |> String.replace("/api/v1", "")
    url = "#{base_url}/api/v1/user/search"

    # Ambil server key aktif untuk autentikasi sistem-ke-sistem
    headers =
      case get_active_server_key() do
        nil -> []
        sk -> [{"x-server-key", sk.key}]
      end

    case Req.get(url, params: [phone: phone], headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        {:ok,
         %{
           id: body["id"],
           name: body["full_name"],
           phone: body["phone_number"],
           avatar_url: body["profile_photo"]
         }}

      _ ->
        {:error, :not_found}
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

  def list_registered_users(app_id, owner_id) do
    if to_string(Application.get_env(:revoluchat, :tier_type)) == "advance" do
      case UserClient.list_contacts(app_id, owner_id) do
        {:ok, contacts} ->
          Enum.map(contacts, fn u ->
            %{
              id: u.id,
              # In Advance, UUID is chat_id
              chat_id: u.id,
              name: u.full_name || "User #{u.id}",
              phone: u.phone_number,
              avatar_url: u.profile_photo
            }
          end)

        _ ->
          []
      end
    else
      query =
        from(uc in UserChat,
          where: uc.app_id == ^app_id and uc.user_id != ^owner_id,
          order_by: [asc: uc.name]
        )

      results = Repo.all(query)

      Enum.map(results, fn uc ->
        %{
          id: to_string(uc.user_id),
          chat_id: uc.chat_id,
          name: uc.name || "User #{uc.user_id}",
          phone: uc.phone,
          avatar_url: uc.avatar_url
        }
      end)
    end
  end

  @doc """
  Sync contacts by checking a list of phone numbers against registered users.
  Returns a list of User objects for those that are registered.
  """
  def sync_contacts(app_id, phones) when is_list(phones) do
    normalized_phones =
      phones
      |> Enum.map(&normalize_phone/1)
      |> Enum.filter(&(&1 != "" and &1 != nil))
      |> Enum.uniq()

    if to_string(Application.get_env(:revoluchat, :tier_type)) == "advance" do
      # In Advance, we search Go backend.
      # Use async_stream to check multiple numbers concurrently
      normalized_phones
      |> Task.async_stream(
        fn phone ->
          case UserClient.search_user_by_phone(app_id, phone) do
            {:ok, user} ->
              %{
                id: user.id,
                chat_id: user.id,
                name: user.full_name || "User #{user.id}",
                phone: user.phone_number,
                avatar_url: user.profile_photo
              }

            _ ->
              nil
          end
        end, max_concurrency: 15, timeout: 10_000, on_timeout: :exit)
      |> Enum.map(fn
        {:ok, result} -> result
        _ -> nil
      end)
      |> Enum.filter(& &1)
    else
      # Normal tier: search local DB
      from(uc in UserChat,
        where: uc.app_id == ^app_id and uc.phone in ^normalized_phones,
        order_by: [asc: uc.name]
      )
      |> Repo.all()
      |> Enum.map(fn uc ->
        %{
          id: to_string(uc.user_id),
          chat_id: uc.chat_id,
          name: uc.name || "User #{uc.user_id}",
          phone: uc.phone,
          avatar_url: uc.avatar_url
        }
      end)
    end
  end

  defp normalize_phone(phone) do
    phone = phone |> String.trim() |> String.replace(~r/^\+/, "")

    if String.starts_with?(phone, "0") do
      "62" <> String.slice(phone, 1..-1//1)
    else
      phone
    end
  end

  # ─── Admin Management ────────────────────────────────────────────────────────

  @doc """
  Lists users for the Admin Dashboard.
  Delegates to gRPC for Advance tier, or queries UserChat for Normal tier.
  """
  def list_admin_users(app_id \\ nil, query \\ "", page \\ 1, limit \\ 10, status_filter \\ "all") do
    if to_string(Application.get_env(:revoluchat, :tier_type)) == "advance" do
      Revoluchat.Grpc.AdminClient.list_users(query, page, limit, status_filter)
    else
      offset = (page - 1) * limit

      base_query = from(uc in UserChat)

      base_query =
        if app_id do
          from(uc in base_query, where: uc.app_id == ^app_id)
        else
          base_query
        end

      base_query =
        if query != "" do
          search_term = "%#{query}%"

          from(uc in base_query,
            where: ilike(uc.name, ^search_term) or ilike(uc.phone, ^search_term)
          )
        else
          base_query
        end

      base_query =
        case status_filter do
          "active" -> from(uc in base_query, where: uc.is_active == true)
          "suspended" -> from(uc in base_query, where: uc.is_active == false)
          _ -> base_query
        end

      total_count = Repo.aggregate(base_query, :count, :id)
      total_pages = ceil(total_count / limit)

      users =
        base_query
        |> order_by(desc: :inserted_at)
        |> offset(^offset)
        |> limit(^limit)
        |> Repo.all()
        |> Enum.map(fn uc ->
          %{
            id: to_string(uc.user_id),
            uuid: to_string(uc.user_id),
            name: uc.name || "User #{uc.user_id}",
            phone: uc.phone || "-",
            status:
              if uc.is_active and
                   (is_nil(uc.suspended_until) or
                      DateTime.compare(uc.suspended_until, DateTime.utc_now()) == :lt) do
                "active"
              else
                "suspended"
              end,
            inserted_at: DateTime.to_iso8601(DateTime.from_naive!(uc.inserted_at, "Etc/UTC")),
            # Default for now
            is_kyc: true
          }
        end)

      {:ok,
       %{
         users: users,
         total_count: total_count,
         total_pages: total_pages
       }}
    end
  end

  def suspend_user(app_id \\ nil, user_id, duration, reason) do
    if to_string(Application.get_env(:revoluchat, :tier_type)) == "advance" do
      case Revoluchat.Grpc.AdminClient.suspend_user(user_id, duration, reason) do
        {:ok, response} ->
          # Kick online user WebSocket immediately!
          RevoluchatWeb.Endpoint.broadcast("user_socket:#{user_id}", "disconnect", %{})
          {:ok, response}

        {:error, reason} ->
          {:error, reason}
      end
    else
      query = from(uc in UserChat, where: uc.user_id == ^to_string(user_id))
      query = if app_id, do: from(uc in query, where: uc.app_id == ^app_id), else: query

      case Repo.all(query) do
        [] ->
          {:error, "User not found"}

        users ->
          suspended_until = parse_duration(duration)

          Repo.transaction(fn ->
            Enum.each(users, fn u ->
              case u
                   |> UserChat.changeset(%{is_active: false, suspended_until: suspended_until})
                   |> Repo.update() do
                {:ok, _} -> :ok
                {:error, changeset} -> Repo.rollback(changeset)
              end
            end)
          end)
          |> case do
            {:ok, _} ->
              # Kick online user WebSocket immediately!
              RevoluchatWeb.Endpoint.broadcast("user_socket:#{user_id}", "disconnect", %{})
              {:ok, %{success: true, message: "User suspended successfully"}}

            {:error, changeset} ->
              {:error, changeset}
          end
      end
    end
  end

  def unsuspend_user(app_id \\ nil, user_id) do
    if to_string(Application.get_env(:revoluchat, :tier_type)) == "advance" do
      Revoluchat.Grpc.AdminClient.unsuspend_user(user_id)
    else
      query = from(uc in UserChat, where: uc.user_id == ^to_string(user_id))
      query = if app_id, do: from(uc in query, where: uc.app_id == ^app_id), else: query

      case Repo.all(query) do
        [] ->
          {:error, "User not found"}

        users ->
          Repo.transaction(fn ->
            Enum.each(users, fn u ->
              case u
                   |> UserChat.changeset(%{is_active: true, suspended_until: nil})
                   |> Repo.update() do
                {:ok, _} -> :ok
                {:error, changeset} -> Repo.rollback(changeset)
              end
            end)
          end)
          |> case do
            {:ok, _} ->
              {:ok, %{success: true, message: "User unsuspended successfully"}}

            {:error, changeset} ->
              {:error, changeset}
          end
      end
    end
  end

  defp parse_duration(duration) do
    cond do
      duration == "permanent" or duration == "" or is_nil(duration) ->
        nil

      true ->
        case Regex.run(~r/^(\d+)([a-zA-Z]+)$/, to_string(duration)) do
          [_, val_str, unit] ->
            val = String.to_integer(val_str)
            now = DateTime.utc_now()

            case String.downcase(unit) do
              "h" -> DateTime.add(now, val * 3600, :second)
              "d" -> DateTime.add(now, val * 86400, :second)
              "w" -> DateTime.add(now, val * 7 * 86400, :second)
              "m" -> DateTime.add(now, val * 30 * 86400, :second)
              "y" -> DateTime.add(now, val * 365 * 86400, :second)
              _ -> nil
            end

          _ ->
            nil
        end
    end
  end

  def log_admin_login(admin_or_email, ip_address, user_agent, status) do
    {os, browser} = parse_user_agent(user_agent)

    attrs = %{
      ip_address: ip_address,
      user_agent: user_agent,
      device_os: os,
      device_browser: browser,
      status: to_string(status)
    }

    attrs =
      case admin_or_email do
        %Admin{} = admin ->
          Map.merge(attrs, %{admin_id: admin.id, email: admin.email})

        email when is_binary(email) ->
          Map.put(attrs, :email, email)

        _ ->
          attrs
      end

    %AdminLoginActivity{}
    |> AdminLoginActivity.changeset(attrs)
    |> Repo.insert()
  end

  def parse_user_agent(ua) do
    ua_str = to_string(ua)

    os =
      cond do
        String.contains?(ua_str, "Windows") -> "Windows"
        String.contains?(ua_str, "Macintosh") -> "macOS"
        String.contains?(ua_str, "Android") -> "Android"
        String.contains?(ua_str, "iPhone") or String.contains?(ua_str, "iPad") -> "iOS"
        String.contains?(ua_str, "Linux") -> "Linux"
        true -> "Unknown OS"
      end

    browser =
      cond do
        String.contains?(ua_str, "Edg") -> "Edge"
        String.contains?(ua_str, "Chrome") -> "Chrome"
        String.contains?(ua_str, "Safari") -> "Safari"
        String.contains?(ua_str, "Firefox") -> "Firefox"
        true -> "Unknown Browser"
      end

    {os, browser}
  end

  def list_admins do
    Repo.all(from a in Admin, order_by: [desc: a.inserted_at])
  end

  def get_admin!(id), do: Repo.get!(Admin, id)

  def get_admin(id), do: Repo.get(Admin, id)

  def create_admin(attrs \\ %{}) do
    %Admin{}
    |> Admin.changeset(attrs)
    |> Repo.insert()
  end

  def update_admin(%Admin{} = admin, attrs) do
    admin
    |> Admin.changeset(attrs)
    |> Repo.update()
  end

  def delete_admin(%Admin{} = admin) do
    Repo.delete(admin)
  end

  def change_admin(%Admin{} = admin, attrs \\ %{}) do
    Admin.changeset(admin, attrs)
  end
end
