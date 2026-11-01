///|
/// Bindings and variables configured in `cloudflare.config.ts`.
#external
pub type Env

///|
/// Returns the string variable, or an empty string when it is not set.
pub extern "js" fn Env::string_var(self : Env, name : String) -> String =
  #| (env, name) => typeof env[name] === "string" ? env[name] : ""

///|
pub extern "js" fn Env::d1(self : Env, name : String) -> D1Database =
  #| (env, name) => env[name]
