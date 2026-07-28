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
            class={if @setting_tab == :general, do: "border-primary-500 text-primary-600 whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm", else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm"}
          >
            General Settings
          </button>
          
          <button
            phx-click="change_setting_tab"
            phx-value-tab="chat_room"
            class={if @setting_tab == :chat_room, do: "border-primary-500 text-primary-600 whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm", else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm"}
          >
            Chat Room
          </button>
        </nav>
      </div>

      <!-- Tab Content -->
      <div>
        <%= if @setting_tab == :general do %>
          <div class="w-full space-y-8 pb-20">
             
             <!-- Node Configuration -->
             <.card label="Node Configuration">
               <p class="text-sm text-gray-500 mb-6">Technical cluster and security details (read-only).</p>
               <dl class="divide-y divide-gray-100 border-t border-gray-100 pt-2">
                 <div class="py-4 sm:grid sm:grid-cols-3 sm:gap-4">
                   <dt class="text-sm font-medium leading-6 text-gray-900">Cluster Name</dt>
                   <dd class="mt-1 text-sm leading-6 text-gray-700 sm:col-span-2 sm:mt-0">revolu-chat-prod-cluster <span class="text-gray-400">(Detected via ENV)</span></dd>
                 </div>
                 <div class="py-4 sm:grid sm:grid-cols-3 sm:gap-4">
                   <dt class="text-sm font-medium leading-6 text-gray-900">Security Mode</dt>
                   <dd class="mt-1 text-sm leading-6 text-gray-700 sm:col-span-2 sm:mt-0">
                     <span class="inline-flex items-center rounded-full bg-blue-50 px-2.5 py-1 text-xs font-medium text-blue-700 ring-1 ring-inset ring-blue-700/10">Enterprise Hardened</span>
                   </dd>
                 </div>
               </dl>
              </.card>

              <!-- Global Limits -->
              <.card label="Global Server Limits & Anti-Spam Control">
                <p class="text-sm text-gray-500 mb-6">Configure dynamic Elixir backend limits enforced directly on WebSocket & API servers.</p>
                <form phx-submit="save_global_limits">
                  <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                     <div>
                       <label class="block text-sm font-medium text-gray-700 mb-1">Max Message Size (Bytes)</label>
                       <input
                         type="number"
                         name="max_message_size"
                         value={Map.get(@app_preferences || %{}, "max_message_size", "1048576")}
                         placeholder="1048576"
                         required
                         class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm"
                       />
                       <p class="text-xs text-gray-400 mt-1">Maximum allowed payload size per WebSocket message frame.</p>
                     </div>
                     <div>
                       <label class="block text-sm font-medium text-gray-700 mb-1">Anti-Spam Rate Limit (Msg/Sec)</label>
                       <input
                         type="number"
                         name="rate_limit_per_sec"
                         value={Map.get(@app_preferences || %{}, "rate_limit_per_sec", "5")}
                         placeholder="5"
                         required
                         class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm"
                       />
                       <p class="text-xs text-gray-400 mt-1">Maximum messages allowed per second per user connection.</p>
                     </div>
                     <div>
                       <label class="block text-sm font-medium text-gray-700 mb-1">Max Attachment Upload (MB)</label>
                       <input
                         type="number"
                         name="max_attachment_size_mb"
                         value={Map.get(@app_preferences || %{}, "max_attachment_size_mb", "25")}
                         placeholder="25"
                         required
                         class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm"
                       />
                       <p class="text-xs text-gray-400 mt-1">Maximum allowed file upload size per attachment.</p>
                     </div>
                  </div>
                  <div class="mt-8 flex items-center justify-end gap-x-4 border-t border-gray-100 pt-6">
                     <%= if assigns[:save_global_limits_status] == :success do %>
                       <p class="text-sm text-green-600 font-medium flex items-center">
                         <svg class="w-5 h-5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                         Global limits saved successfully
                       </p>
                     <% end %>
                     <%= if assigns[:save_global_limits_status] == :error do %>
                       <p class="text-sm text-red-600 font-medium flex items-center">
                         <svg class="w-5 h-5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                         Failed to save global limits
                       </p>
                     <% end %>
                     <.revolu_button type="submit" variant="solid" phx-disable-with="Saving Limits...">Save Global Limits</.revolu_button>
                  </div>
                </form>
              </.card>

             <!-- App Force Update Configuration -->
             <.card label="App Force Update Configuration">
               <p class="text-sm text-gray-500 mb-6">Configure the minimum required app version and store links. Older clients will be forced to update.</p>
               
               <form phx-submit="save_app_preferences">
                 <div class="space-y-6">
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">Latest App Version (Minimum Required)</label>
                      <input
                        type="text"
                        name="app_version"
                        value={Map.get(@app_preferences || %{}, "app_version", "")}
                        placeholder="e.g. 1.0.0"
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm"
                      />
                      <p class="text-xs text-gray-400 mt-1">Clients running a version lower than this will see a force-update screen.</p>
                    </div>
                    
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Play Store URL (Android)</label>
                        <input
                          type="text"
                          name="playstore_url"
                          value={Map.get(@app_preferences || %{}, "playstore_url", "")}
                          placeholder="https://play.google.com/..."
                          class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm"
                        />
                        <p class="text-xs text-gray-400 mt-1">Where Android users are redirected to update.</p>
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">App Store URL (iOS)</label>
                        <input
                          type="text"
                          name="appstore_url"
                          value={Map.get(@app_preferences || %{}, "appstore_url", "")}
                          placeholder="https://apps.apple.com/..."
                          class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 sm:text-sm"
                        />
                        <p class="text-xs text-gray-400 mt-1">Where iOS users are redirected to update.</p>
                      </div>
                    </div>
                 </div>
                 
                 <div class="mt-8 flex items-center justify-end gap-x-4 border-t border-gray-100 pt-6">
                    <%= if @save_app_preferences_status == :success do %>
                      <p class="text-sm text-green-600 font-medium flex items-center">
                        <svg class="w-5 h-5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                        Saved successfully
                      </p>
                    <% end %>
                    <%= if @save_app_preferences_status == :error do %>
                      <p class="text-sm text-red-600 font-medium flex items-center">
                        <svg class="w-5 h-5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                        Failed to save
                      </p>
                    <% end %>
                    <.revolu_button type="submit" variant="solid" phx-disable-with="Saving Changes...">Save App Preferences</.revolu_button>
                 </div>
               </form>
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
                        <button phx-click="request_delete_wallpaper" phx-value-id={wallpaper.id} class="bg-red-600 text-white p-2 rounded-full hover:bg-red-700 transition-colors" title="Delete Wallpaper">
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

      <%= if @show_delete_wallpaper_modal do %>
        <.modal
          id="delete-wallpaper-modal"
          show={@show_delete_wallpaper_modal}
          type="danger"
          title="Delete Wallpaper"
          on_cancel={JS.push("close_modal")}
        >
          Are you sure you want to permanently delete this wallpaper? This action cannot be undone.
          <:footer>
            <.revolu_button phx-click="confirm_delete_wallpaper" variant="solid" class="bg-red-600 hover:bg-red-700">
              Confirm Delete
            </.revolu_button>
            <.revolu_button phx-click={hide_dashboard_modal("delete-wallpaper-modal") |> JS.push("close_modal")} variant="white">
              Cancel
            </.revolu_button>
          </:footer>
        </.modal>
      <% end %>
    </div>
    """
  end
  def error_to_string(:too_large), do: "File too large"
  def error_to_string(:not_accepted), do: "Unacceptable file type"
  def error_to_string(:too_many_files), do: "Too many files"
  def error_to_string(_), do: "Unknown error"
end
