defmodule RevoluchatWeb.AdminDashboardLive.ServerKeysSection do
  use RevoluchatWeb, :component

  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl space-y-8 pb-20">
      <.card label="Generate New Server Key">
        <form phx-submit="create_server_key" class="flex gap-4 items-end">
          <div class="flex-1">
            <label class="block text-sm font-medium text-gray-700 mb-1">Key Name / Description</label>
            <input
              type="text"
              name="name"
              placeholder="e.g. Phoenix to Go SDK"
              required
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm"
            />
          </div>
          <.revolu_button type="submit" variant="solid" class="mb-1">Generate Key</.revolu_button>
        </form>
      </.card>

      <.card label="Active Server Keys">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead>
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Key</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for key <- @server_keys do %>
                <tr>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 border-b-0"><%= key.name %></td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 border-b-0">
                    <code class="bg-gray-100 px-2 py-1 rounded text-xs select-all"><%= key.key %></code>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap border-b-0">
                    <span class={[
                      "px-2 inline-flex text-xs leading-5 font-semibold rounded-full",
                      if(key.status == "active", do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800")
                    ]}>
                      <%= key.status %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium border-b-0 space-x-2">
                    <%= if key.status == "active" and @signer_count > 0 do %>
                       <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800 mr-2">
                        <svg class="mr-1.5 h-2 w-2 text-blue-400" fill="currentColor" viewBox="0 0 8 8">
                          <circle cx="4" cy="4" r="3" />
                        </svg>
                        Connected
                      </span>
                    <% else %>
                      <.revolu_button
                        variant="solid"
                        size="xs"
                        phx-click="connect_server_key"
                        phx-value-id={key.id}
                        class="bg-primary-600 hover:bg-primary-700"
                      >
                        Connect
                      </.revolu_button>
                    <% end %>

                    <%= if key.status == "active" do %>
                      <.revolu_button
                        variant="ghost"
                        size="xs"
                        phx-click="revoke_server_key"
                        phx-value-id={key.id}
                        class="text-amber-600 hover:text-amber-700 hover:bg-amber-50"
                      >
                        Revoke
                      </.revolu_button>
                    <% end %>

                    <.revolu_button
                      variant="ghost"
                      size="xs"
                      phx-click="delete_server_key"
                      phx-value-id={key.id}
                      class="text-red-600 hover:text-red-700 hover:bg-red-50"
                    >
                      Delete
                    </.revolu_button>
                  </td>
                  </tr>
                <% end %>
                <%= if Enum.empty?(@server_keys) do %>
                  <tr>
                    <td colspan="4" class="px-6 py-10 text-center text-sm text-gray-400 italic">
                      No Server Keys generated yet.
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </.card>
      </div>

      <%= if @show_delete_server_modal do %>
        <.modal
          id="delete-server-key-modal"
          show={@show_delete_server_modal}
          type="danger"
          title="Delete Server Key"
          on_cancel={JS.push("close_modal")}
        >
          Are you sure you want to permanently delete this Server Key? This action cannot be undone and may break inter-service communication if it's the only active key.
          <:footer>
             <.revolu_button phx-click="confirm_delete_server_key" variant="solid" class="bg-red-600 hover:bg-red-700">
              Confirm Delete
            </.revolu_button>
            <.revolu_button phx-click={hide_dashboard_modal("delete-server-key-modal") |> JS.push("close_modal")} variant="white">
              Cancel
            </.revolu_button>
          </:footer>
        </.modal>
      <% end %>

      <%= if @show_revoke_server_modal do %>
        <.modal
          id="revoke-server-key-modal"
          show={@show_revoke_server_modal}
          type="warning"
          title="Revoke Server Key"
          on_cancel={JS.push("close_modal")}
        >
          Are you sure you want to revoke this Server Key? The key will remain in the system but will no longer be valid for authentication.
          <:footer>
            <.revolu_button phx-click="confirm_revoke_server_key" variant="solid" class="bg-amber-600 hover:bg-amber-700">
              Confirm Revoke
            </.revolu_button>
            <.revolu_button phx-click={hide_dashboard_modal("revoke-server-key-modal") |> JS.push("close_modal")} variant="white">
              Cancel
            </.revolu_button>
          </:footer>
        </.modal>
      <% end %>
    """
  end
end
