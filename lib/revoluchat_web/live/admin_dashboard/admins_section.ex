defmodule RevoluchatWeb.AdminDashboardLive.AdminsSection do
  use RevoluchatWeb, :component

  alias Phoenix.LiveView.JS

  attr :admins, :list, default: []
  attr :show_admin_modal, :boolean, default: false
  attr :editing_admin, :any, default: nil
  attr :current_admin, :any, default: nil

  def render(assigns) do
    ~H"""
    <div class="w-full space-y-6 pb-20">
      <!-- 1. Admin Management Table -->
      <.card label="Admin Management & Access Control Roles">
        <div class="px-4 py-5 sm:px-6 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 border-b border-gray-200">
          <div>
            <h3 class="text-base font-bold text-gray-900">Registered Administrator Accounts</h3>
          </div>
          <.revolu_button
            type="button"
            phx-click="open_admin_modal"
            variant="solid"
          >
            Add New Admin
          </.revolu_button>
        </div>

        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Admin Email</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Role</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Assigned Permissions</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Created By</th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for admin <- @admins do %>
                <tr class="hover:bg-gray-50/50 transition-colors">
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-semibold text-gray-900 border-b-0">
                    <div class="flex items-center gap-3">
                      <div class="h-8 w-8 rounded-full bg-indigo-100 text-indigo-700 font-bold flex items-center justify-center text-xs">
                        <%= String.upcase(String.slice(admin.email, 0, 2)) %>
                      </div>
                      <div>
                        <div class="text-gray-900"><%= admin.email %></div>
                        <%= if admin.id == @current_admin.id do %>
                          <span class="text-[10px] font-bold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded border border-emerald-200">Active Session</span>
                        <% end %>
                      </div>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm border-b-0">
                    <span class={[
                      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold",
                      if(admin.role == "super_admin", do: "bg-purple-100 text-purple-800", else: "bg-blue-100 text-blue-800")
                    ]}>
                      <%= if admin.role == "super_admin", do: "Super Admin", else: "Custom Admin" %>
                    </span>
                  </td>
                  <td class="px-6 py-4 text-sm border-b-0">
                    <%= if admin.role == "super_admin" do %>
                      <span class="inline-flex items-center text-xs font-semibold text-purple-700 bg-purple-50 px-2.5 py-1 rounded border border-purple-200/60">
                        All Permissions (Full Access)
                      </span>
                    <% else %>
                      <div class="flex flex-wrap gap-1.5">
                        <%= for perm <- (admin.permissions || []) do %>
                          <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800">
                            <%= perm %>
                          </span>
                        <% end %>
                        <%= if Enum.empty?(admin.permissions || []) do %>
                          <span class="text-gray-400 italic text-xs">No explicit permissions</span>
                        <% end %>
                      </div>
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-600 border-b-0 font-medium">
                    <%= admin.created_by || "System" %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium border-b-0 space-x-2">
                    <.revolu_button
                      variant="ghost"
                      size="xs"
                      phx-click="edit_admin"
                      phx-value-id={admin.id}
                    >
                      Edit
                    </.revolu_button>
                    <%= if admin.id != @current_admin.id do %>
                      <.revolu_button
                        variant="ghost"
                        size="xs"
                        phx-click="delete_admin"
                        phx-value-id={admin.id}
                        data-confirm="Apakah Anda yakin ingin menghapus akun admin ini?"
                        class="text-red-600 hover:text-red-700 hover:bg-red-50"
                      >
                        Delete
                      </.revolu_button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </.card>

      <!-- Add / Edit Admin Modal -->
      <%= if @show_admin_modal do %>
        <.modal
          id="admin-modal"
          show={@show_admin_modal}
          title={if @editing_admin, do: "Edit Admin Account & Permissions", else: "Create New Admin Account"}
          on_cancel={JS.push("close_admin_modal")}
          max_width="md"
        >
          <form phx-submit="save_admin" class="space-y-4">
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">Email Address</label>
              <input
                type="email"
                name="email"
                value={if @editing_admin, do: @editing_admin.email, else: ""}
                placeholder="admin@revoluchat.id"
                required
                class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm"
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Password <%= if @editing_admin, do: "(Kosongkan jika tidak ingin merubah)" %>
              </label>
              <input
                type="password"
                name="password"
                placeholder="••••••••••••"
                {if !@editing_admin, do: [required: true], else: []}
                class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm"
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">Admin Role</label>
              <select name="role" class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm">
                <option value="custom" selected={if @editing_admin, do: @editing_admin.role == "custom", else: true}>Custom Admin (Granular Permissions)</option>
                <option value="super_admin" selected={if @editing_admin, do: @editing_admin.role == "super_admin", else: false}>Super Admin (Full Access)</option>
              </select>
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-2">Granular Permissions</label>
              <div class="space-y-2 bg-gray-50 p-3 rounded-md border border-gray-200">
                <% permissions = if @editing_admin, do: @editing_admin.permissions || [], else: [] %>
                <label class="flex items-center cursor-pointer">
                  <input type="checkbox" name="permissions[]" value="view_dashboard" checked={"view_dashboard" in permissions} class="rounded border-gray-300 text-primary-600 shadow-sm focus:ring-primary-500">
                  <span class="ml-2 text-xs text-gray-700 font-medium">View Dashboard (Summary & Activity)</span>
                </label>
                <label class="flex items-center cursor-pointer">
                  <input type="checkbox" name="permissions[]" value="manage_users" checked={"manage_users" in permissions} class="rounded border-gray-300 text-primary-600 shadow-sm focus:ring-primary-500">
                  <span class="ml-2 text-xs text-gray-700 font-medium">Manage Users</span>
                </label>
                <label class="flex items-center cursor-pointer">
                  <input type="checkbox" name="permissions[]" value="manage_settings" checked={"manage_settings" in permissions} class="rounded border-gray-300 text-primary-600 shadow-sm focus:ring-primary-500">
                  <span class="ml-2 text-xs text-gray-700 font-medium">Manage Settings & Keys</span>
                </label>
                <label class="flex items-center cursor-pointer">
                  <input type="checkbox" name="permissions[]" value="manage_admins" checked={"manage_admins" in permissions} class="rounded border-gray-300 text-primary-600 shadow-sm focus:ring-primary-500">
                  <span class="ml-2 text-xs text-gray-700 font-medium">Manage Admins & Security Rules (<code class="text-indigo-600 font-semibold">manage_admins</code>)</span>
                </label>
                <label class="flex items-center cursor-pointer">
                  <input type="checkbox" name="permissions[]" value="view_logs" checked={"view_logs" in permissions} class="rounded border-gray-300 text-primary-600 shadow-sm focus:ring-primary-500">
                  <span class="ml-2 text-xs text-gray-700 font-medium">Access Audit & Footprint Logs (<code class="text-indigo-600 font-semibold">view_logs</code>)</span>
                </label>
              </div>
            </div>

            <!-- Audit Log Note -->
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">Catatan Audit / Alasan Pembuatan Akun</label>
              <input
                type="text"
                name="audit_note"
                placeholder="Contoh: Pembuatan akun admin operasional tim CS"
                class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm"
              />
            </div>

            <div class="mt-6 flex justify-end gap-3 pt-4 border-t border-gray-100">
              <.revolu_button type="submit" variant="solid">
                Save Account & Log Audit
              </.revolu_button>
              <.revolu_button type="button" phx-click={hide_dashboard_modal("admin-modal") |> JS.push("close_admin_modal")} variant="white">Cancel</.revolu_button>
            </div>
          </form>
        </.modal>
      <% end %>
    </div>
    """
  end
end
