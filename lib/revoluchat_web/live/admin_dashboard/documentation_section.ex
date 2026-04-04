defmodule RevoluchatWeb.AdminDashboardLive.DocumentationSection do
  use RevoluchatWeb, :component

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl space-y-8 pb-20">
      <.card label="API Authentication">
        <div class="prose prose-sm max-w-none text-gray-600">
          <p>Semua permintaan API memerlukan Header <code>Authorization</code> dengan format:</p>
          <pre class="bg-gray-50 p-4 rounded-lg overflow-x-auto text-xs">Authorization: Bearer YOUR_JWT_TOKEN</pre>
        </div>
      </.card>

      <.card label="Conversations Integration">
        <div class="space-y-4">
          <div class="border-l-4 border-primary-500 pl-4 py-2">
            <h4 class="text-sm font-bold text-gray-900">GET /api/v1/conversations</h4>
            <p class="text-xs text-gray-500 mt-1">Mengambil daftar percakapan aktif untuk user yang terautentikasi.</p>
          </div>
          <div class="border-l-4 border-green-500 pl-4 py-2">
            <h4 class="text-sm font-bold text-gray-900">POST /api/v1/conversations</h4>
            <p class="text-xs text-gray-500 mt-1">Membuat percakapan baru dengan metadata kustom.</p>
          </div>
        </div>
      </.card>

      <.card label="WebSocket Chat (Phoenix Channels)">
        <div class="prose prose-sm max-w-none text-gray-600">
          <p>Hubungkan client menggunakan configuration yang sesuai dengan App ID dan API Key Anda:</p>
          <pre class="bg-gray-900 text-green-400 p-4 rounded-lg overflow-x-auto text-xs">
    const socket = new Socket("ws://your-domain/socket", &#123;
      params: &#123;
        token: userToken,
        api_key: "YOUR_API_KEY",
        app_id: "YOUR_APP_ID",    // Harus cocok dengan API Key di dashboard
        tenant_id: "YOUR_APP_ID"  // Digunakan sebagai alias tenant di SDK
      &#125;
    &#125;);
    socket.connect();

    // Topic format: tenant:&#123;app_id&#125;:room:&#123;conversation_id&#125;
    const channel = socket.channel("tenant:YOUR_APP_ID:room:" + id, &#123;&#125;);
    channel.join().receive("ok", () => console.log("Joined!"));
          </pre>
        </div>
      </.card>
    </div>
    """
  end
end
