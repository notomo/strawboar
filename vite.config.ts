import { defineConfig } from "vite";
import rabbita from "@rabbita/vite";

export default defineConfig({
  // index.html and public/ live next to the MoonBit main package.
  root: "src/app",
  build: {
    outDir: "../../dist",
    emptyOutDir: true,
  },
  plugins: [
    rabbita({ mainPkgDir: "src/app" }),
    {
      // The app also depends on packages outside the root (e.g. src/core).
      name: "watch-src",
      configureServer(server) {
        server.watcher.add("src");
      },
    },
  ],
  server: {
    proxy: {
      // `node --run dev:worker`
      "/api": "http://localhost:8787",
    },
  },
});
