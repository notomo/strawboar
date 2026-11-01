// Worker entry: delegates to the MoonBit handler in this package.
//
// The top-level code of the MoonBit module generates a random hash seed, which Workers disallow
// in global scope, so vite.config.ts wraps the module into a function that runs on the first request.
import load from "../../_build/js/release/build/server/server.js";

let handler;

export default {
  async fetch(request, env) {
    handler ??= load();
    return handler.fetch(request, env);
  },
};
