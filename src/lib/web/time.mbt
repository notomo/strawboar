///|
/// Current UNIX time in seconds.
pub extern "js" fn now_seconds() -> Double =
  #| () => Date.now() / 1000

///|
extern "js" fn sleep_ffi(ms : Int32) -> @js_async.Promise[Unit] =
  #| (ms) => new Promise((resolve) => setTimeout(resolve, ms))

///|
pub async fn sleep(ms : Int32) -> Unit {
  sleep_ffi(ms).wait()
}
