///|
/// Reloads the page.
pub extern "js" fn reload() -> Unit =
  #| () => location.reload()

///|
/// Navigates to `url`, keeping the current page in the history.
pub extern "js" fn navigate(url : String) -> Unit =
  #| (url) => location.assign(url)
