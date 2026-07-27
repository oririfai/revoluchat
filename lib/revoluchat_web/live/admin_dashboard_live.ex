defmodule RevoluchatWeb.AdminDashboardLive do
  use RevoluchatWeb, :live_view

  alias Revoluchat.Repo

  require Logger

  alias RevoluchatWeb.AdminDashboardLive.{
    SummarySection,
    ActivitySection,
    SettingSection,
    ApiKeysSection,
    ServerKeysSection,
    DocumentationSection,
    UserSection,
    AdminsSection
  }

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("Mounting AdminDashboardLive")
    if connected?(socket), do: schedule_refresh()

    {:ok,
     socket
     |> assign(page_title: "Summary")
     |> assign_stats()
     |> assign(active_tab: :summary)
     |> assign(sidebar_collapsed: false)
     |> assign(api_keys: [])
     |> assign(show_delete_modal: false)
     |> assign(deleting_key_id: nil)
     |> assign(show_revoke_modal: false)
     |> assign(revoking_key_id: nil)
     |> assign(server_keys: [])
     |> assign(signer_count: 0)
     |> assign(show_delete_server_modal: false)
     |> assign(deleting_server_key_id: nil)
     |> assign(show_revoke_server_modal: false)
     |> assign(revoking_server_key_id: nil)
     |> assign(show_server_error_modal: false)
     |> assign(server_error_message: "")
     # Setting Section assigns
     |> assign(setting_tab: :general)
     |> assign(wallpapers: [])
     |> allow_upload(:wallpaper, accept: ~w(.jpg .jpeg .png), max_entries: 1)
     # User Section assigns
     |> assign(users: [])
     |> assign(user_page: 1)
     |> assign(user_search: "")
     |> assign(user_status: "all")
     |> assign(user_total_count: 0)
     |> assign(user_total_pages: 0)
     |> assign(selected_user: nil)
     |> assign(show_user_detail_modal: false)
     |> assign(show_suspend_modal: false)
     |> assign(show_unsuspend_modal: false)
     |> assign(user_connection_error: nil)
     |> assign(total_users: 0)
     |> assign(total_active_users: 0)
     |> assign(total_suspended_users: 0)
     |> assign(total_conversations: 0)
     |> assign(message_volume_stats: [])
     |> assign(total_connected_users: 0)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    Logger.info(
      "Handling params: #{inspect(params)}, action: #{inspect(socket.assigns.live_action)}"
    )

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :summary, _params) do
    if Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "view_dashboard") do
      socket |> assign(active_tab: :summary) |> assign(page_title: "Summary")
    else
      socket |> put_flash(:error, "Unauthorized") |> push_navigate(to: "/admin/setting")
    end
  end

  defp apply_action(socket, :activity, _params) do
    if Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "view_dashboard") do
      socket |> assign(active_tab: :activity) |> assign(page_title: "Activity")
    else
      socket |> put_flash(:error, "Unauthorized") |> push_navigate(to: "/admin/setting")
    end
  end

  defp apply_action(socket, :users, _params) do
    if Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_users") do
      socket
      |> assign(active_tab: :users)
      |> assign(page_title: "Users")
      |> assign(user_page: 1)
      |> assign(user_search: "")
      |> assign_users()
    else
      socket |> put_flash(:error, "Unauthorized") |> push_navigate(to: "/admin")
    end
  end

  defp apply_action(socket, :setting, _params) do
    if Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      wallpapers =
        case Revoluchat.Grpc.AdminClient.get_wallpapers() do
          {:ok, list} -> list
          _ -> []
        end

      socket
      |> assign(active_tab: :setting)
      |> assign(page_title: "Settings")
      |> assign(wallpapers: wallpapers)
    else
      socket |> put_flash(:error, "Unauthorized") |> push_navigate(to: "/admin")
    end
  end

  defp apply_action(socket, :documentation, _params) do
    socket |> assign(active_tab: :documentation) |> assign(page_title: "Documentation")
  end

  defp apply_action(socket, :api_keys, _params) do
    if Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      api_keys =
        try do
          Revoluchat.Accounts.list_api_keys()
        rescue
          e ->
            Logger.error("Error listing api_keys: #{inspect(e)}")
            []
        end

      socket
      |> assign(active_tab: :api_keys)
      |> assign(page_title: "API Keys")
      |> assign(api_keys: api_keys)
      |> assign(show_delete_modal: false)
      |> assign(show_revoke_modal: false)
    else
      socket |> put_flash(:error, "Unauthorized") |> push_navigate(to: "/admin")
    end
  end

  defp apply_action(socket, :server_keys, _params) do
    if Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      server_keys =
        try do
          Revoluchat.Accounts.list_server_keys()
        rescue
          e ->
            Logger.error("Error listing server_keys: #{inspect(e)}")
            []
        end

      connected? =
        case Revoluchat.Accounts.check_active_server_key_connection() do
          {:ok, :connected} -> true
          _ -> false
        end

      signer_count =
        if connected? do
          try do
            case Revoluchat.Accounts.JwksStrategy.list_signers() do
              {:ok, signers} -> map_size(signers)
              _ -> 0
            end
          rescue
            _ -> 0
          end
        else
          0
        end

      socket
      |> assign(active_tab: :server_keys)
      |> assign(page_title: "Server Keys")
      |> assign(server_keys: server_keys)
      |> assign(signer_count: signer_count)
      |> assign(show_delete_server_modal: false)
      |> assign(show_revoke_server_modal: false)
      |> assign(show_server_error_modal: false)
      |> assign(server_error_message: "")
    else
      socket |> put_flash(:error, "Unauthorized") |> push_navigate(to: "/admin")
    end
  end

  defp apply_action(socket, :admins, _params) do
    if Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_admins") do
      admins = Revoluchat.Accounts.list_admins()
      socket
      |> assign(active_tab: :admins)
      |> assign(page_title: "Admins & Roles")
      |> assign(admins: admins)
      |> assign(show_admin_modal: false)
      |> assign(editing_admin: nil)
    else
      socket |> put_flash(:error, "Unauthorized") |> push_navigate(to: "/admin")
    end
  end

  @impl true
  def handle_event("create_api_key", %{"name" => name}, socket) do
    case Revoluchat.Accounts.create_api_key(name) do
      {:ok, _api_key} ->
        {:noreply,
         socket
         |> put_flash(:info, "API Key created successfully")
         |> assign(api_keys: safe_list_api_keys())}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create API Key")}
    end
  end

  def handle_event("revoke_api_key", %{"id" => id}, socket) do
    {:noreply, assign(socket, show_revoke_modal: true, revoking_key_id: id)}
  end

  def handle_event("confirm_revoke_api_key", _params, socket) do
    id = socket.assigns.revoking_key_id

    case Revoluchat.Accounts.revoke_api_key(id) do
      {:ok, _api_key} ->
        {:noreply,
         socket
         |> put_flash(:info, "API Key revoked")
         |> assign(show_revoke_modal: false, revoking_key_id: nil)
         |> assign(api_keys: safe_list_api_keys())}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to revoke API Key")
         |> assign(show_revoke_modal: false, revoking_key_id: nil)}
    end
  end

  def handle_event("delete_api_key", %{"id" => id}, socket) do
    {:noreply, assign(socket, show_delete_modal: true, deleting_key_id: id)}
  end

  def handle_event("confirm_delete_api_key", _params, socket) do
    id = socket.assigns.deleting_key_id

    case Revoluchat.Accounts.delete_api_key(id) do
      {:ok, _api_key} ->
        {:noreply,
         socket
         |> put_flash(:info, "API Key deleted successfully")
         |> assign(show_delete_modal: false, deleting_key_id: nil)
         |> assign(api_keys: safe_list_api_keys())}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete API Key")
         |> assign(show_delete_modal: false, deleting_key_id: nil)}
    end
  end

  # --- Server Keys Events ---

  def handle_event("create_server_key", %{"name" => name}, socket) do
    case Revoluchat.Accounts.create_server_key(name) do
      {:ok, _server_key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Server Key created successfully")
         |> assign(server_keys: safe_list_server_keys())}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create Server Key")}
    end
  end

  def handle_event("connect_server_key", %{"id" => id}, socket) do
    Logger.info("Event connect_server_key triggered for id: #{id}")

    case Revoluchat.Accounts.connect_server_key(id) do
      {:ok, signers} when is_list(signers) ->
        {:noreply,
         socket
         |> put_flash(:info, "Server Key connected and verified successfully!")
         |> assign(server_keys: safe_list_server_keys())
         |> assign(signer_count: length(signers))}

      {:ok, signers} when is_map(signers) ->
        {:noreply,
         socket
         |> put_flash(:info, "Server Key connected and verified successfully!")
         |> assign(server_keys: safe_list_server_keys())
         |> assign(signer_count: map_size(signers))}

      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Server Key connected successfully!")
         |> assign(server_keys: safe_list_server_keys())}

      {:error, reason} ->
        Logger.error("Failed to connect Server Key: #{inspect(reason)}")

        # Format the reason for better user readability
        error_msg =
          case reason do
            :could_not_reach_jwks_url ->
              "Tidak dapat menghubungi URL JWKS. Pastikan server tujuan sedang berjalan dan dapat diakses."

            {:error, :could_not_reach_jwks_url} ->
              "Tidak dapat menghubungi URL JWKS. Pastikan server tujuan sedang berjalan dan dapat diakses."

            {:error, :invalid_server_key} ->
              "Server Key tidak valid atau tidak diizinkan oleh server tujuan."

            other ->
              "Gagal verifikasi JWKS: #{inspect(other)}"
          end

        {:noreply,
         socket
         |> put_flash(:error, "Failed to connect Server Key: #{inspect(reason)}")
         |> assign(server_keys: safe_list_server_keys())
         |> assign(signer_count: 0)
         |> assign(show_server_error_modal: true)
         |> assign(server_error_message: error_msg)}
    end
  end

  def handle_event("revoke_server_key", %{"id" => id}, socket) do
    {:noreply, assign(socket, show_revoke_server_modal: true, revoking_server_key_id: id)}
  end

  def handle_event("confirm_revoke_server_key", _params, socket) do
    id = socket.assigns.revoking_server_key_id

    case Revoluchat.Accounts.revoke_server_key(id) do
      {:ok, _server_key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Server Key revoked")
         |> assign(show_revoke_server_modal: false, revoking_server_key_id: nil)
         |> assign(server_keys: safe_list_server_keys())}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to revoke Server Key")
         |> assign(show_revoke_server_modal: false, revoking_server_key_id: nil)}
    end
  end

  def handle_event("delete_server_key", %{"id" => id}, socket) do
    {:noreply, assign(socket, show_delete_server_modal: true, deleting_server_key_id: id)}
  end

  def handle_event("confirm_delete_server_key", _params, socket) do
    id = socket.assigns.deleting_server_key_id

    case Revoluchat.Accounts.delete_server_key(id) do
      {:ok, _server_key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Server Key deleted successfully")
         |> assign(show_delete_server_modal: false, deleting_server_key_id: nil)
         |> assign(server_keys: safe_list_server_keys())}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete Server Key")
         |> assign(show_delete_server_modal: false, deleting_server_key_id: nil)}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_delete_modal: false,
       deleting_key_id: nil,
       show_revoke_modal: false,
       revoking_key_id: nil,
       show_delete_server_modal: false,
       deleting_server_key_id: nil,
       show_revoke_server_modal: false,
       revoking_server_key_id: nil,
       show_server_error_modal: false,
       server_error_message: ""
     )}
  end

  # --- User Management Events ---

  def handle_event("view_user_detail", %{"id" => id}, socket) do
    user = Enum.find(socket.assigns.users, &(&1.id == id))
    {:noreply, assign(socket, show_user_detail_modal: true, selected_user: user)}
  end

  def handle_event("open_suspend_modal", %{"id" => id}, socket) do
    user = Enum.find(socket.assigns.users, &(&1.id == id))
    {:noreply, assign(socket, show_suspend_modal: true, selected_user: user)}
  end

  def handle_event("open_unsuspend_modal", %{"id" => id}, socket) do
    user = Enum.find(socket.assigns.users, &(&1.id == id))
    {:noreply, assign(socket, show_unsuspend_modal: true, selected_user: user)}
  end

  def handle_event("close_user_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_user_detail_modal: false,
       show_suspend_modal: false,
       show_unsuspend_modal: false,
       selected_user: nil
     )}
  end

  def handle_event(
        "confirm_suspend",
        %{"id" => uuid, "duration" => duration, "reason" => reason},
        socket
      ) do
    mapped_duration =
      case duration do
        "1_hour" -> "1h"
        "12_hours" -> "12h"
        "1_day" -> "1d"
        "1_week" -> "1w"
        "permanent" -> "100y"
        other -> other
      end

    case Revoluchat.Accounts.suspend_user(nil, uuid, mapped_duration, reason) do
      {:ok, _response} ->
        {:noreply,
         socket
         |> put_flash(:info, "User suspended successfully")
         |> assign(show_suspend_modal: false, selected_user: nil)
         |> assign_users()}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to suspend user: #{inspect(reason)}")
         |> assign(show_suspend_modal: false, selected_user: nil)}
    end
  end

  def handle_event("confirm_unsuspend", %{"id" => uuid}, socket) do
    case Revoluchat.Accounts.unsuspend_user(nil, uuid) do
      {:ok, _response} ->
        {:noreply,
         socket
         |> put_flash(:info, "User unsuspended successfully")
         |> assign(show_unsuspend_modal: false, selected_user: nil)
         |> assign_users()}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to unsuspend user: #{inspect(reason)}")
         |> assign(show_unsuspend_modal: false, selected_user: nil)}
    end
  end

  def handle_event("search_users", %{"search" => search}, socket) do
    {:noreply,
     socket
     |> assign(user_search: search, user_page: 1)
     |> assign_users()}
  end

  def handle_event("change_page", %{"page" => page_str}, socket) do
    page = String.to_integer(page_str)

    {:noreply,
     socket
     |> assign(user_page: page)
     |> assign_users()}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(user_status: status)
     |> assign(user_page: 1)
     |> assign_users()}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    tab_atom =
      try do
        String.to_existing_atom(tab)
      rescue
        _ -> :summary
      end

    {:noreply,
     socket
     |> assign(active_tab: tab_atom)
     |> assign(show_delete_modal: false)
     |> assign(show_revoke_modal: false)
     |> assign(show_delete_server_modal: false)
     |> assign(show_revoke_server_modal: false)
     |> assign(show_user_detail_modal: false)
     |> assign(show_suspend_modal: false)
     |> assign(show_unsuspend_modal: false)
     |> assign(selected_user: nil)}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, sidebar_collapsed: !socket.assigns.sidebar_collapsed)}
  end

  # ─── Settings Management Events ─────────────────────────────────────────────

  @impl true
  def handle_event("change_setting_tab", %{"tab" => tab_str}, socket) do
    tab = String.to_existing_atom(tab_str)
    {:noreply, assign(socket, setting_tab: tab)}
  end

  @impl true
  def handle_event("validate_wallpaper", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save_wallpaper", _params, socket) do
    # Consume uploaded file
    uploaded_files = consume_uploaded_entries(socket, :wallpaper, fn %{path: path}, _entry ->
      binary = File.read!(path)
      # Generate random id to avoid collisions
      uuid = Ecto.UUID.generate()
      filename = "wallpaper_#{uuid}.jpg"
      key = "wallpapers/#{filename}"
      
      case Revoluchat.Storage.upload_binary(key, binary, "image/jpeg") do
        {:ok, _} ->
          # Get public host URL
          public_host_str = Application.get_env(:revoluchat, :storage)[:public_host] || "localhost:9000/revoluchat"
          prefixed_host =
            if String.starts_with?(public_host_str, "http://") or String.starts_with?(public_host_str, "https://") do
              public_host_str
            else
              "https://" <> public_host_str
            end
          
          url = "#{prefixed_host}/#{key}"
          case Revoluchat.Grpc.AdminClient.add_wallpaper(url) do
            {:ok, _} -> {:ok, url}
            {:error, reason} -> 
              Logger.error("GRPC add_wallpaper failed: #{inspect(reason)}")
              {:postpone, "gRPC upload failed"}
          end
        error ->
          Logger.error("Failed to upload wallpaper to storage: #{inspect(error)}")
          {:postpone, "Upload failed"}
      end
    end)

    if Enum.empty?(uploaded_files) do
      {:noreply, put_flash(socket, :error, "Failed to upload wallpaper.")}
    else
      # Refresh wallpapers
      wallpapers =
        case Revoluchat.Grpc.AdminClient.get_wallpapers() do
          {:ok, list} -> list
          _ -> []
        end
      {:noreply,
       socket
       |> put_flash(:info, "Wallpaper uploaded successfully.")
       |> assign(wallpapers: wallpapers)}
    end
  end

  @impl true
  def handle_event("delete_wallpaper", %{"id" => id}, socket) do
    case Revoluchat.Grpc.AdminClient.delete_wallpaper(id) do
      {:ok, _} ->
        # Refresh wallpapers
        wallpapers =
          case Revoluchat.Grpc.AdminClient.get_wallpapers() do
            {:ok, list} -> list
            _ -> []
          end
        {:noreply,
         socket
         |> put_flash(:info, "Wallpaper deleted.")
         |> assign(wallpapers: wallpapers)}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete wallpaper.")}
    end
  end

  # ─── Admins Management Events ───────────────────────────────────────────────

  @impl true
  def handle_event("open_admin_modal", _params, socket) do
    {:noreply, assign(socket, show_admin_modal: true, editing_admin: nil)}
  end

  @impl true
  def handle_event("close_admin_modal", _params, socket) do
    {:noreply, assign(socket, show_admin_modal: false, editing_admin: nil)}
  end

  @impl true
  def handle_event("edit_admin", %{"id" => id}, socket) do
    admin = Revoluchat.Accounts.get_admin!(id)
    {:noreply, assign(socket, show_admin_modal: true, editing_admin: admin)}
  end

  @impl true
  def handle_event("delete_admin", %{"id" => id}, socket) do
    admin = Revoluchat.Accounts.get_admin!(id)
    case Revoluchat.Accounts.delete_admin(admin) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Admin deleted successfully.")
         |> assign(admins: Revoluchat.Accounts.list_admins())}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete admin.")}
    end
  end

  @impl true
  def handle_event("save_admin", params, socket) do
    permissions = params["permissions"] || []
    role = params["role"] || "custom"
    
    attrs = %{
      "email" => params["email"],
      "role" => role,
      "permissions" => permissions
    }

    # Only include password if provided
    attrs = if params["password"] != "", do: Map.put(attrs, "password", params["password"]), else: attrs

    result =
      if socket.assigns.editing_admin do
        Revoluchat.Accounts.update_admin(socket.assigns.editing_admin, attrs)
      else
        Revoluchat.Accounts.create_admin(attrs)
      end

    case result do
      {:ok, _admin} ->
        {:noreply,
         socket
         |> put_flash(:info, "Admin saved successfully.")
         |> assign(show_admin_modal: false, editing_admin: nil)
         |> assign(admins: Revoluchat.Accounts.list_admins())}

      {:error, %Ecto.Changeset{} = changeset} ->
        error_msg = RevoluchatWeb.CoreComponents.translate_errors(changeset)
        {:noreply, put_flash(socket, :error, "Failed to save admin: #{error_msg}")}
    end
  end

  @impl true
  def handle_info(:refresh_stats, socket) do
    schedule_refresh()
    {:noreply, assign_stats(socket)}
  end

  defp assign_stats(socket) do
    try do
      connected? =
        case Revoluchat.Accounts.check_active_server_key_connection() do
          {:ok, :connected} -> true
          _ -> false
        end

      signer_count =
        if connected? do
          case Revoluchat.Accounts.JwksStrategy.list_signers() do
            {:ok, signers} -> map_size(signers)
            _ -> 0
          end
        else
          0
        end

      # User stats (total, active, suspended)
      user_stats = Revoluchat.Accounts.get_user_stats()

      # Chat stats (handled based on tier via Revoluchat.Chat)
      chat_stats = Revoluchat.Chat.get_global_chat_stats()

      # Fill in missing days with 0 so we always have 7 data points
      today = Date.utc_today()
      last_7_days = Enum.map(0..6, fn days_ago -> Date.add(today, -6 + days_ago) end)

      volume_map =
        Map.new(chat_stats.message_volume_stats, fn %{date: d, count: c} -> {d, c} end)

      message_volume_stats =
        Enum.map(last_7_days, fn date ->
          date_str = Date.to_string(date)
          %{date: date_str, count: Map.get(volume_map, date_str, 0)}
        end)

      socket
      |> assign(total_messages: chat_stats.total_messages)
      |> assign(total_conversations: chat_stats.total_conversations)
      |> assign(signer_count: signer_count)
      |> assign(total_users: user_stats.total_users)
      |> assign(total_active_users: user_stats.active_users)
      |> assign(total_suspended_users: user_stats.suspended_users)
      |> assign(message_volume_stats: message_volume_stats)
      |> assign(total_connected_users: Map.get(chat_stats, :total_connected_users, 0))
    rescue
      e ->
        Logger.error("Error fetching stats: #{inspect(e)}")

        socket
        |> assign(total_messages: 0)
        |> assign(total_conversations: 0)
        |> assign(signer_count: 0)
        |> assign(total_users: 0)
        |> assign(total_active_users: 0)
        |> assign(total_suspended_users: 0)
        |> assign(message_volume_stats: [])
        |> assign(total_connected_users: 0)
    end
  end

  defp assign_users(socket) do
    search = socket.assigns.user_search
    page = socket.assigns.user_page
    status = socket.assigns.user_status

    if to_string(Application.get_env(:revoluchat, :tier_type)) == "advance" do
      connected? =
        case Revoluchat.Accounts.check_active_server_key_connection() do
          {:ok, :connected} -> true
          _ -> false
        end

      if connected? do
        case Revoluchat.Accounts.list_admin_users(nil, search, page, 10, status) do
          {:ok, result} ->
            socket
            |> assign(users: result.users)
            |> assign(user_total_count: result.total_count)
            |> assign(user_total_pages: result.total_pages)
            |> assign(user_connection_error: nil)

          {:error, reason} ->
            Logger.error("Failed to list users: #{inspect(reason)}")

            socket
            |> assign(users: [])
            |> assign(user_total_count: 0)
            |> assign(user_total_pages: 0)
            |> assign(user_connection_error: "Gagal mengambil data karena koneksi ke server error")
            |> put_flash(:error, "Gagal mengambil data karena koneksi ke server error")
        end
      else
        socket
        |> assign(users: [])
        |> assign(user_total_count: 0)
        |> assign(user_total_pages: 0)
        |> assign(user_connection_error: "Gagal mengambil data karena koneksi ke server error")
        |> put_flash(:error, "Gagal mengambil data karena koneksi ke server error")
      end
    else
      # Normal tier, local DB query, no connection check required
      case Revoluchat.Accounts.list_admin_users(nil, search, page, 10, status) do
        {:ok, result} ->
          socket
          |> assign(users: result.users)
          |> assign(user_total_count: result.total_count)
          |> assign(user_total_pages: result.total_pages)
          |> assign(user_connection_error: nil)

        {:error, reason} ->
          Logger.error("Failed to list users locally: #{inspect(reason)}")
          socket
          |> assign(users: [])
          |> assign(user_total_count: 0)
          |> assign(user_total_pages: 0)
          |> assign(user_connection_error: "Gagal mengambil data dari database lokal")
          |> put_flash(:error, "Gagal mengambil data dari database lokal")
      end
    end
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh_stats, 5000)
  end

  defp safe_list_api_keys do
    try do
      Revoluchat.Accounts.list_api_keys()
    rescue
      e ->
        Logger.error("Error safe listing api_keys: #{inspect(e)}")
        []
    end
  end

  defp safe_list_server_keys do
    try do
      Revoluchat.Accounts.list_server_keys()
    rescue
      e ->
        Logger.error("Error safe listing server_keys: #{inspect(e)}")
        []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <.page_header
        title={
          case @active_tab do
            :summary -> "Enterprise Summary"
            :activity -> "Recent Activity"
            :users -> "User Management"
            :setting -> "System Settings"
            :documentation -> "API & Integration Guide"
            :api_keys -> "Developer API Keys"
            :server_keys -> "Inter-Server Shared Keys"
            _ -> "Dashboard"
          end
        }
        description={
          case @active_tab do
            :summary -> "Overview of your Revoluchat Enterprise instance stats."
            :activity -> "Real-time monitoring and event connection logs."
            :users -> "Manage user accounts, view active connections, and handle suspensions."
            :setting -> "Configure system-wide parameters and integrations."
            :documentation -> "Technical documentation for developers to integrate with Revoluchat."
            :api_keys -> "Manage secure access keys for developer integrations."
            :server_keys -> "Manage backend-to-backend keys for accessing Identity Provider endpoints."
            _ -> ""
          end
        }
      />

      <%= if @active_tab == :summary do %>
        <SummarySection.render
          total_messages={@total_messages}
          total_conversations={@total_conversations}
          total_users={@total_users}
          total_active_users={@total_active_users}
          total_suspended_users={@total_suspended_users}
          message_volume_stats={@message_volume_stats}
          total_connected_users={@total_connected_users}
        />
      <% end %>

      <%= if @active_tab == :activity do %>
        <ActivitySection.render />
      <% end %>

      <%= if @active_tab == :users do %>
        <UserSection.render
          users={@users}
          page={@user_page}
          search={@user_search}
          status={@user_status}
          total_count={@user_total_count}
          total_pages={@user_total_pages}
          selected_user={@selected_user}
          show_detail={@show_user_detail_modal}
          show_suspend={@show_suspend_modal}
          show_unsuspend={@show_unsuspend_modal}
          connection_error={@user_connection_error}
        />
      <% end %>

      <%= if @active_tab == :setting do %>
        <SettingSection.render
          setting_tab={@setting_tab}
          wallpapers={@wallpapers}
          uploads={@uploads}
        />
      <% end %>

      <%= if @active_tab == :api_keys do %>
        <ApiKeysSection.render
          api_keys={@api_keys}
          show_delete_modal={@show_delete_modal}
          show_revoke_modal={@show_revoke_modal}
        />
      <% end %>

      <%= if @active_tab == :server_keys do %>
        <ServerKeysSection.render
          server_keys={@server_keys}
          signer_count={@signer_count}
          show_delete_server_modal={@show_delete_server_modal}
          show_revoke_server_modal={@show_revoke_server_modal}
          show_server_error_modal={@show_server_error_modal}
          server_error_message={@server_error_message}
        />
      <% end %>

      <%= if @active_tab == :documentation do %>
        <DocumentationSection.render />
      <% end %>

      <%= if @active_tab == :admins do %>
        <AdminsSection.render
          admins={@admins}
          show_admin_modal={@show_admin_modal}
          editing_admin={@editing_admin}
          current_admin={@current_admin}
        />
      <% end %>
    </div>
    """
  end
end
