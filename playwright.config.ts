import { defineConfig, devices } from "@playwright/test";

const isCI = !!process.env.CI;
const baseURL = "http://localhost:8787";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: isCI,
  retries: isCI ? 2 : 0,
  workers: isCI ? 1 : undefined,
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
    // Serves the built assets and the Worker with local D1 (`.dev.vars` is required).
    command: "npm run preview",
    url: `${baseURL}/api/summary`,
    reuseExistingServer: !isCI,
    timeout: 180_000,
  },
});
