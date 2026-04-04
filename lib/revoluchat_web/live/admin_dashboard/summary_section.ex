defmodule RevoluchatWeb.AdminDashboardLive.SummarySection do
  use RevoluchatWeb, :component

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
      <.stat_card label="Total Messages" value={@total_messages} icon="hero-chat-bubble-left-right" />
      <.stat_card
        label="Conversations"
        value={@total_conversations}
        icon="hero-users"
        color_class="text-blue-600 bg-blue-100"
      />
    </div>
    """
  end

end
