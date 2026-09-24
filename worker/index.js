// Worker entry: delegates to the MoonBit handler (src/worker).
//
// The MoonBit module is imported lazily because its top-level code
// generates a random hash seed, which Workers disallow in global scope.
let handler;

export default {
  async fetch(request, env) {
    handler ??= await import("../_build/js/release/build/worker/worker.js");
    return handler.fetch(request, env);
  },
};
