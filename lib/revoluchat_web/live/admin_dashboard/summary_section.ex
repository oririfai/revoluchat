defmodule RevoluchatWeb.AdminDashboardLive.SummarySection do
  use RevoluchatWeb, :component

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Stat Cards Grid -->
      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 xl:grid-cols-3">
        <.summary_stat_card
          id="stat-total-users"
          label="Total Users"
          value={format_number(@total_users)}
          icon="hero-users"
          color_class="text-indigo-600 bg-indigo-50"
          border_class="border-indigo-100"
          trend_label="registered accounts"
        />
        <.summary_stat_card
          id="stat-active-users"
          label="Active Users"
          value={format_number(@total_active_users)}
          icon="hero-user-circle"
          color_class="text-emerald-600 bg-emerald-50"
          border_class="border-emerald-100"
          trend_label="accounts in good standing"
        />
        <.summary_stat_card
          id="stat-suspended-users"
          label="Suspended Users"
          value={format_number(@total_suspended_users)}
          icon="hero-no-symbol"
          color_class="text-red-500 bg-red-50"
          border_class="border-red-100"
          trend_label="restricted accounts"
        />
        <.summary_stat_card
          id="stat-total-conversations"
          label="Total Conversations"
          value={format_number(@total_conversations)}
          icon="hero-user-group"
          color_class="text-violet-600 bg-violet-50"
          border_class="border-violet-100"
          trend_label="active chat threads"
        />
        <.summary_stat_card
          id="stat-total-messages"
          label="Total Messages"
          value={format_number(@total_messages)}
          icon="hero-chat-bubble-left-right"
          color_class="text-sky-600 bg-sky-50"
          border_class="border-sky-100"
          trend_label="messages exchanged"
        />
        <.summary_stat_card
          id="stat-connected-users"
          label="Connected Users"
          value={format_number(@total_connected_users)}
          icon="hero-wifi"
          color_class="text-amber-600 bg-amber-50"
          border_class="border-amber-100"
          trend_label="realtime connection"
          is_live={@total_connected_users > 0}
        />
      </div>

      <!-- Message Volume Chart -->
      <div class="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
        <div class="px-6 py-5 border-b border-gray-100 flex items-center justify-between">
          <div>
            <h3 class="text-base font-semibold text-gray-900">Message Volume</h3>
            <p class="text-sm text-gray-400 mt-0.5">Messages sent over the last 7 days</p>
          </div>
          <span class="inline-flex items-center gap-1.5 text-xs font-medium text-sky-600 bg-sky-50 px-2.5 py-1 rounded-full border border-sky-100">
            <span class="w-1.5 h-1.5 rounded-full bg-sky-500 inline-block animate-pulse"></span>
            Auto-refresh
          </span>
        </div>
        <div class="p-6">
          <div
            id="message-volume-chart"
            phx-hook="MessageVolumeChart"
            data-stats={Jason.encode!(@message_volume_stats)}
            class="h-56"
          ></div>
        </div>
      </div>

      <!-- Quick Stats Row -->
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <.summary_ratio_card
          id="stat-active-ratio"
          label="Active Rate"
          value={active_ratio(@total_users, @total_active_users)}
          description="of users are active"
          color="emerald"
        />
        <.summary_ratio_card
          id="stat-suspension-ratio"
          label="Suspension Rate"
          value={active_ratio(@total_users, @total_suspended_users)}
          description="of users suspended"
          color="red"
        />
        <.summary_ratio_card
          id="stat-msg-per-user"
          label="Avg. Messages/User"
          value={msgs_per_user(@total_messages, @total_users)}
          description="messages per registered user"
          color="sky"
        />
      </div>
    </div>
    """
  end

  # ─── Sub-components ──────────────────────────────────────────────────────────

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :color_class, :string, default: "text-indigo-600 bg-indigo-50"
  attr :border_class, :string, default: "border-gray-100"
  attr :trend_label, :string, default: ""
  attr :is_live, :boolean, default: false

  defp summary_stat_card(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "bg-white rounded-2xl border shadow-sm p-5 flex items-start gap-4 transition-all duration-200 hover:shadow-md hover:-translate-y-0.5",
        @border_class
      ]}
    >
      <div class={["flex-shrink-0 w-12 h-12 rounded-xl flex items-center justify-center", @color_class]}>
        <.icon name={@icon} class="w-6 h-6" />
      </div>
      <div class="min-w-0 flex-1">
        <p class="text-sm font-medium text-gray-500 truncate"><%= @label %></p>
        <div class="flex items-baseline gap-2 mt-0.5">
          <p class="text-2xl font-bold text-gray-900"><%= @value %></p>
        </div>
        <%= if @trend_label != "" do %>
          <p class="text-xs text-gray-400 mt-1 truncate"><%= @trend_label %></p>
        <% end %>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :description, :string, default: ""
  attr :color, :string, default: "sky"

  defp summary_ratio_card(assigns) do
    ~H"""
    <div
      id={@id}
      class="bg-white rounded-xl border border-gray-100 shadow-sm p-4 text-center"
    >
      <p class="text-xs font-medium text-gray-400 uppercase tracking-wider"><%= @label %></p>
      <p class={[
        "text-3xl font-black mt-1",
        case @color do
          "emerald" -> "text-emerald-600"
          "red" -> "text-red-500"
          "sky" -> "text-sky-600"
          _ -> "text-indigo-600"
        end
      ]}>
        <%= @value %>
      </p>
      <%= if @description != "" do %>
        <p class="text-xs text-gray-400 mt-1"><%= @description %></p>
      <% end %>
    </div>
    """
  end

  # ─── Helpers ─────────────────────────────────────────────────────────────────

  defp format_number(nil), do: "0"
  defp format_number(n) when n >= 1_000_000 do
    "#{Float.round(n / 1_000_000, 1)}M"
  end
  defp format_number(n) when n >= 1_000 do
    "#{Float.round(n / 1_000, 1)}K"
  end
  defp format_number(n), do: to_string(n)

  defp active_ratio(0, _), do: "0%"
  defp active_ratio(nil, _), do: "0%"
  defp active_ratio(_, nil), do: "0%"
  defp active_ratio(total, part) do
    pct = (part / total * 100) |> Float.round(1)
    "#{pct}%"
  end

  defp msgs_per_user(0, _), do: "0"
  defp msgs_per_user(_, 0), do: "0"
  defp msgs_per_user(nil, _), do: "0"
  defp msgs_per_user(_, nil), do: "0"
  defp msgs_per_user(msgs, users) do
    avg = (msgs / users) |> Float.round(1)
    "#{avg}"
  end
end
