defmodule RevoluchatWeb.AdminDashboardLive.SettingSection do
  use RevoluchatWeb, :component

  def render(assigns) do
    ~H"""
    <div class="w-full space-y-6">
      <!-- Tabs Navigation -->
      <div class="border-b border-gray-200">
        <nav class="-mb-px flex space-x-8" aria-label="Tabs">
          <button
            phx-click="change_setting_tab"
            phx-value-tab="general"
            class={if @setting_tab == :general, do: "border-blue-500 text-blue-600 whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm", else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm"}
          >
            General Settings
          </button>
          
          <button
            phx-click="change_setting_tab"
            phx-value-tab="chat_room"
            class={if @setting_tab == :chat_room, do: "border-blue-500 text-blue-600 whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm", else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm"}
          >
            Chat Room
          </button>
        </nav>
      </div>

      <!-- Tab Content -->
      <div>
        <%= if @setting_tab == :general do %>
          <div class="w-full space-y-8">
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
        <% end %>

        <%= if @setting_tab == :chat_room do %>
          <div class="w-full space-y-8">
            <.card label="Upload Wallpaper">
              <form id="wallpaper-upload-form" phx-submit="save_wallpaper" phx-change="validate_wallpaper">
                <div class="space-y-4">
                  <div class="flex items-center justify-center w-full">
                      <label for={@uploads.wallpaper.ref} class="flex flex-col items-center justify-center w-full h-32 border-2 border-gray-300 border-dashed rounded-lg cursor-pointer bg-gray-50 hover:bg-gray-100">
                          <div class="flex flex-col items-center justify-center pt-5 pb-6">
                              <svg class="w-8 h-8 mb-4 text-gray-500" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 20 16">
                                  <path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 13h3a3 3 0 0 0 0-6h-.025A5.56 5.56 0 0 0 16 6.5 5.5 5.5 0 0 0 5.207 5.021C5.137 5.017 5.071 5 5 5a4 4 0 0 0 0 8h2.167M10 15V6m0 0L8 8m2-2 2 2"/>
                              </svg>
                              <p class="mb-2 text-sm text-gray-500"><span class="font-semibold">Click to upload</span> or drag and drop</p>
                              <p class="text-xs text-gray-500">JPG, JPEG or PNG (MAX. 5MB)</p>
                          </div>
                          <.live_file_input upload={@uploads.wallpaper} class="hidden" />
                      </label>
                  </div>
                  
                  <%= for entry <- @uploads.wallpaper.entries do %>
                    <div class="flex items-center justify-between p-3 bg-white border border-gray-200 rounded">
                      <span class="text-sm font-medium text-gray-900"><%= entry.client_name %></span>
                      <div class="flex flex-col items-end">
                        <span class="text-sm text-gray-500"><%= Float.round(entry.client_size / 1024 / 1024, 2) %> MB</span>
                        <%= if entry.progress > 0 do %>
                          <span class="text-xs text-blue-600 font-semibold"><%= entry.progress %>%</span>
                        <% end %>
                      </div>
                    </div>
                    
                    <%= for err <- upload_errors(@uploads.wallpaper, entry) do %>
                      <p class="text-xs text-red-600 mt-1"><%= error_to_string(err) %></p>
                    <% end %>
                  <% end %>
                  
                  <%= for err <- upload_errors(@uploads.wallpaper) do %>
                    <p class="text-sm text-red-600"><%= error_to_string(err) %></p>
                  <% end %>
                </div>
                
                <div class="mt-6 flex justify-end">
                   <.revolu_button type="submit" variant="solid" disabled={Enum.empty?(@uploads.wallpaper.entries)} phx-disable-with="Uploading...">Upload Wallpaper</.revolu_button>
                </div>
              </form>
            </.card>

            <.card label="Active Wallpapers">
              <%= if Enum.empty?(@wallpapers) do %>
                <p class="text-sm text-gray-500 text-center py-8">No wallpapers uploaded yet.</p>
              <% else %>
                <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <%= for wallpaper <- @wallpapers do %>
                    <% backend_url = System.get_env("CHAT_SERVICE_HTTP_ENDPOINT", "http://localhost:8181") %>
                    <% image_url = if String.starts_with?(wallpaper.url, "/"), do: "#{backend_url}#{wallpaper.url}", else: wallpaper.url %>
                    <div class="relative group aspect-[9/16] rounded-lg overflow-hidden border border-gray-200">
                      <img src={image_url} class="object-cover w-full h-full" />
                      <div class="absolute inset-0 bg-black bg-opacity-40 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                        <button phx-click="delete_wallpaper" phx-value-id={wallpaper.id} class="bg-red-600 text-white p-2 rounded-full hover:bg-red-700 transition-colors" title="Delete Wallpaper" data-confirm="Are you sure you want to delete this wallpaper?">
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" />
                          </svg>
                        </button>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </.card>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
  def error_to_string(:too_large), do: "File too large"
  def error_to_string(:not_accepted), do: "Unacceptable file type"
  def error_to_string(:too_many_files), do: "Too many files"
  def error_to_string(_), do: "Unknown error"
end
