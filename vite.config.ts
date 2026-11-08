import { execFileSync } from "node:child_process";
import path from "node:path";
import { defineConfig, type Plugin } from "vite";
import { cloudflare } from "@cloudflare/vite-plugin";

// The Vite environment of the Worker, which the moonbit plugin reloads on changes.
const workerEnvironment = "strawboar";

export default defineConfig({
  // index.html loads the app as /main.js; the rest of the app lives in its package.
  publicDir: "src/app/public",
  plugins: [
    moonbit(),
    cloudflare({
      // Named explicitly, as the plugin otherwise names it `ssr`.
      viteEnvironment: { name: workerEnvironment },
      // Each E2E project has its own local D1.
      persistState: { path: process.env.STRAWBOAR_STATE_DIR ?? ".cloudflare/state" },
    }),
  ],
});

// Outputs of `moon build`, relative to the root.
const buildDir = "_build/js/release/build";
/** The MoonBit app package, which index.html loads as /main.js. */
const appModule = `${buildDir}/app/app.js`;
/** The MoonBit server package that src/server/worker.js imports. */
const serverModule = `/${buildDir}/server/server.js`;

/**
 * Builds the MoonBit packages into _build, and rebuilds them and reloads the
 * page and the Worker on changes in dev.
 * The app package is served as /main.js. The server package is wrapped into a
 * function that returns its exports (see worker.js).
 */
function moonbit(): Plugin {
  const build = () => execFileSync("moon", ["build", "--target", "js", "--release"], { stdio: "inherit" });
  let root = process.cwd();
  return {
    name: "moonbit",
    config(_, { isPreview }) {
      if (!isPreview) {
        build();
      }
      // The outputs change on every build, which the watcher below handles.
      return { server: { watch: { ignored: ["**/_build/**", "**/.mooncakes/**"] } } };
    },
    configResolved(config) {
      root = config.root;
    },
    resolveId(id) {
      if (id === "/main.js") {
        return path.resolve(root, appModule);
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
        for (const environment of [server.environments.client, server.environments[workerEnvironment]]) {
          environment.moduleGraph.invalidateAll();
          environment.hot.send({ type: "full-reload" });
        }
      });
    },
  };
}
