import { defineConfig } from "vite";
import rabbita from "@rabbita/vite";

export default defineConfig({
  plugins: [rabbita({ mainPkgDir: "src/app" })],
  server: {
    proxy: {
      // `npm run dev:worker`
      "/api": "http://localhost:8787",
    },
  },
});
