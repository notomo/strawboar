///|
/// Reloads the page.
pub extern "js" fn reload() -> Unit =
  #| () => location.reload()
