///|
/// A Fetch API `Request` passed to the Worker.
#external
pub type Request

///|
pub extern "js" fn Request::method_(self : Request) -> String =
  #| (r) => r.method

///|
pub extern "js" fn Request::pathname(self : Request) -> String =
  #| (r) => new URL(r.url).pathname

///|
pub extern "js" fn Request::hostname(self : Request) -> String =
  #| (r) => new URL(r.url).hostname

///|
/// Returns the header value, or an empty string when the header is absent.
pub extern "js" fn Request::header(self : Request, name : String) -> String =
  #| (r, name) => r.headers.get(name) ?? ""

///|
/// A Fetch API `Response` returned from the Worker.
#external
pub type Response

///|
pub extern "js" fn Response::json(body : String, status : Int) -> Response =
  #| (body, status) => new Response(body, {
  #|   status,
  #|   headers: {
  #|     "content-type": "application/json; charset=utf-8",
  #|     "cache-control": "no-store",
  #|   },
  #| })

///|
/// Bindings and variables configured in `wrangler.jsonc`.
#external
pub type Env

///|
/// Returns the string variable, or an empty string when it is not set.
pub extern "js" fn Env::string_var(self : Env, name : String) -> String =
  #| (env, name) => typeof env[name] === "string" ? env[name] : ""

///|
pub extern "js" fn Env::d1(self : Env, name : String) -> D1Database =
  #| (env, name) => env[name]
