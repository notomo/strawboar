import { defineConfig, devices } from "@playwright/test";

const isCI = !!process.env.CI;
const baseURL = "http://localhost:8788";

export default defineConfig({
  testDir: "./e2e",
  // Tests share one local D1 database.
  fullyParallel: false,
  forbidOnly: isCI,
  retries: isCI ? 2 : 0,
  workers: 1,
  reporter: "html",
  use: {
    baseURL,
    trace: "on-first-retry",
  },

  projects: [
    {
      name: "desktop",
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "mobile",
      use: { ...devices["Pixel 7"] },
    },
  ],

  webServer: {
    // Serves the built assets and the Worker with a fresh local D1 (`.dev.vars` is required).
    command: "npm run build && npm run e2e:server",
    url: `${baseURL}/api/chores`,
    reuseExistingServer: false,
    timeout: 180_000,
  },
});
