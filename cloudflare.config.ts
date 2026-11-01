import { bindings, defineConfig } from "cf/config";

/** The D1 database bound as `DB`. `cf d1` takes it only by ID (`db/d1.ts`). */
export const databaseId = "a571afe0-a00d-4237-b107-a285f19264ac";

/** Modes whose builds may read `DEV_AUTH_BYPASS_EMAIL` from `.dev.vars`. */
const localModes = ["development", "e2e"];

// The Worker serves the SPA built by Vite and /api/* by the MoonBit handler.
// Access to it is restricted by Cloudflare Access (configured in the dashboard).
export default defineConfig(({ mode }) => ({
  worker: {
    name: "strawboar",
    compatibilityDate: "2026-09-01",
    entrypoint: "./src/server/worker.js",
    assets: {
      notFoundHandling: "single-page-application",
      runWorkerFirst: ["/api/*"],
    },
    env: {
      DB: bindings.d1({ id: databaseId, name: "strawboar" }),
      // Worker secrets. ALLOWED_EMAILS is comma separated.
      ACCESS_TEAM_DOMAIN: bindings.secret(),
      ACCESS_AUD: bindings.secret(),
      ALLOWED_EMAILS: bindings.secret(),
      // Skips Access for localhost: never part of a production build.
      DEV_AUTH_BYPASS_EMAIL: mode !== undefined && localModes.includes(mode) && bindings.secret(),
    },
    workersDev: true,
    // Preview URLs per version would easily be left outside of Access.
    previewUrls: false,
    observability: { enabled: true },
  },
}));
