import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";

/** Emits exactly app.js (one ES module) and style.css; scripts/build-web.ts places them in web/. */
export default defineConfig({
  root: fileURLToPath(new URL("./web-src", import.meta.url)),
  publicDir: false,
  plugins: [react(), tailwindcss()],
  resolve: { alias: { "@": fileURLToPath(new URL("./web-src", import.meta.url)) } },
  build: {
    emptyOutDir: true,
    modulePreload: false,
    cssCodeSplit: false,
    assetsInlineLimit: 0,
    rollupOptions: {
      input: fileURLToPath(new URL("./web-src/main.tsx", import.meta.url)),
      output: { entryFileNames: "app.js", assetFileNames: "style.css", codeSplitting: false },
    },
  },
});
