defmodule RevoluchatWeb.AdminDashboardLive.UserSection do
  use RevoluchatWeb, :component

  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= if assigns[:connection_error] do %>
        <div class="rounded-md bg-red-50 p-4 border border-red-200">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div class="flex">
              <div class="flex-shrink-0 mt-0.5">
                <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path fill-rule="evenodd" d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-red-800">
                  Koneksi Server Gagal
                </h3>
                <div class="mt-1 text-sm text-red-700">
                  <p>
                    <%= @connection_error %>. Pastikan server backend sedang berjalan dan dapat diakses.
                  </p>
                </div>
              </div>
            </div>
            <div class="flex-shrink-0 sm:ml-6">
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="server_keys"
                class="inline-flex items-center px-4 py-2 border border-red-300 shadow-sm text-xs font-semibold rounded-md text-red-700 bg-white hover:bg-red-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition-all duration-200"
              >
                View Connection
              </button>
            </div>
          </div>
        </div>
      <% end %>

      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div class="flex flex-col sm:flex-row sm:items-center gap-4 w-full">
          <div class="relative max-w-sm w-full">
            <form phx-submit="search_users" phx-change="search_users" class="relative">
              <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <.icon name="hero-magnifying-glass" class="h-5 w-5 text-gray-400" />
              </div>
              <input
                type="text"
                name="search"
                value={@search}
                placeholder="Search by name, phone, or UUID..."
                phx-debounce="300"
                class="block w-full rounded-md border-gray-300 pl-10 focus:border-primary-500 focus:ring-primary-500 sm:text-sm"
              />
            </form>
          </div>
          <div class="w-full sm:w-48">
            <form phx-change="filter_status">
              <select
                name="status"
                class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm"
              >
                <option value="all" selected={@status == "all"}>All Statuses</option>
                <option value="active" selected={@status == "active"}>Active</option>
                <option value="suspended" selected={@status == "suspended"}>Inactive</option>
              </select>
            </form>
          </div>
        </div>
      </div>

      <.card label="User Accounts">
        <div class="overflow-x-auto overflow-y-auto max-h-[calc(100vh-320px)] border-b border-gray-200">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50 sticky top-0 z-10 shadow-sm">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Phone</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Joined At</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">KYC Status</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for user <- @users do %>
                <tr class="hover:bg-gray-50/50 transition-colors">
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 border-b-0">
                    <div class="flex items-center gap-2">
                      <div class="h-8 w-8 rounded-full bg-primary-100 flex items-center justify-center text-primary-700 font-bold text-xs">
                        <%= String.slice(user.name || "U", 0, 2) |> String.upcase() %>
                      </div>
                      <div>
                        <div class="font-semibold text-gray-900"><%= user.name %></div>
                        <div class="text-xs text-gray-400 font-mono"><%= user.uuid %></div>
                      </div>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-600 border-b-0 font-mono"><%= user.phone %></td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 border-b-0"><%= format_date(user.inserted_at) %></td>
                  <td class="px-6 py-4 whitespace-nowrap border-b-0">
                    <span class={[
                      "px-2 inline-flex text-xs leading-5 font-semibold rounded-full",
                      if(user.is_kyc, do: "bg-green-100 text-green-800", else: "bg-gray-100 text-gray-800")
                    ]}>
                      <%= if user.is_kyc, do: "Verified", else: "Unverified" %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap border-b-0">
                    <span class={[
                      "px-2 inline-flex text-xs leading-5 font-semibold rounded-full",
                      if(user.status == "active", do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800")
                    ]}>
                      <%= String.capitalize(user.status || "inactive") %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium border-b-0 space-x-2">
                    <.revolu_button
                      variant="ghost"
                      size="xs"
                      phx-click="view_user_detail"
                      phx-value-id={user.id}
                      class="text-primary-600 hover:bg-primary-50"
                    >
                      Detail
                    </.revolu_button>

                    <%= if user.status == "active" do %>
                      <.revolu_button
                        variant="ghost"
                        size="xs"
                        phx-click="open_suspend_modal"
                        phx-value-id={user.id}
                        class="text-red-600 hover:bg-red-50"
                      >
                        Suspend
                      </.revolu_button>
                    <% else %>
                      <.revolu_button
                        variant="ghost"
                        size="xs"
                        phx-click="open_unsuspend_modal"
                        phx-value-id={user.id}
                        class="text-green-600 hover:bg-green-50"
                      >
                        Unsuspend
                      </.revolu_button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
              <%= if Enum.empty?(@users) do %>
                <tr>
                  <td colspan="6" class="px-6 py-10 text-center text-sm text-gray-400 italic">
                    No users found matching your search.
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <!-- Pagination -->
        <%= if @total_count > 0 do %>
          <div class="flex items-center justify-between border-t border-gray-200 bg-white px-4 py-3 sm:px-6 mt-4">
            <div class="flex flex-1 justify-between sm:hidden">
              <button
                phx-click="change_page"
                phx-value-page={@page - 1}
                disabled={@page <= 1}
                class="relative inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
              >
                Previous
              </button>
              <button
                phx-click="change_page"
                phx-value-page={@page + 1}
                disabled={@page >= @total_pages}
                class="relative ml-3 inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
              >
                Next
              </button>
            </div>
            <div class="hidden sm:flex sm:flex-1 sm:items-center sm:justify-between">
              <div>
                <p class="text-sm text-gray-700">
                  Showing
                  <span class="font-medium"><%= max((@page - 1) * 10 + 1, 1) %></span>
                  to
                  <span class="font-medium"><%= min(@page * 10, @total_count) %></span>
                  of
                  <span class="font-medium"><%= @total_count %></span>
                  users
                </p>
              </div>
              <div>
                <nav class="isolate inline-flex -space-x-px rounded-md shadow-sm" aria-label="Pagination">
                  <button
                    phx-click="change_page"
                    phx-value-page={@page - 1}
                    disabled={@page <= 1}
                    class="relative inline-flex items-center rounded-l-md px-2 py-2 text-gray-400 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20 focus:outline-offset-0 disabled:opacity-50"
                  >
                    <span class="sr-only">Previous</span>
                    <.icon name="hero-chevron-left" class="h-5 w-5" />
                  </button>

                  <%= for p <- 1..@total_pages do %>
                    <button
                      phx-click="change_page"
                      phx-value-page={p}
                      class={[
                        "relative inline-flex items-center px-4 py-2 text-sm font-semibold focus:z-20 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2",
                        if(p == @page,
                          do: "z-10 bg-primary-600 text-white focus-visible:outline-primary-600",
                          else: "text-gray-900 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:outline-offset-0"
                        )
                      ]}
                    >
                      <%= p %>
                    </button>
                  <% end %>

                  <button
                    phx-click="change_page"
                    phx-value-page={@page + 1}
                    disabled={@page >= @total_pages}
                    class="relative inline-flex items-center rounded-r-md px-2 py-2 text-gray-400 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20 focus:outline-offset-0 disabled:opacity-50"
                  >
                    <span class="sr-only">Next</span>
                    <.icon name="hero-chevron-right" class="h-5 w-5" />
                  </button>
                </nav>
              </div>
            </div>
          </div>
        <% end %>
      </.card>
    </div>

    <!-- User Detail Modal -->
    <.modal
      :if={@show_detail && @selected_user}
      id="user-detail-modal"
      show={@show_detail}
      on_cancel={JS.push("close_user_modal")}
      title="User Account Details"
      type="info"
    >
      <div class="space-y-4">
        <div class="grid grid-cols-3 gap-y-3 gap-x-2 text-sm border-b pb-4">
          <div class="font-medium text-gray-500">Name</div>
          <div class="col-span-2 text-gray-900 font-semibold"><%= @selected_user.name %></div>

          <div class="font-medium text-gray-500">Phone Number</div>
          <div class="col-span-2 text-gray-900 font-mono"><%= @selected_user.phone %></div>

          <div class="font-medium text-gray-500">User UUID</div>
          <div class="col-span-2 text-gray-900 font-mono text-xs select-all"><%= @selected_user.uuid %></div>

          <div class="font-medium text-gray-500">Joined Date</div>
          <div class="col-span-2 text-gray-900"><%= format_date(@selected_user.inserted_at) %></div>

          <div class="font-medium text-gray-500">KYC Status</div>
          <div class="col-span-2">
            <span class={[
              "px-2 inline-flex text-xs leading-5 font-semibold rounded-full",
              if(@selected_user.is_kyc, do: "bg-green-100 text-green-800", else: "bg-gray-100 text-gray-800")
            ]}>
              <%= if @selected_user.is_kyc, do: "Verified", else: "Not Verified" %>
            </span>
          </div>

          <div class="font-medium text-gray-500">Account Status</div>
          <div class="col-span-2">
            <span class={[
              "px-2 inline-flex text-xs leading-5 font-semibold rounded-full",
              if(@selected_user.status == "active", do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800")
            ]}>
              <%= String.capitalize(@selected_user.status || "inactive") %>
            </span>
          </div>
        </div>
      </div>
      <:footer>
        <.revolu_button phx-click="close_user_modal" variant="white">Close</.revolu_button>
      </:footer>
    </.modal>

    <!-- Suspend Modal -->
    <.modal
      :if={@show_suspend && @selected_user}
      id="suspend-user-modal"
      show={@show_suspend}
      on_cancel={JS.push("close_user_modal")}
      title="Suspend User Account"
      type="danger"
    >
      <form phx-submit="confirm_suspend">
        <input type="hidden" name="id" value={@selected_user.uuid} />
        <div class="space-y-4">
          <p class="text-sm text-gray-600">
            You are about to suspend <strong><%= @selected_user.name %></strong>. Suspended users will be immediately disconnected and blocked from logging in, sending messages, or making calls.
          </p>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Suspension Duration</label>
            <select name="duration" class="block w-full rounded-md border-gray-300 shadow-sm focus:border-red-500 focus:ring-red-500 sm:text-sm">
              <option value="1_hour">1 Hour</option>
              <option value="12_hours">12 Hours</option>
              <option value="1_day">1 Day</option>
              <option value="1_week">1 Week</option>
              <option value="permanent" selected>Permanent</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Reason for Suspension</label>
            <textarea
              name="reason"
              rows="3"
              required
              placeholder="e.g. Terms of service violation, abusive behavior..."
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-red-500 focus:ring-red-500 sm:text-sm"
            ></textarea>
          </div>
        </div>
        <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse gap-3">
          <.revolu_button type="submit" variant="solid" class="bg-red-600 hover:bg-red-700">
            Confirm Suspend
          </.revolu_button>
          <.revolu_button type="button" phx-click="close_user_modal" variant="white">Cancel</.revolu_button>
        </div>
      </form>
    </.modal>

    <!-- Unsuspend Confirmation Modal -->
    <.modal
      :if={@show_unsuspend && @selected_user}
      id="unsuspend-user-modal"
      show={@show_unsuspend}
      on_cancel={JS.push("close_user_modal")}
      title="Unsuspend User Account"
      type="info"
    >
      <div class="space-y-4">
        <p class="text-sm text-gray-600">
          Are you sure you want to unsuspend <strong><%= @selected_user.name %></strong>? Their account status will be restored to active and they will be able to log in, send messages, and make calls immediately.
        </p>
      </div>
      <:footer>
        <.revolu_button phx-click="close_user_modal" variant="white">Cancel</.revolu_button>
        <.revolu_button
          phx-click="confirm_unsuspend"
          phx-value-id={@selected_user.uuid}
          variant="solid"
          class="bg-green-600 hover:bg-green-700"
        >
          Confirm Unsuspend
        </.revolu_button>
      </:footer>
    </.modal>
    """
  end

  defp format_date(nil), do: "-"

  defp format_date(date_str) when is_binary(date_str) do
    case DateTime.from_iso8601(date_str) do
      {:ok, datetime, _offset} ->
        datetime
        |> DateTime.add(7 * 3600, :second)
        |> Calendar.strftime("%Y-%m-%d %H:%M:%S")

      _ ->
        case NaiveDateTime.from_iso8601(date_str) do
          {:ok, naive} ->
            naive
            |> NaiveDateTime.add(7 * 3600, :second)
            |> Calendar.strftime("%Y-%m-%d %H:%M:%S")

          _ ->
            date_str
        end
    end
  end
end
