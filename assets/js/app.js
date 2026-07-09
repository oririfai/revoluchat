// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// 1. { "esbuild": "...", "tailwind": "..." } in your package.json
//    and then `import "..."` here.
//
// 2. Add them as dependencies to your mix.exs project
//    and then `import "..."` here (e.g. `import "phoenix_html"`).

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
// import topbar from "topbar";

// ─── Hooks ───────────────────────────────────────────────────────────────────

/**
 * MessageVolumeChart Hook
 * Renders a bar chart showing message volume for the last 7 days.
 * Uses Chart.js (loaded via CDN in root.html.heex).
 * Data is passed via the `data-stats` attribute as JSON.
 */
const MessageVolumeChart = {
  chart: null,

  mounted() {
    this.renderChart();
  },

  updated() {
    // LiveView pushed new data — re-render
    this.renderChart();
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }
  },

  renderChart() {
    // Wait for Chart.js to be available (loaded via CDN)
    if (typeof Chart === "undefined") {
      setTimeout(() => this.renderChart(), 100);
      return;
    }

    const raw = this.el.dataset.stats;
    if (!raw) return;

    let stats;
    try {
      stats = JSON.parse(raw);
    } catch (e) {
      console.error("[MessageVolumeChart] Invalid JSON in data-stats:", e);
      return;
    }

    const labels = stats.map((s) => {
      // Format "YYYY-MM-DD" to short day label e.g. "Jul 8"
      const d = new Date(s.date + "T00:00:00");
      return d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
    });
    const data = stats.map((s) => s.count);

    // Destroy previous chart instance to avoid canvas reuse error
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }

    // Get or create canvas element
    let canvas = this.el.querySelector("canvas");
    if (!canvas) {
      canvas = document.createElement("canvas");
      canvas.style.width = "100%";
      canvas.style.height = "100%";
      this.el.appendChild(canvas);
    }

    const ctx = canvas.getContext("2d");

    // Gradient fill
    const gradient = ctx.createLinearGradient(0, 0, 0, 220);
    gradient.addColorStop(0, "rgba(14, 165, 233, 0.45)");
    gradient.addColorStop(1, "rgba(14, 165, 233, 0.02)");

    this.chart = new Chart(ctx, {
      type: "bar",
      data: {
        labels,
        datasets: [
          {
            label: "Messages",
            data,
            backgroundColor: gradient,
            borderColor: "rgba(14, 165, 233, 0.85)",
            borderWidth: 2,
            borderRadius: 6,
            borderSkipped: false,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "#0f172a",
            titleColor: "#94a3b8",
            bodyColor: "#f1f5f9",
            borderColor: "#1e293b",
            borderWidth: 1,
            padding: 10,
            callbacks: {
              label: (ctx) => ` ${ctx.parsed.y.toLocaleString()} messages`,
            },
          },
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: {
              color: "#94a3b8",
              font: { size: 12 },
            },
            border: { display: false },
          },
          y: {
            beginAtZero: true,
            grid: {
              color: "rgba(148, 163, 184, 0.08)",
            },
            ticks: {
              color: "#94a3b8",
              font: { size: 12 },
              maxTicksLimit: 5,
              callback: (val) =>
                val >= 1000 ? `${(val / 1000).toFixed(1)}K` : val,
            },
            border: { display: false },
          },
        },
        animation: {
          duration: 500,
          easing: "easeInOutQuart",
        },
      },
    });
  },
};

// ─── LiveSocket Setup ─────────────────────────────────────────────────────────

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: {
    MessageVolumeChart,
  },
});

// Show progress bar on live navigation and form submits
// topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
// window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
// window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for debugging
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
