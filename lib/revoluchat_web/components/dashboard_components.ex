defmodule RevoluchatWeb.DashboardComponents do
  use Phoenix.Component
  use PetalComponents
  use RevoluchatWeb, :verified_routes

  alias Phoenix.LiveView.JS

  attr(:active_tab, :atom, required: true)
  attr(:admin_name, :string, default: "Admin")
  attr(:collapsed, :boolean, default: false)

  def sidebar(assigns) do
    ~H"""
    <aside class={[
      "fixed inset-y-0 left-0 z-50 bg-white border-r border-gray-200 flex flex-col transition-all duration-300 ease-in-out",
      if(@collapsed, do: "w-20", else: "w-64")
    ]}>
      <div class="flex flex-col flex-grow pt-5 pb-4">
        <div class={[
          "flex items-center flex-shrink-0 px-6 gap-2 mb-8 transition-all duration-300",
          if(@collapsed, do: "justify-center px-2", else: "")
        ]}>
          <span class="text-primary-600 font-black text-2xl tracking-tighter">R</span>
          <%= if !@collapsed do %>
            <span class="text-primary-600 font-black text-2xl tracking-tighter -ml-1">EVOLU</span>
            <span class="text-gray-400 font-light text-xl">CHAT</span>
          <% end %>
        </div>
        <nav class="mt-5 flex-1 px-3 space-y-1">
          <.nav_item
            href={~p"/admin"}
            active={@active_tab == :summary}
            icon="hero-squares-2x2"
            text="Summary"
            collapsed={@collapsed}
          />
          <.nav_item
            href={~p"/admin/activity"}
            active={@active_tab == :activity}
            icon="hero-chart-bar-square"
            text="Activity"
            collapsed={@collapsed}
          />
          <.nav_item
            href={~p"/admin/setting"}
            active={@active_tab == :setting}
            icon="hero-cog-6-tooth"
            text="Setting"
            collapsed={@collapsed}
          />
          <.nav_item
            href={~p"/admin/apikeys"}
            active={@active_tab == :api_keys}
            icon="hero-command-line"
            text="API Keys"
            collapsed={@collapsed}
          />
          <.nav_item
            href={~p"/admin/serverkeys"}
            active={@active_tab == :server_keys}
            icon="hero-server"
            text="Server Keys"
            collapsed={@collapsed}
          />
        </nav>
      </div>

      <!-- Navigation for Documentation (above profile) -->
      <div class="px-3 py-2">
        <.nav_item
          href={~p"/admin/documentation"}
          active={@active_tab == :documentation}
          icon="hero-book-open"
          text="Documentation"
          collapsed={@collapsed}
        />
      </div>

      <div class="flex-shrink-0 flex border-t border-gray-200 p-4">
        <div class={[
          "flex items-center transition-all duration-300",
          if(@collapsed, do: "justify-center w-full", else: "gap-3")
        ]}>
          <div class="h-8 w-8 rounded-full bg-primary-100 flex items-center justify-center text-primary-700 font-bold text-xs flex-shrink-0">
            <%= String.slice(@admin_name, 0, 2) |> String.upcase() %>
          </div>
          <%= if !@collapsed do %>
            <div class="text-sm overflow-hidden">
              <p class="font-medium text-gray-700 truncate"><%= @admin_name %></p>
              <form action={~p"/admin/logout"} method="post" class="inline">
                <input type="hidden" name="_method" value="delete">
                <button type="submit" class="text-xs text-gray-400 hover:text-red-500 transition-colors">
                  Sign out
                </button>
              </form>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Floating Toggle Button -->
      <button
        phx-click="toggle_sidebar"
        class="absolute top-1/2 -right-3 transform -translate-y-1/2 z-[60] flex items-center justify-center w-6 h-6 bg-white border border-gray-200 rounded-full shadow-sm hover:text-primary-600 hover:border-primary-300 transition-all duration-200 text-gray-400 group/toggle"
        title={if(@collapsed, do: "Expand", else: "Collapse")}
      >
        <.icon
          name={if(@collapsed, do: "hero-chevron-right", else: "hero-chevron-left")}
          class="w-3.5 h-3.5 transition-transform duration-300 group-hover/toggle:scale-110"
        />
      </button>
    </aside>
    """
  end

  attr(:href, :string, required: true)
  attr(:active, :boolean, default: false)
  attr(:icon, :string, required: true)
  attr(:text, :string, required: true)
  attr(:collapsed, :boolean, default: false)

  def nav_item(assigns) do
    ~H"""
    <.link
      patch={@href}
      class={[
        "group relative flex items-center px-3 py-2 text-sm font-medium rounded-md transition-all duration-200",
        if(@active,
          do: "bg-primary-50 text-primary-700",
          else: "text-gray-600 hover:bg-gray-50 hover:text-gray-900"
        ),
        if(@collapsed, do: "justify-center", else: "")
      ]}
    >
      <.icon
        name={@icon}
        class={[
          "flex-shrink-0 h-5 w-5 transition-colors duration-200",
          if(!@collapsed, do: "mr-3", else: ""),
          if(@active, do: "text-primary-600", else: "text-gray-400 group-hover:text-gray-500")
        ]}
      />
      <%= if !@collapsed do %>
        <span class="truncate transition-all duration-300 opacity-100 group-hover:pl-1">
          <%= @text %>
        </span>
      <% else %>
        <!-- Stylized Tooltip -->
        <div class="absolute left-full ml-2 px-2 py-1 bg-gray-900 text-white text-xs rounded opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 whitespace-nowrap z-[70] shadow-lg pointer-events-none">
          <%= @text %>
          <!-- Tooltip Arrow -->
          <div class="absolute right-full top-1/2 -translate-y-1/2 border-4 border-transparent border-r-gray-900">
          </div>
        </div>
      <% end %>
    </.link>
    """
  end

  attr(:title, :string, required: true)
  attr(:description, :string, default: nil)

  def page_header(assigns) do
    ~H"""
    <div class="mb-8">
      <h2 class="text-2xl font-bold text-gray-900 sm:text-3xl tracking-tight">
        <%= @title %>
      </h2>
      <%= if @description do %>
        <p class="mt-2 text-sm text-gray-500">
          <%= @description %>
        </p>
      <% end %>
    </div>
    """
  end

  attr(:label, :string, required: true)
  attr(:value, :any, required: true)
  attr(:icon, :string, required: true)
  attr(:color_class, :string, default: "text-primary-600 bg-primary-100")

  def stat_card(assigns) do
    ~H"""
    <.card>
      <div class="p-5">
        <div class="flex items-center">
          <div class={["flex-shrink-0 p-3 rounded-lg", @color_class]}>
            <.icon name={@icon} class="w-6 h-6" />
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate"><%= @label %></dt>
              <dd class="text-2xl font-semibold text-gray-900"><%= @value %></dd>
            </dl>
          </div>
        </div>
      </div>
    </.card>
    """
  end

  attr(:label, :string, required: true)
  attr(:items, :list, default: [])

  def activity_list(assigns) do
    ~H"""
    <.card label={@label}>
      <div class="space-y-4">
        <%= if Enum.empty?(@items) do %>
          <p class="text-sm text-gray-400 text-center py-4 italic">No recent activity.</p>
        <% else %>
          <%= for item <- @items do %>
            <div class="flex items-center justify-between text-sm py-2 border-b last:border-0 hover:bg-gray-50/50 px-2 -mx-2 rounded transition-colors duration-150">
              <div class="flex items-center gap-3">
                <span class={[
                  "px-2 py-0.5 rounded font-mono text-xs font-bold",
                  item.badge_class
                ]}>
                  <%= item.badge %>
                </span>
                <span class="text-gray-700 font-medium"><%= item.text %></span>
              </div>
              <span class="text-gray-400 text-xs"><%= item.time %></span>
            </div>
          <% end %>
        <% end %>
      </div>
    </.card>
    """
  end

  def mobile_header(assigns) do
    ~H"""
    <header class="sticky top-0 z-40 bg-white/80 backdrop-blur-md border-b border-gray-200 lg:hidden">
      <div class="px-4 py-4 flex justify-between items-center">
        <div class="flex items-center gap-2">
          <span class="text-primary-600 font-black text-xl tracking-tighter">REVOLU</span>
          <span class="text-gray-400 font-light text-lg">CHAT</span>
        </div>
      </div>
    </header>
    """
  end

  attr(:type, :string, default: "button")
  # solid, outline, ghost, white
  attr(:variant, :string, default: "solid")
  # xs, sm, md, lg
  attr(:size, :string, default: "md")
  attr(:class, :string, default: nil)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def revolu_button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex items-center justify-center font-semibold transition-all duration-200 active:scale-95 disabled:opacity-50 disabled:active:scale-100",
        case @size do
          "xs" -> "px-2.5 py-1.5 text-xs rounded-md"
          "sm" -> "px-3 py-2 text-sm leading-4 rounded-md"
          "md" -> "px-4 py-2.5 text-sm rounded-lg"
          "lg" -> "px-6 py-3 text-base rounded-xl"
        end,
        case @variant do
          "solid" -> "bg-primary-600 text-white shadow-sm hover:bg-primary-700 hover:shadow-md border border-transparent"
          "outline" -> "bg-transparent border-2 border-primary-600 text-primary-600 hover:bg-primary-50"
          "ghost" -> "bg-transparent text-primary-600 hover:bg-primary-50 border border-transparent"
          "white" -> "bg-white text-gray-700 border border-gray-200 shadow-sm hover:bg-gray-50 hover:border-gray-300"
          _ -> "bg-primary-600 text-white"
        end,
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  attr(:id, :string, required: true)
  attr(:show, :boolean, default: false)
  attr(:on_cancel, JS, default: %JS{})
  # info, warning, danger, success
  attr(:type, :string, default: "info")
  attr(:title, :string, default: nil)
  # sm, md, lg, xl, 2xl
  attr(:max_width, :string, default: "sm")
  slot(:inner_block, required: true)
  slot(:footer)

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_dashboard_modal(@id)}
      phx-remove={hide_dashboard_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove") |> hide_dashboard_modal(@id)}
      class="relative z-[100] hidden"
    >
      <div id={"#{@id}-bg"} class="fixed inset-0 bg-gray-900/40 backdrop-blur-sm transition-opacity" aria-hidden="true" />
      <div class="fixed inset-0 z-10 w-screen overflow-y-auto">
        <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
          <div
            id={"#{@id}-container"}
            phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
            phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
            class={[
              "relative transform overflow-hidden rounded-2xl bg-white text-left shadow-2xl transition-all sm:my-8 w-full",
              case @max_width do
                "sm" -> "sm:max-w-sm"
                "md" -> "sm:max-w-md"
                "lg" -> "sm:max-w-lg"
                "xl" -> "sm:max-w-xl"
                "2xl" -> "sm:max-w-2xl"
                _ -> "sm:max-w-lg"
              end
            ]}
          >
            <div class="bg-white px-4 pb-4 pt-5 sm:p-6 sm:pb-4">
              <div class="sm:flex sm:items-start">
                <%= if @type != "info" do %>
                  <div class={[
                    "mx-auto flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full sm:mx-0 sm:h-10 sm:w-10",
                    case @type do
                      "danger" -> "bg-red-100 text-red-600"
                      "warning" -> "bg-amber-100 text-amber-600"
                      "success" -> "bg-green-100 text-green-600"
                      _ -> "bg-primary-100 text-primary-600"
                    end
                  ]}>
                    <.icon
                      name={
                        case @type do
                          "danger" -> "hero-exclamation-triangle"
                          "warning" -> "hero-exclamation-circle"
                          "success" -> "hero-check-circle"
                          _ -> "hero-information-circle"
                        end
                      }
                      class="h-6 w-6"
                    />
                  </div>
                <% end %>
                <div class={["mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left", if(@type == "info", do: "w-full")]}>
                  <%= if @title do %>
                    <h3 class="text-lg font-bold leading-6 text-gray-900" id={"#{@id}-title"}>
                      <%= @title %>
                    </h3>
                  <% end %>
                  <div class="mt-2 text-sm text-gray-500">
                    <%= render_slot(@inner_block) %>
                  </div>
                </div>
              </div>
            </div>
            <%= if render_slot(@footer) != "" do %>
              <div class="bg-gray-50 px-4 py-3 sm:flex sm:flex-row-reverse sm:px-6 gap-3">
                <%= render_slot(@footer) %>
              </div>
            <% else %>
              <div class="bg-gray-50 px-4 py-3 sm:flex sm:flex-row-reverse sm:px-6">
                 <.revolu_button phx-click={hide_dashboard_modal(@id)} variant="white">Close</.revolu_button>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def show_dashboard_modal(id) when is_binary(id) do
    show_dashboard_modal(%JS{}, id)
  end

  def show_dashboard_modal(%JS{} = js, id) do
    js
    |> JS.show(
      to: "##{id}",
      transition: {"transition ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "##{id}-container",
      transition:
        {"transition ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-container")
  end

  def hide_dashboard_modal(id) when is_binary(id) do
    hide_dashboard_modal(%JS{}, id)
  end

  def hide_dashboard_modal(%JS{} = js, id) do
    js
    |> JS.hide(
      to: "##{id}",
      transition: {"transition ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "##{id}-container",
      transition:
        {"transition ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
