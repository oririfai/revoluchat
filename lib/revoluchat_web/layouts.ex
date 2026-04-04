defmodule RevoluchatWeb.Layouts do
  use RevoluchatWeb, :html

  embed_templates("layouts/*")

  def nav_link(assigns) do
    ~H"""
    <.link
      href={@href}
      class={[
        "group flex items-center px-3 py-2 text-sm font-medium rounded-md transition-all duration-200",
        if(@active, do: "bg-primary-50 text-primary-700", else: "text-gray-600 hover:bg-gray-50 hover:text-gray-900")
      ]}
    >
      <.icon
        name={@icon}
        class={[
          "mr-3 flex-shrink-0 h-5 w-5 transition-colors duration-200",
          if(@active, do: "text-primary-600", else: "text-gray-400 group-hover:text-gray-500")
        ]}
      />
      <%= @text %>
    </.link>
    """
  end
end
