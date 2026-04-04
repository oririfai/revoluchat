defmodule RevoluchatWeb.AdminDashboardLive.ActivitySection do
  use RevoluchatWeb, :component

  def render(assigns) do
    ~H"""
    <.card class="overflow-hidden">
      <div class="h-96 bg-gray-50 flex items-center justify-center border-t border-dashed border-gray-200">
        <div class="text-center">
          <.icon name="hero-map" class="w-12 h-12 text-gray-300 mx-auto mb-2" />
          <p class="text-sm text-gray-400 font-medium">Real-time connection map visualization</p>
          <div class="mt-4 flex justify-center gap-1">
            <div class="w-2 h-2 rounded-full bg-green-500 animate-pulse"></div>
            <div class="w-2 h-2 rounded-full bg-blue-500 animate-pulse delay-75"></div>
            <div class="w-2 h-2 rounded-full bg-purple-500 animate-pulse delay-150"></div>
          </div>
        </div>
      </div>
    </.card>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-8">
      <.activity_list
        label="Incoming Requests"
        items={[
          %{badge: "GET", badge_class: "bg-blue-50 text-blue-700", text: "/api/v1/conversations", time: "Just now"},
          %{badge: "POST", badge_class: "bg-green-50 text-green-700", text: "/api/v1/messages", time: "1m ago"},
          %{badge: "GET", badge_class: "bg-blue-50 text-blue-700", text: "/api/v1/health", time: "5m ago"}
        ]}
      />
      <.activity_list
        label="WebSocket Events"
        items={[
          %{badge: "JOIN", badge_class: "bg-green-50 text-green-700", text: "room:lobby", time: "2 mins ago"},
          %{badge: "MSG", badge_class: "bg-primary-50 text-primary-700", text: "new:message", time: "4 mins ago"},
          %{badge: "LEAVE", badge_class: "bg-red-50 text-red-700", text: "room:123", time: "10 mins ago"}
        ]}
      />
    </div>
    """
  end
end
