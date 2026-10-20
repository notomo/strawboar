///|
/// Current UNIX time in seconds.
pub extern "js" fn now_seconds() -> Double =
  #| () => Date.now() / 1000
