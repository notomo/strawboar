import { defineConfig, devices } from "@playwright/test";

const isCI = !!process.env.CI;

// Each project has its own Worker and local D1 so that the projects run in parallel,
// while the tests in a project share the database and run one by one.
const projects = [
  { name: "desktop", port: 8788, use: devices["Desktop Chrome"] },
  { name: "mobile", port: 8789, use: devices["Pixel 7"] },
  // WebKit needs system libraries: `npx playwright install-deps webkit`
  { name: "tablet", port: 8790, use: devices["iPad Pro 11 landscape"] },
];

const e2eDir = ".cloudflare/e2e";
const baseURL = (port: number) => `http://localhost:${port}`;

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: false,
  forbidOnly: isCI,
  retries: isCI ? 2 : 0,
  workers: projects.length,
  reporter: "html",
  use: {
    trace: "on-first-retry",
  },

  projects: projects.map(({ name, port, use }) => ({
    name,
    use: { ...use, baseURL: baseURL(port) },
  })),

  // Web servers start one by one, so the first one builds the assets and copies a migrated local D1 for all.
  webServer: projects.map(({ name, port }, i) => ({
    // Previews the build (in the e2e mode, so `.dev.vars` is required) with a fresh local D1.
    command: [
      ...(i === 0 ? ["node --run e2e:prepare", ...projects.map((p) => `cp -r ${e2eDir}/template ${e2eDir}/${p.name}`)] : []),
      `npx vite preview --port ${port} --strictPort`,
    ].join(" && "),
    env: { STRAWBOAR_STATE_DIR: `${e2eDir}/${name}` },
    url: `${baseURL(port)}/api/chores`,
    reuseExistingServer: false,
    timeout: 180_000,
  })),
});
