///|
extern "js" fn fetch_text_ffi(url : String) -> @js_async.Promise[String] =
  #| async (url) => {
  #|   const response = await fetch(url);
  #|   if (!response.ok) {
  #|     throw new Error(`failed to fetch ${url}: ${response.status}`);
  #|   }
  #|   return response.text();
  #| }

///|
pub async fn fetch_text(url : String) -> String {
  fetch_text_ffi(url).wait()
}

///|
extern "js" fn send_ffi(
  method_ : String,
  url : String,
  body : String,
  has_body : Bool,
  content_type : String,
) -> @js_async.Promise[String] =
  #| async (method, url, body, hasBody, contentType) => {
  #|   const response = await fetch(url, hasBody
  #|     ? { method, body, headers: { "content-type": contentType } }
  #|     : { method });
  #|   if (!response.ok) {
  #|     throw new Error(`${method} ${url} failed: ${response.status}`);
  #|   }
  #|   return response.text();
  #| }

///|
/// Sends a request and returns the body of its response, or fails if the
/// response is not successful (2xx).
pub async fn send(
  method_~ : String,
  url : String,
  body? : String,
  content_type~ : String = "text/plain;charset=UTF-8",
) -> String {
  send_ffi(method_, url, body.unwrap_or(""), body is Some(_), content_type).wait()
}

///|
/// Starts `f` on the event loop of MoonBit's async and gives its result to
/// `on_done`, so that a caller outside of it (e.g. a UI event) can run it.
pub fn[A] spawn(
  f : async () -> A,
  on_done : (Result[A, Error]) -> Unit,
) -> Unit {
  @js_async.Promise::from_async(() => {
    let result : Result[A, Error] = try f() catch {
      error => Err(error)
    } noraise {
      value => Ok(value)
    }
    on_done(result)
  })
  |> ignore
}
