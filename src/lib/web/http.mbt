///|
/// A Fetch API `Request`.
#external
pub type Request

///|
pub extern "js" fn Request::method_(self : Request) -> String =
  #| (r) => r.method

///|
pub extern "js" fn Request::pathname(self : Request) -> String =
  #| (r) => new URL(r.url).pathname

///|
/// The origin of the request URL, e.g. `https://example.com`.
pub extern "js" fn Request::origin(self : Request) -> String =
  #| (r) => new URL(r.url).origin

///|
pub extern "js" fn Request::hostname(self : Request) -> String =
  #| (r) => new URL(r.url).hostname

///|
/// Returns the header value, or an empty string when the header is absent.
pub extern "js" fn Request::header(self : Request, name : String) -> String =
  #| (r, name) => r.headers.get(name) ?? ""

///|
extern "js" fn Request::text_ffi(self : Request) -> @js_async.Promise[String] =
  #| (r) => r.text()

///|
pub async fn Request::text(self : Request) -> String {
  self.text_ffi().wait()
}

///|
/// A Fetch API `Response`.
#external
pub type Response

///|
extern "js" fn Response::new_ffi(
  body : String,
  has_body : Bool,
  status : Int32,
  headers : String,
) -> Response =
  #| (body, hasBody, status, headers) =>
  #|   new Response(hasBody ? body : null, { status, headers: JSON.parse(headers) })

///|
pub fn Response::json(
  body : String,
  status : Int32,
  headers~ : Map[String, String] = {},
) -> Response {
  let headers = headers.copy()
  headers["content-type"] = "application/json; charset=utf-8"
  Response::new_ffi(body, true, status, Json(headers).stringify())
}

///|
/// A response without body, e.g. `204 No Content`.
pub fn Response::empty(
  status : Int32,
  headers~ : Map[String, String] = {},
) -> Response {
  Response::new_ffi("", false, status, Json(headers).stringify())
}
