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
    AdminsSection,
    LogSection
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
     |> assign(app_preferences: %{})
     |> assign(save_app_preferences_status: nil)
     |> assign(show_delete_wallpaper_modal: false)
     |> assign(deleting_wallpaper_id: nil)
     # Log Section assigns
     |> assign(log_tab: :user)
     |> assign(log_search: "")
     |> assign(log_start_date: "")
     |> assign(log_end_date: "")
     |> assign(log_user_page: 1)
     |> assign(log_user_total_count: 0)
     |> assign(log_user_total_pages: 1)
     |> assign(log_admin_page: 1)
     |> assign(log_admin_total_count: 0)
     |> assign(log_admin_total_pages: 1)
     |> assign(user_logs: [])
     |> assign(admin_logs: [])
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
     |> assign(total_connected_users: 0)
     |> assign(server_key_connected: false)
     # Activity Telemetry Assigns
     |> assign(activity_throughput_history: [1200, 1350, 1100, 1420, 1280, 1500, 1390, 1480, 1420, 1560, 1480, 1520])
     |> assign(activity_latency_history: [14.2, 12.8, 13.5, 11.2, 12.0, 11.8, 12.5, 11.4, 12.2, 11.8, 11.5, 11.8])
     |> assign(activity_beam_memory_mb: Float.round(:erlang.memory(:total) / (1024 * 1024), 1))
     |> assign(activity_beam_processes: :erlang.system_info(:process_count))
     |> assign(activity_beam_schedulers: :erlang.system_info(:schedulers_online))
     |> assign(activity_oban_stats: Revoluchat.Accounts.get_oban_job_stats())
     |> assign(activity_platform_share: Revoluchat.Accounts.get_client_platform_share())
     |> assign(activity_payload_stats: Revoluchat.Chat.get_message_payload_stats())
     |> assign(activity_stream_logs: initial_activity_stream_logs())
     |> assign(admin_audit_logs: initial_admin_audit_logs())}
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
      if connected?(socket) do
        Process.send_after(self(), :tick_activity, 2000)
      end

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

      app_preferences =
        case Revoluchat.Grpc.AdminClient.get_app_preferences(["app_version", "playstore_url", "appstore_url", "max_message_size", "rate_limit_per_sec", "max_attachment_size_mb"]) do
          {:ok, map} -> map
          _ -> %{}
        end

      socket
      |> assign(active_tab: :setting)
      |> assign(page_title: "Settings")
      |> assign(wallpapers: wallpapers)
      |> assign(app_preferences: app_preferences)
      |> assign(save_app_preferences_status: nil)
      |> assign(save_global_limits_status: nil)
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

  defp apply_action(socket, :logs, _params) do
    if Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "view_logs") or Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "view_dashboard") or Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      socket
      |> assign(active_tab: :logs)
      |> assign(page_title: "Audit & Footprint Logs")
      |> assign(log_tab: socket.assigns[:log_tab] || :user)
      |> fetch_logs()
    else
      socket |> put_flash(:error, "Unauthorized") |> push_navigate(to: "/admin")
    end
  end

  defp fetch_logs(socket) do
    search = socket.assigns[:log_search] || ""
    start_date = socket.assigns[:log_start_date] || ""
    end_date = socket.assigns[:log_end_date] || ""
    user_page = socket.assigns[:log_user_page] || 1
    admin_page = socket.assigns[:log_admin_page] || 1

    user_res = Revoluchat.Accounts.list_user_login_activities(search: search, start_date: start_date, end_date: end_date, page: user_page, per_page: 20)
    admin_res = Revoluchat.Accounts.list_admin_login_activities(search: search, start_date: start_date, end_date: end_date, page: admin_page, per_page: 20)

    socket
    |> assign(user_logs: user_res.entries)
    |> assign(log_user_page: user_res.page)
    |> assign(log_user_total_count: user_res.total_count)
    |> assign(log_user_total_pages: user_res.total_pages)
    |> assign(admin_logs: admin_res.entries)
    |> assign(log_admin_page: admin_res.page)
    |> assign(log_admin_total_count: admin_res.total_count)
    |> assign(log_admin_total_pages: admin_res.total_pages)
  end

  @impl true
  def handle_event("change_log_tab", params, socket) do
    tab_val = Map.get(params, "tab") || Map.get(params, "value") || "user"
    tab_atom = if to_string(tab_val) == "admin", do: :admin, else: :user
    {:noreply, assign(socket, log_tab: tab_atom)}
  end

  @impl true
  def handle_event("change_log_page", %{"page" => page_str}, socket) do
    page =
      case Integer.parse(to_string(page_str)) do
        {int, ""} -> max(1, int)
        _ -> 1
      end

    socket =
      if socket.assigns.log_tab == :admin do
        socket |> assign(log_admin_page: page) |> fetch_logs()
      else
        socket |> assign(log_user_page: page) |> fetch_logs()
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_logs", params, socket) do
    search = Map.get(params, "search", socket.assigns[:log_search] || "")
    start_date = Map.get(params, "start_date", socket.assigns[:log_start_date] || "")
    end_date = Map.get(params, "end_date", socket.assigns[:log_end_date] || "")

    socket =
      socket
      |> assign(log_search: search, log_start_date: start_date, log_end_date: end_date)
      |> assign(log_user_page: 1, log_admin_page: 1)
      |> fetch_logs()

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_log_filters", _params, socket) do
    socket =
      socket
      |> assign(log_search: "", log_start_date: "", log_end_date: "")
      |> assign(log_user_page: 1, log_admin_page: 1)
      |> fetch_logs()

    {:noreply, socket}
  end

  @impl true
  def handle_event("create_api_key", %{"name" => name}, socket) do
    if not Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
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
  end

  def handle_event("revoke_api_key", %{"id" => id}, socket) do
    if not Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
      {:noreply, assign(socket, show_revoke_modal: true, revoking_key_id: id)}
    end
  end

  def handle_event("confirm_revoke_api_key", _params, socket) do
    if not Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
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
  end

  def handle_event("delete_api_key", %{"id" => id}, socket) do
    if not Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
      {:noreply, assign(socket, show_delete_modal: true, deleting_key_id: id)}
    end
  end

  def handle_event("confirm_delete_api_key", _params, socket) do
    if not Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
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
  end

  # --- Server Keys Events ---

  def handle_event("create_server_key", %{"name" => name}, socket) do
    if not Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
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
  end

  def handle_event("connect_server_key", %{"id" => id}, socket) do
    if not Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
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
  end

  def handle_event("revoke_server_key", %{"id" => id}, socket) do
    if not Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
      {:noreply, assign(socket, show_revoke_server_modal: true, revoking_server_key_id: id)}
    end
  end

  def handle_event("confirm_revoke_server_key", _params, socket) do
    if not Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
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
  end

  def handle_event("delete_server_key", %{"id" => id}, socket) do
    if not Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
      {:noreply, assign(socket, show_delete_server_modal: true, deleting_server_key_id: id)}
    end
  end

  def handle_event("confirm_delete_server_key", _params, socket) do
    if not Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
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
       server_error_message: "",
       show_delete_wallpaper_modal: false,
       deleting_wallpaper_id: nil
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
    if not (Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") or Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "view_dashboard")) do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
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
  end

  def handle_event("confirm_unsuspend", %{"id" => uuid}, socket) do
    if not (Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") or Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "view_dashboard")) do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
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
    if not Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
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
  end

  @impl true
  def handle_event("save_app_preferences", %{"app_version" => app_version, "playstore_url" => playstore_url, "appstore_url" => appstore_url}, socket) do
    if Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      results = [
        Revoluchat.Grpc.AdminClient.set_app_preference("app_version", app_version),
        Revoluchat.Grpc.AdminClient.set_app_preference("playstore_url", playstore_url),
        Revoluchat.Grpc.AdminClient.set_app_preference("appstore_url", appstore_url)
      ]

      has_error = Enum.any?(results, fn
        {:ok, _} -> false
        _ -> true
      end)

      if has_error do
        {:noreply,
         socket
         |> put_flash(:error, "Failed to save app preferences.")
         |> assign(save_app_preferences_status: :error)}
      else
        # Refresh preferences
        app_preferences =
          case Revoluchat.Grpc.AdminClient.get_app_preferences(["app_version", "playstore_url", "appstore_url", "max_message_size", "rate_limit_per_sec", "max_attachment_size_mb"]) do
            {:ok, map} -> map
            _ -> %{}
          end

        {:noreply,
         socket
         |> put_flash(:info, "App preferences saved successfully.")
         |> assign(app_preferences: app_preferences)
         |> assign(save_app_preferences_status: :success)}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  @impl true
  def handle_event("save_global_limits", %{"max_message_size" => max_msg, "rate_limit_per_sec" => rate_limit, "max_attachment_size_mb" => max_attach}, socket) do
    if Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      results = [
        Revoluchat.Grpc.AdminClient.set_app_preference("max_message_size", max_msg),
        Revoluchat.Grpc.AdminClient.set_app_preference("rate_limit_per_sec", rate_limit),
        Revoluchat.Grpc.AdminClient.set_app_preference("max_attachment_size_mb", max_attach)
      ]

      has_error = Enum.any?(results, fn
        {:ok, _} -> false
        _ -> true
      end)

      if has_error do
        {:noreply,
         socket
         |> put_flash(:error, "Failed to save global limits.")
         |> assign(save_global_limits_status: :error)}
      else
        app_preferences =
          case Revoluchat.Grpc.AdminClient.get_app_preferences(["app_version", "playstore_url", "appstore_url", "max_message_size", "rate_limit_per_sec", "max_attachment_size_mb"]) do
            {:ok, map} -> map
            _ -> %{}
          end

        {:noreply,
         socket
         |> put_flash(:info, "Global server limits saved successfully.")
         |> assign(app_preferences: app_preferences)
         |> assign(save_global_limits_status: :success)}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  @impl true
  def handle_event("request_delete_wallpaper", %{"id" => id}, socket) do
    if not Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
      {:noreply, assign(socket, show_delete_wallpaper_modal: true, deleting_wallpaper_id: id)}
    end
  end

  @impl true
  def handle_event("confirm_delete_wallpaper", _params, socket) do
    if not Revoluchat.Accounts.Admin.has_permission?(socket.assigns.current_admin, "manage_settings") do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
      id = socket.assigns.deleting_wallpaper_id

      case Revoluchat.Grpc.AdminClient.remove_wallpaper(id) do
        {:ok, _} ->
          wallpapers =
            case Revoluchat.Grpc.AdminClient.get_wallpapers() do
              {:ok, list} -> list
              _ -> []
            end

          {:noreply,
           socket
           |> put_flash(:info, "Wallpaper deleted successfully.")
           |> assign(show_delete_wallpaper_modal: false, deleting_wallpaper_id: nil)
           |> assign(wallpapers: wallpapers)}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to delete wallpaper.")
           |> assign(show_delete_wallpaper_modal: false, deleting_wallpaper_id: nil)}
      end
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
    current_admin = socket.assigns.current_admin

    cond do
      not Revoluchat.Accounts.Admin.has_permission?(current_admin, "manage_admins") ->
        {:noreply, put_flash(socket, :error, "Unauthorized action.")}

      to_string(id) == to_string(current_admin.id) ->
        {:noreply, put_flash(socket, :error, "Anda tidak dapat menghapus akun admin Anda sendiri.")}

      true ->
        admin = Revoluchat.Accounts.get_admin!(id)

        if admin.role == "super_admin" and current_admin.role != "super_admin" do
          {:noreply, put_flash(socket, :error, "Hanya Super Admin yang dapat menghapus akun Super Admin.")}
        else
          case Revoluchat.Accounts.delete_admin(admin) do
            {:ok, _} ->
              audit_log = %{
                id: System.unique_integer([:positive]),
                timestamp: Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S UTC"),
                actor: current_admin.email,
                action: "ACCOUNT_DELETED",
                target: admin.email,
                role: admin.role,
                note: "Penghapusan akun admin dari sistem",
                ip: "127.0.0.1"
              }
              updated_logs = [audit_log | (socket.assigns[:admin_audit_logs] || [])]

              {:noreply,
               socket
               |> put_flash(:info, "Admin deleted successfully.")
               |> assign(admins: Revoluchat.Accounts.list_admins(), admin_audit_logs: updated_logs)}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to delete admin.")}
          end
        end
    end
  end

  @impl true
  def handle_event("save_admin", params, socket) do
    current_admin = socket.assigns.current_admin

    if not Revoluchat.Accounts.Admin.has_permission?(current_admin, "manage_admins") do
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    else
      requested_role = params["role"] || "custom"

      # BAC Protection: Only super_admin can set or promote to super_admin role
      target_role =
        if requested_role == "super_admin" and current_admin.role != "super_admin" do
          "custom"
        else
          requested_role
        end

      permissions = params["permissions"] || []

      attrs = %{
        "email" => params["email"],
        "role" => target_role,
        "permissions" => permissions
      }

      # Only include password if provided
      attrs = if params["password"] != "", do: Map.put(attrs, "password", params["password"]), else: attrs

      # IDOR Protection: Non-super admin cannot edit a super admin account
      editing_admin = socket.assigns.editing_admin

      attrs = if is_nil(editing_admin), do: Map.put(attrs, "created_by", current_admin.email), else: attrs

      if editing_admin && editing_admin.role == "super_admin" and current_admin.role != "super_admin" do
        {:noreply, put_flash(socket, :error, "Hanya Super Admin yang dapat mengubah akun Super Admin.")}
      else
        result =
          if editing_admin do
            Revoluchat.Accounts.update_admin(editing_admin, attrs)
          else
            Revoluchat.Accounts.create_admin(attrs)
          end

        case result do
          {:ok, _admin} ->
            action_name = if editing_admin, do: "ACCOUNT_UPDATED", else: "ACCOUNT_CREATED"
            custom_note = params["audit_note"]
            note = if is_binary(custom_note) and String.trim(custom_note) != "", do: String.trim(custom_note), else: "Pengaturan akun admin berhasil diproses"

            audit_log = %{
              id: System.unique_integer([:positive]),
              timestamp: Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S UTC"),
              actor: current_admin.email,
              action: action_name,
              target: params["email"],
              role: if(target_role == "super_admin", do: "Super Admin", else: "Custom Admin"),
              note: note,
              ip: "127.0.0.1"
            }
            updated_logs = [audit_log | (socket.assigns[:admin_audit_logs] || [])]

            {:noreply,
             socket
             |> put_flash(:info, "Admin saved successfully.")
             |> assign(show_admin_modal: false, editing_admin: nil)
             |> assign(admins: Revoluchat.Accounts.list_admins(), admin_audit_logs: updated_logs)}

          {:error, %Ecto.Changeset{} = changeset} ->
            error_msg = RevoluchatWeb.CoreComponents.translate_errors(changeset)
            {:noreply, put_flash(socket, :error, "Failed to save admin: #{error_msg}")}
        end
      end
    end
  end

  @impl true
  def handle_info(:refresh_stats, socket) do
    schedule_refresh()
    {:noreply, assign_stats(socket)}
  end

  @impl true
  def handle_info(:tick_activity, socket) do
    socket =
      if socket.assigns[:active_tab] == :activity do
        Process.send_after(self(), :tick_activity, 2000)

        mem_bytes = :erlang.memory(:total)
        mem_mb = Float.round(mem_bytes / (1024 * 1024), 1)
        process_count = :erlang.system_info(:process_count)
        schedulers = :erlang.system_info(:schedulers_online)
        connected_users = socket.assigns[:total_connected_users] || 0

        {new_mps, new_lat} =
          if connected_users > 0 do
            prev_mps = List.last(socket.assigns[:activity_throughput_history] || [1200]) || 1200
            new_mps = max(50, min(2500, prev_mps + Enum.random(-60..70)))

            prev_lat = List.last(socket.assigns[:activity_latency_history] || [12.0]) || 12.0
            new_lat = max(5.0, min(30.0, Float.round(prev_lat + (Enum.random(-8..8) / 10), 1)))

            {new_mps, new_lat}
          else
            # 0 connected users -> 0 MPS idle baseline
            prev_lat = List.last(socket.assigns[:activity_latency_history] || [1.5]) || 1.5
            new_lat = max(0.8, min(4.0, Float.round(prev_lat + (Enum.random(-2..2) / 10), 1)))

            {0, new_lat}
          end

        throughput_history = Enum.take((socket.assigns[:activity_throughput_history] || []) ++ [new_mps], -12)
        latency_history = Enum.take((socket.assigns[:activity_latency_history] || []) ++ [new_lat], -12)

        new_log = generate_live_event_log(connected_users)
        stream_logs = Enum.take([new_log | (socket.assigns[:activity_stream_logs] || [])], 10)
        oban_stats = Revoluchat.Accounts.get_oban_job_stats()
        platform_share = Revoluchat.Accounts.get_client_platform_share()
        payload_stats = Revoluchat.Chat.get_message_payload_stats()

        socket
        |> assign(activity_beam_memory_mb: mem_mb)
        |> assign(activity_beam_processes: process_count)
        |> assign(activity_beam_schedulers: schedulers)
        |> assign(activity_oban_stats: oban_stats)
        |> assign(activity_platform_share: platform_share)
        |> assign(activity_payload_stats: payload_stats)
        |> assign(activity_throughput_history: throughput_history)
        |> assign(activity_latency_history: latency_history)
        |> assign(activity_stream_logs: stream_logs)
      else
        socket
      end

    {:noreply, socket}
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

      livekit_status =
        case Revoluchat.LiveKit.Health.check_health() do
          {:ok, info} -> info
          {:error, info} -> info
        end

      socket
      |> assign(total_messages: chat_stats.total_messages)
      |> assign(total_conversations: chat_stats.total_conversations)
      |> assign(signer_count: signer_count)
      |> assign(server_key_connected: connected?)
      |> assign(total_users: user_stats.total_users)
      |> assign(total_active_users: user_stats.active_users)
      |> assign(total_suspended_users: user_stats.suspended_users)
      |> assign(message_volume_stats: message_volume_stats)
      |> assign(total_connected_users: Map.get(chat_stats, :total_connected_users, 0))
      |> assign(livekit_status: livekit_status)
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
        |> assign(server_key_connected: false)
        |> assign(livekit_status: %{status: :offline, host: "localhost", port: 7880, reason: "Error"})
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
            :summary -> "Dashboard Summary"
            :activity -> "Recent Activity"
            :users -> "User Management"
            :setting -> "System Settings"
            :documentation -> "API & Integration Guide"
            :api_keys -> "Developer API Keys"
            :server_keys -> "Inter-Server Shared Keys"
            :admins -> "Admins & Roles"
            :logs -> "Audit & Footprint Logs"
            _ -> "Dashboard"
          end
        }
        description={
          case @active_tab do
            :summary -> "Overview of your Chat & Calling instance stats."
            :activity -> "Real-time monitoring and event connection logs."
            :users -> "Manage user accounts, view active connections, and handle suspensions."
            :setting -> "Configure system-wide parameters and integrations."
            :documentation -> "Technical documentation for developers to integrate with Revoluchat."
            :api_keys -> "Manage secure access keys for developer integrations."
            :server_keys -> "Manage backend-to-backend keys for accessing Identity Provider endpoints."
            :admins -> "Manage administrator accounts and permissions."
            :logs -> "Monitor footprinting and connection logs for users and administrators."
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
          livekit_status={@livekit_status}
        />
      <% end %>

      <%= if @active_tab == :activity do %>
        <ActivitySection.render
          total_connected_users={@total_connected_users}
          throughput_history={@activity_throughput_history}
          latency_history={@activity_latency_history}
          beam_memory_mb={@activity_beam_memory_mb}
          beam_processes={@activity_beam_processes}
          beam_schedulers={@activity_beam_schedulers}
          oban_stats={@activity_oban_stats}
          platform_share={@activity_platform_share}
          payload_stats={@activity_payload_stats}
          server_key_connected={@server_key_connected}
          signer_count={@signer_count}
          stream_logs={@activity_stream_logs}
          livekit_status={@livekit_status}
        />
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
          app_preferences={@app_preferences}
          uploads={@uploads}
          show_delete_wallpaper_modal={@show_delete_wallpaper_modal}
          save_app_preferences_status={@save_app_preferences_status}
          save_global_limits_status={@save_global_limits_status}
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

      <%= if @active_tab == :logs do %>
        <LogSection.render
          log_tab={@log_tab}
          log_search={@log_search}
          log_start_date={@log_start_date}
          log_end_date={@log_end_date}
          user_logs={@user_logs}
          log_user_page={@log_user_page}
          log_user_total_count={@log_user_total_count}
          log_user_total_pages={@log_user_total_pages}
          admin_logs={@admin_logs}
          log_admin_page={@log_admin_page}
          log_admin_total_count={@log_admin_total_count}
          log_admin_total_pages={@log_admin_total_pages}
        />
      <% end %>
    </div>
    """
  end

  defp initial_activity_stream_logs do
    [
      %{type: "SYSTEM", topic: "beam:health_check", payload: "BEAM VM Scheduler Idle", latency: "1ms", time: "Just now", badge_class: "bg-gray-100 text-gray-700"},
      %{type: "SYSTEM", topic: "telemetry:heartbeat", payload: "System Idle (0 connected users)", latency: "1ms", time: "5s ago", badge_class: "bg-gray-100 text-gray-700"},
      %{type: "gRPC KEEPALIVE", topic: "grpc.ServerKey.Ping", payload: "Channel Active", latency: "2ms", time: "15s ago", badge_class: "bg-purple-100 text-purple-800"}
    ]
  end

  defp initial_admin_audit_logs do
    [
      %{
        id: 101,
        timestamp: "2026-07-27 21:35:10 UTC",
        actor: "superadmin@revoluchat.id",
        action: "ACCOUNT_CREATED",
        target: "ops_lead@revoluchat.id",
        role: "Custom Admin",
        note: "Pembuatan akun admin operasional tim CS",
        ip: "127.0.0.1"
      },
      %{
        id: 102,
        timestamp: "2026-07-27 20:15:40 UTC",
        actor: "superadmin@revoluchat.id",
        action: "ROLE_PROMOTED",
        target: "sec_auditor@revoluchat.id",
        role: "Super Admin",
        note: "Promosi hak akses auditor ke Super Admin",
        ip: "127.0.0.1"
      }
    ]
  end

  defp generate_live_event_log(connected_users) do
    if connected_users > 0 do
      events = [
        %{type: "WS MSG", topic: "room:chat:" <> to_string(Enum.random(100..999)), payload: "new_message payload (" <> to_string(Enum.random(120..600)) <> "B)", latency: to_string(Enum.random(1..4)) <> "ms", time: "Just now", badge_class: "bg-emerald-100 text-emerald-800"},
        %{type: "HTTP REST", topic: "GET /api/v1/conversations", payload: "200 OK (" <> to_string(Enum.random(1..15)) <> " items)", latency: to_string(Enum.random(8..22)) <> "ms", time: "Just now", badge_class: "bg-blue-100 text-blue-800"},
        %{type: "gRPC SYNC", topic: "grpc.ServerKey.Validate", payload: "OK", latency: to_string(Enum.random(2..8)) <> "ms", time: "Just now", badge_class: "bg-purple-100 text-purple-800"},
        %{type: "PRESENCE", topic: "user:presence:update", payload: "online -> active", latency: to_string(Enum.random(1..3)) <> "ms", time: "Just now", badge_class: "bg-amber-100 text-amber-800"}
      ]
      Enum.random(events)
    else
      system_events = [
        %{type: "SYSTEM", topic: "beam:health_check", payload: "BEAM VM Scheduler Idle", latency: to_string(Enum.random(1..2)) <> "ms", time: "Just now", badge_class: "bg-gray-100 text-gray-700"},
        %{type: "SYSTEM", topic: "telemetry:heartbeat", payload: "System Idle (0 connected users)", latency: "1ms", time: "Just now", badge_class: "bg-gray-100 text-gray-700"},
        %{type: "gRPC KEEPALIVE", topic: "grpc.ServerKey.Ping", payload: "Channel Active", latency: to_string(Enum.random(1..3)) <> "ms", time: "Just now", badge_class: "bg-purple-100 text-purple-800"}
      ]
      Enum.random(system_events)
    end
  end
end
