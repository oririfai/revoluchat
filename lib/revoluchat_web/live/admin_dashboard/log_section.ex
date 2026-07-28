defmodule RevoluchatWeb.AdminDashboardLive.LogSection do
  use RevoluchatWeb, :component

  def render(assigns) do
    ~H"""
    <div class="w-full space-y-6">
      <!-- Filters (Backend Search Query & Date Range) -->
      <div class="bg-white p-3.5 rounded-xl border border-gray-200/80 shadow-sm">
        <form phx-change="filter_logs" phx-submit="filter_logs" class="flex flex-row items-center justify-between gap-4 w-full">
          <!-- Search Bar -->
          <div class="relative flex-1 min-w-[200px]">
            <div class="absolute left-3 top-1/2 -translate-y-1/2 flex items-center pointer-events-none z-10">
              <.icon name="hero-magnifying-glass" class="h-4 w-4 text-gray-400" />
            </div>
            <input
              type="text"
              name="search"
              value={@log_search}
              placeholder={if to_string(@log_tab) == "user", do: "Cari nama, nomor HP, IP, User Agent...", else: "Cari nama, email, IP, User Agent..."}
              phx-debounce="300"
              class="block w-full rounded-lg border border-gray-300 pl-9 pr-3 py-1.5 text-sm focus:border-primary-500 focus:ring-primary-500"
            />
          </div>

          <!-- Date Filters (Inline beside search bar) -->
          <div class="flex items-center gap-3 shrink-0">
            <div class="flex items-center gap-2">
              <span class="text-xs font-medium text-gray-500 whitespace-nowrap">Dari:</span>
              <input
                type="date"
                name="start_date"
                value={@log_start_date}
                class="rounded-lg border border-gray-300 py-1.5 px-2.5 text-sm focus:border-primary-500 focus:ring-primary-500"
              />
            </div>

            <div class="flex items-center gap-2">
              <span class="text-xs font-medium text-gray-500 whitespace-nowrap">Sampai:</span>
              <input
                type="date"
                name="end_date"
                value={@log_end_date}
                class="rounded-lg border border-gray-300 py-1.5 px-2.5 text-sm focus:border-primary-500 focus:ring-primary-500"
              />
            </div>

            <%= if (@log_search != "" and not is_nil(@log_search)) or (@log_start_date != "" and not is_nil(@log_start_date)) or (@log_end_date != "" and not is_nil(@log_end_date)) do %>
              <button
                type="button"
                phx-click="reset_log_filters"
                class="inline-flex items-center gap-1.5 px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-lg text-gray-700 bg-white hover:bg-gray-50 transition-colors cursor-pointer"
              >
                <.icon name="hero-x-mark" class="w-3.5 h-3.5 text-gray-400" />
                Reset
              </button>
            <% end %>
          </div>
        </form>
      </div>

      <!-- Tabs Navigation -->
      <div class="border-b border-gray-200">
        <nav class="-mb-px flex space-x-8" aria-label="Tabs">
          <button
            type="button"
            phx-click="change_log_tab"
            phx-value-tab="user"
            class={if to_string(@log_tab) == "user", do: "border-primary-500 text-primary-600 whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 cursor-pointer", else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 cursor-pointer"}
          >
            <.icon name="hero-users" class="w-4 h-4 pointer-events-none" />
            <span class="pointer-events-none">Log User</span>
          </button>

          <button
            type="button"
            phx-click="change_log_tab"
            phx-value-tab="admin"
            class={if to_string(@log_tab) == "admin", do: "border-primary-500 text-primary-600 whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 cursor-pointer", else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center gap-2 cursor-pointer"}
          >
            <.icon name="hero-shield-check" class="w-4 h-4 pointer-events-none" />
            <span class="pointer-events-none">Log Admin</span>
          </button>
        </nav>
      </div>

      <!-- Tab Content -->
      <div>
        <%= if to_string(@log_tab) == "user" do %>
          <div class="w-full space-y-8 pb-20">
            <.card label="User Activity & Footprint Logs">
              <div class="overflow-x-auto overflow-y-auto max-h-[calc(100vh-340px)] border-b border-gray-200">
                <table class="min-w-full divide-y divide-gray-200">
                  <thead class="bg-gray-50 sticky top-0 z-10 shadow-sm">
                    <tr>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Phone</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Time</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">IP</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User Agent</th>
                    </tr>
                  </thead>
                  <tbody class="bg-white divide-y divide-gray-200">
                    <%= for log <- @user_logs do %>
                      <% wib_dt = to_wib(log.inserted_at) %>
                      <tr class="hover:bg-gray-50/50 transition-colors">
                        <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 border-b-0">
                          <%= Calendar.strftime(wib_dt, "%Y-%m-%d") %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm font-semibold text-gray-900 border-b-0">
                          <%= log.name || "User #{String.slice(log.user_id, 0, 8)}" %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-600 border-b-0 font-mono">
                          <%= log.phone || "-" %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 border-b-0 font-mono">
                          <%= Calendar.strftime(wib_dt, "%H:%M:%S WIB") %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-700 border-b-0">
                          <code class="bg-gray-100 text-gray-800 px-2 py-0.5 rounded text-xs font-mono"><%= log.ip_address %></code>
                        </td>
                        <td class="px-6 py-4 text-sm text-gray-500 border-b-0">
                          <div class="flex items-center gap-2">
                            <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-semibold bg-blue-50 text-blue-700 ring-1 ring-inset ring-blue-700/10">
                              <%= log.device_os %> / <%= log.device_browser %>
                            </span>
                            <span class="text-xs text-gray-400 font-mono truncate max-w-xs" title={log.user_agent}>
                              <%= log.user_agent %>
                            </span>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                    <%= if Enum.empty?(@user_logs) do %>
                      <tr>
                        <td colspan="6" class="px-6 py-10 text-center text-sm text-gray-400 italic">
                          Belum ada log footprint user yang tercatat.
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <!-- Pagination (Matches User Management style) -->
              <%= if @log_user_total_count > 0 do %>
                <div class="flex items-center justify-between border-t border-gray-200 bg-white px-4 py-3 sm:px-6 mt-4">
                  <div class="flex flex-1 justify-between sm:hidden">
                    <button
                      type="button"
                      phx-click="change_log_page"
                      phx-value-page={@log_user_page - 1}
                      disabled={@log_user_page <= 1}
                      class="relative inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
                    >
                      Previous
                    </button>
                    <button
                      type="button"
                      phx-click="change_log_page"
                      phx-value-page={@log_user_page + 1}
                      disabled={@log_user_page >= @log_user_total_pages}
                      class="relative ml-3 inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
                    >
                      Next
                    </button>
                  </div>
                  <div class="hidden sm:flex sm:flex-1 sm:items-center sm:justify-between">
                    <div>
                      <p class="text-sm text-gray-700">
                        Showing
                        <span class="font-medium"><%= max((@log_user_page - 1) * 20 + 1, 1) %></span>
                        to
                        <span class="font-medium"><%= min(@log_user_page * 20, @log_user_total_count) %></span>
                        of
                        <span class="font-medium"><%= @log_user_total_count %></span>
                        logs
                      </p>
                    </div>
                    <div>
                      <nav class="isolate inline-flex -space-x-px rounded-md shadow-sm" aria-label="Pagination">
                        <button
                          type="button"
                          phx-click="change_log_page"
                          phx-value-page={@log_user_page - 1}
                          disabled={@log_user_page <= 1}
                          class="relative inline-flex items-center rounded-l-md px-2 py-2 text-gray-400 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20 focus:outline-offset-0 disabled:opacity-50 cursor-pointer"
                        >
                          <span class="sr-only">Previous</span>
                          <.icon name="hero-chevron-left" class="h-5 w-5" />
                        </button>

                        <%= for p <- 1..@log_user_total_pages do %>
                          <button
                            type="button"
                            phx-click="change_log_page"
                            phx-value-page={p}
                            class={[
                              "relative inline-flex items-center px-4 py-2 text-sm font-semibold focus:z-20 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 cursor-pointer",
                              if(p == @log_user_page,
                                do: "z-10 bg-primary-600 text-white focus-visible:outline-primary-600",
                                else: "text-gray-900 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:outline-offset-0"
                              )
                            ]}
                          >
                            <%= p %>
                          </button>
                        <% end %>

                        <button
                          type="button"
                          phx-click="change_log_page"
                          phx-value-page={@log_user_page + 1}
                          disabled={@log_user_page >= @log_user_total_pages}
                          class="relative inline-flex items-center rounded-r-md px-2 py-2 text-gray-400 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20 focus:outline-offset-0 disabled:opacity-50 cursor-pointer"
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
        <% end %>

        <%= if to_string(@log_tab) == "admin" do %>
          <div class="w-full space-y-8 pb-20">
            <.card label="Admin Login & Footprint Logs">
              <div class="overflow-x-auto overflow-y-auto max-h-[calc(100vh-340px)] border-b border-gray-200">
                <table class="min-w-full divide-y divide-gray-200">
                  <thead class="bg-gray-50 sticky top-0 z-10 shadow-sm">
                    <tr>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Time</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">IP</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User Agent</th>
                    </tr>
                  </thead>
                  <tbody class="bg-white divide-y divide-gray-200">
                    <%= for log <- @admin_logs do %>
                      <% email_val = (log.admin && log.admin.email) || log.email || "admin" %>
                      <% admin_name = email_val |> String.split("@") |> List.first() |> String.capitalize() %>
                      <% wib_dt = to_wib(log.inserted_at) %>
                      <tr class="hover:bg-gray-50/50 transition-colors">
                        <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 border-b-0">
                          <%= Calendar.strftime(wib_dt, "%Y-%m-%d") %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm font-semibold text-gray-900 border-b-0">
                          <%= admin_name %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-600 border-b-0">
                          <%= log.email || (log.admin && log.admin.email) || "-" %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 border-b-0 font-mono">
                          <%= Calendar.strftime(wib_dt, "%H:%M:%S WIB") %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-700 border-b-0">
                          <code class="bg-gray-100 text-gray-800 px-2 py-0.5 rounded text-xs font-mono"><%= log.ip_address %></code>
                        </td>
                        <td class="px-6 py-4 text-sm text-gray-500 border-b-0">
                          <div class="flex items-center gap-2">
                            <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-semibold bg-primary-50 text-primary-700 ring-1 ring-inset ring-primary-700/10">
                              <%= log.device_os %> / <%= log.device_browser %>
                            </span>
                            <span class="text-xs text-gray-400 font-mono truncate max-w-xs" title={log.user_agent}>
                              <%= log.user_agent %>
                            </span>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                    <%= if Enum.empty?(@admin_logs) do %>
                      <tr>
                        <td colspan="6" class="px-6 py-10 text-center text-sm text-gray-400 italic">
                          Belum ada log footprint admin yang tercatat.
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <!-- Pagination (Matches User Management style) -->
              <%= if @log_admin_total_count > 0 do %>
                <div class="flex items-center justify-between border-t border-gray-200 bg-white px-4 py-3 sm:px-6 mt-4">
                  <div class="flex flex-1 justify-between sm:hidden">
                    <button
                      type="button"
                      phx-click="change_log_page"
                      phx-value-page={@log_admin_page - 1}
                      disabled={@log_admin_page <= 1}
                      class="relative inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
                    >
                      Previous
                    </button>
                    <button
                      type="button"
                      phx-click="change_log_page"
                      phx-value-page={@log_admin_page + 1}
                      disabled={@log_admin_page >= @log_admin_total_pages}
                      class="relative ml-3 inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
                    >
                      Next
                    </button>
                  </div>
                  <div class="hidden sm:flex sm:flex-1 sm:items-center sm:justify-between">
                    <div>
                      <p class="text-sm text-gray-700">
                        Showing
                        <span class="font-medium"><%= max((@log_admin_page - 1) * 20 + 1, 1) %></span>
                        to
                        <span class="font-medium"><%= min(@log_admin_page * 20, @log_admin_total_count) %></span>
                        of
                        <span class="font-medium"><%= @log_admin_total_count %></span>
                        logs
                      </p>
                    </div>
                    <div>
                      <nav class="isolate inline-flex -space-x-px rounded-md shadow-sm" aria-label="Pagination">
                        <button
                          type="button"
                          phx-click="change_log_page"
                          phx-value-page={@log_admin_page - 1}
                          disabled={@log_admin_page <= 1}
                          class="relative inline-flex items-center rounded-l-md px-2 py-2 text-gray-400 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20 focus:outline-offset-0 disabled:opacity-50 cursor-pointer"
                        >
                          <span class="sr-only">Previous</span>
                          <.icon name="hero-chevron-left" class="h-5 w-5" />
                        </button>

                        <%= for p <- 1..@log_admin_total_pages do %>
                          <button
                            type="button"
                            phx-click="change_log_page"
                            phx-value-page={p}
                            class={[
                              "relative inline-flex items-center px-4 py-2 text-sm font-semibold focus:z-20 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 cursor-pointer",
                              if(p == @log_admin_page,
                                do: "z-10 bg-primary-600 text-white focus-visible:outline-primary-600",
                                else: "text-gray-900 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:outline-offset-0"
                              )
                            ]}
                          >
                            <%= p %>
                          </button>
                        <% end %>

                        <button
                          type="button"
                          phx-click="change_log_page"
                          phx-value-page={@log_admin_page + 1}
                          disabled={@log_admin_page >= @log_admin_total_pages}
                          class="relative inline-flex items-center rounded-r-md px-2 py-2 text-gray-400 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20 focus:outline-offset-0 disabled:opacity-50 cursor-pointer"
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
        <% end %>
      </div>
    </div>
    """
  end

  def to_wib(nil), do: DateTime.utc_now() |> DateTime.add(7 * 3600, :second)
  def to_wib(%DateTime{} = dt), do: DateTime.add(dt, 7 * 3600, :second)
  def to_wib(%NaiveDateTime{} = ndt) do
    dt = DateTime.from_naive!(ndt, "Etc/UTC")
    DateTime.add(dt, 7 * 3600, :second)
  end
  def to_wib(_), do: DateTime.utc_now() |> DateTime.add(7 * 3600, :second)
end
