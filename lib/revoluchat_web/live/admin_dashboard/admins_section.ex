defmodule RevoluchatWeb.AdminDashboardLive.AdminsSection do
  use RevoluchatWeb, :component

  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <div class="w-full space-y-8 pb-20">
      <.card>
        <div class="px-4 py-5 sm:px-6 flex justify-between items-center border-b border-gray-200">
          <div>
            <h3 class="text-lg leading-6 font-medium text-gray-900">Admin Management</h3>
            <p class="mt-1 max-w-2xl text-sm text-gray-500">Manage administrator accounts and their roles.</p>
          </div>
          <button
            type="button"
            phx-click="open_admin_modal"
            class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            Add New Admin
          </button>
        </div>

        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead>
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Role</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Permissions</th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for admin <- @admins do %>
                <tr>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 border-b-0"><%= admin.email %></td>
                  <td class="px-6 py-4 text-sm text-gray-500 border-b-0">
                    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium " <> if admin.role == "super_admin", do: "bg-purple-100 text-purple-800", else: "bg-green-100 text-green-800"}>
                      <%= admin.role %>
                    </span>
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-500 border-b-0">
                    <%= if admin.role == "super_admin" do %>
                      <span class="text-gray-400 italic">All Access</span>
                    <% else %>
                      <div class="flex flex-wrap gap-1">
                        <%= for perm <- (admin.permissions || []) do %>
                          <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800">
                            <%= perm %>
                          </span>
                        <% end %>
                      </div>
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium border-b-0">
                    <button
                      type="button"
                      phx-click="edit_admin"
                      phx-value-id={admin.id}
                      class="text-indigo-600 hover:text-indigo-900 mr-4"
                    >
                      Edit
                    </button>
                    <%= if admin.id != @current_admin.id do %>
                      <button
                        type="button"
                        phx-click="delete_admin"
                        phx-value-id={admin.id}
                        data-confirm="Are you sure you want to delete this admin?"
                        class="text-red-600 hover:text-red-900"
                      >
                        Delete
                      </button>
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
        <div class="relative z-10" aria-labelledby="modal-title" role="dialog" aria-modal="true">
          <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
          <div class="fixed inset-0 z-10 w-screen overflow-y-auto">
            <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
              <div class="relative transform overflow-hidden rounded-lg bg-white text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg">
                <form phx-submit="save_admin">
                  <div class="bg-white px-4 pb-4 pt-5 sm:p-6 sm:pb-4">
                    <div class="sm:flex sm:items-start">
                      <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left w-full">
                        <h3 class="text-base font-semibold leading-6 text-gray-900" id="modal-title">
                          <%= if @editing_admin, do: "Edit Admin", else: "Add New Admin" %>
                        </h3>
                        <div class="mt-4 space-y-4">
                          <div>
                            <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
                            <input
                              type="email"
                              name="email"
                              value={if @editing_admin, do: @editing_admin.email, else: ""}
                              required
                              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                            />
                          </div>
                          <div>
                            <label class="block text-sm font-medium text-gray-700 mb-1">
                              Password <%= if @editing_admin, do: "(Leave blank to keep current)" %>
                            </label>
                            <input
                              type="password"
                              name="password"
                              {if !@editing_admin, do: [required: true], else: []}
                              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                            />
                          </div>
                          <div>
                            <label class="block text-sm font-medium text-gray-700 mb-1">Role</label>
                            <select name="role" class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm">
                              <option value="custom" selected={if @editing_admin, do: @editing_admin.role == "custom", else: true}>Custom</option>
                              <option value="super_admin" selected={if @editing_admin, do: @editing_admin.role == "super_admin", else: false}>Super Admin</option>
                            </select>
                          </div>
                          
                          <div>
                            <label class="block text-sm font-medium text-gray-700 mb-2">Permissions</label>
                            <div class="space-y-2">
                              <% permissions = if @editing_admin, do: @editing_admin.permissions || [], else: [] %>
                              <label class="flex items-center">
                                <input type="checkbox" name="permissions[]" value="view_dashboard" checked={"view_dashboard" in permissions} class="rounded border-gray-300 text-indigo-600 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50">
                                <span class="ml-2 text-sm text-gray-600">View Dashboard (Summary & Activity)</span>
                              </label>
                              <label class="flex items-center">
                                <input type="checkbox" name="permissions[]" value="manage_users" checked={"manage_users" in permissions} class="rounded border-gray-300 text-indigo-600 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50">
                                <span class="ml-2 text-sm text-gray-600">Manage Users</span>
                              </label>
                              <label class="flex items-center">
                                <input type="checkbox" name="permissions[]" value="manage_settings" checked={"manage_settings" in permissions} class="rounded border-gray-300 text-indigo-600 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50">
                                <span class="ml-2 text-sm text-gray-600">Manage Settings & Keys</span>
                              </label>
                              <label class="flex items-center">
                                <input type="checkbox" name="permissions[]" value="manage_admins" checked={"manage_admins" in permissions} class="rounded border-gray-300 text-indigo-600 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50">
                                <span class="ml-2 text-sm text-gray-600">Manage Admins</span>
                              </label>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                  <div class="bg-gray-50 px-4 py-3 sm:flex sm:flex-row-reverse sm:px-6">
                    <button type="submit" class="inline-flex w-full justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 sm:ml-3 sm:w-auto">Save</button>
                    <button type="button" phx-click="close_admin_modal" class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:mt-0 sm:w-auto">Cancel</button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
