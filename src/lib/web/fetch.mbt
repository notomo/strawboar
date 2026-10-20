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
