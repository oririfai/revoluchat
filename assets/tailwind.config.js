const plugin = require("tailwindcss/plugin");
const fs = require("fs");
const path = require("path");

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/revoluchat_web.ex",
    "../lib/revoluchat_web/**/*.*ex",
    "../deps/petal_components/**/*.*ex",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: "#ecfdf5",
          100: "#d1fae5",
          200: "#a7f3d0",
          300: "#6ee7b7",
          400: "#34d399",
          500: "#10b981",
          600: "#059669",
          700: "#047857",
          800: "#065f46",
          900: "#064e3b",
          950: "#022c22",
        },
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography"),
    require("@tailwindcss/aspect-ratio"),
    // Embeds Heroicons (2.1.1) into your app.css bundle
    // See your `mix.exs` for the heroicons dependency
    plugin(({ addComponents, theme }) => {
      let iconsDir = path.join(__dirname, "../deps/heroicons/optimized");
      let values = {};
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
        ["-micro", "/16/solid"],
      ];
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach((file) => {
          let name = path.basename(file, ".svg") + suffix;
          values[name] = { name, fullPath: path.join(iconsDir, dir, file) };
        });
      });
      addComponents({
        ".hero": {
          display: "inline-block",
          fill: "currentColor",
        },
        ...Object.entries(values).reduce((acc, [name, { fullPath }]) => {
          let content = fs
            .readFileSync(fullPath)
            .toString()
            .replace(/\r?\n|\r/g, "");
          let size = name.endsWith("-micro")
            ? theme("spacing.4")
            : theme("spacing.5");
          return {
            ...acc,
            [`.hero-${name}`]: {
              content: `url('data:image/svg+xml;utf8,${content}')`,
              "-webkit-mask-repeat": "no-repeat",
              "mask-repeat": "no-repeat",
              "-webkit-mask-size": "contain",
              "mask-size": "contain",
              "background-color": "currentColor",
              "-webkit-mask-image": `url('data:image/svg+xml;utf8,${content}')`,
              "mask-image": `url('data:image/svg+xml;utf8,${content}')`,
              "background-image": "none",
              width: size,
              height: size,
            },
          };
        }, {}),
      });
    }),
  ],
};
