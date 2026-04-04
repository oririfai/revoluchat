defmodule RevoluchatWeb.AdminDashboardLive.SettingSection do
  use RevoluchatWeb, :component

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl space-y-8">
       <.card label="Node Configuration">
          <div class="space-y-6">
             <div>
                <h4 class="text-sm font-medium text-gray-900">Cluster Name</h4>
                <p class="text-xs text-gray-500">revolu-chat-prod-cluster (Detected via ENV)</p>
             </div>
             <div>
                <h4 class="text-sm font-medium text-gray-900">Security Mode</h4>
                <span class="mt-1 inline-flex items-center rounded-full bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700 ring-1 ring-inset ring-blue-700/10">
                  Enterprise Hardened
                </span>
             </div>
          </div>
       </.card>

       <.card label="Global Limits">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
             <.field label="Max Connections per User" type="number" value="10" name="limit_conn" />
             <.field label="Max Message Size (Bytes)" type="number" value="1048576" name="limit_msg" />
          </div>
          <div class="mt-6 flex justify-end">
             <.revolu_button variant="solid">Save Settings</.revolu_button>
          </div>
       </.card>
    </div>
    """
  end
end
