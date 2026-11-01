import { execFileSync } from "node:child_process";
import { defineConfig, type Plugin } from "vite";
import rabbita from "@rabbita/vite";
import { cloudflare } from "@cloudflare/vite-plugin";

// The Worker environment, named after the Worker in cloudflare.config.ts.
const workerEnvironment = "strawboar";

export default defineConfig({
  // index.html loads the app as /main.js; the rest of the app lives in its package.
  publicDir: "src/app/public",
  plugins: [
    rabbita({ mainPkgDir: "src/app" }),
    moonbitServer(),
    cloudflare({
      // Each E2E project has its own local D1.
      persistState: { path: process.env.STRAWBOAR_STATE_DIR ?? ".cloudflare/state" },
    }),
  ],
});

/** The MoonBit server package that src/server/worker.js imports. */
const serverModule = "/_build/js/release/build/server/server.js";

/**
 * Builds the MoonBit packages that src/server/worker.js imports from _build,
 * and rebuilds them and reloads the Worker on changes in dev.
 * The server package is wrapped into a function that returns its exports (see worker.js).
 */
function moonbitServer(): Plugin {
  const build = () => execFileSync("moon", ["build", "--target", "js", "--release"], { stdio: "inherit" });
  return {
    name: "moonbit-server",
    config(_, { isPreview }) {
      if (!isPreview) {
        build();
      }
    },
    transform(code, id) {
      if (!id.endsWith(serverModule)) {
        return;
      }
      const exports = /\nexport \{([^}]*)\}\s*$/.exec(code);
      if (exports === null) {
        this.error("no export list at the end of the MoonBit output");
      }
      const entries = exports[1].split(",").map((entry) => {
        const [local, exported = local] = entry.trim().split(/\s+as\s+/);
        return `${exported}: ${local}`;
      });
      const body = code.slice(0, exports.index);
      return { code: `export default function load() {\n${body}\nreturn { ${entries.join(", ")} };\n}\n`, map: null };
    },
    configureServer(server) {
      server.watcher.on("change", (file) => {
        if (!/\.(mbt|mbti)$|moon\.(pkg|mod)(\.json)?$/.test(file)) {
          return;
        }
        try {
          build();
        } catch {
          return; // moon has printed the errors.
        }
        const environment = server.environments[workerEnvironment];
        environment.moduleGraph.invalidateAll();
        environment.hot.send({ type: "full-reload" });
      });
    },
  };
}
