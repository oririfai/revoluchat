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
    UserSection
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
     |> assign(user_connection_error: nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    Logger.info(
      "Handling params: #{inspect(params)}, action: #{inspect(socket.assigns.live_action)}"
    )

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :summary, _params) do
    socket |> assign(active_tab: :summary) |> assign(page_title: "Summary")
  end

  defp apply_action(socket, :activity, _params) do
    socket |> assign(active_tab: :activity) |> assign(page_title: "Activity")
  end

  defp apply_action(socket, :users, _params) do
    socket
    |> assign(active_tab: :users)
    |> assign(page_title: "Users")
    |> assign(user_page: 1)
    |> assign(user_search: "")
    |> assign_users()
  end

  defp apply_action(socket, :setting, _params) do
    socket |> assign(active_tab: :setting) |> assign(page_title: "Settings")
  end

  defp apply_action(socket, :documentation, _params) do
    socket |> assign(active_tab: :documentation) |> assign(page_title: "Documentation")
  end

  defp apply_action(socket, :api_keys, _params) do
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
  end

  defp apply_action(socket, :server_keys, _params) do
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

      socket
      |> assign(total_messages: Repo.aggregate(Revoluchat.Chat.Message, :count, :id) || 0)
      |> assign(
        total_conversations: Repo.aggregate(Revoluchat.Chat.Conversation, :count, :id) || 0
      )
      |> assign(signer_count: signer_count)
    rescue
      e ->
        Logger.error("Error fetching stats: #{inspect(e)}")

        socket
        |> assign(total_messages: 0)
        |> assign(total_conversations: 0)
        |> assign(signer_count: 0)
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
        <SettingSection.render />
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
    </div>
    """
  end
end
