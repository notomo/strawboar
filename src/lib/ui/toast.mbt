///|
/// A short message, announced politely, with an optional action after it.
pub fn toast(
  id~ : String,
  title~ : String,
  action? : @html.Html,
  style~ : Array[String] = [],
) -> @html.Html {
  @html.div(
    class="ui-toast",
    id~,
    attrs=@html.Attrs::build()
      .role("status")
      .aria_live("polite")
      .aria_atomic("true"),
    style~,
    [@html.div(class="ui-toast-title", title), action.unwrap_or(@html.nothing)],
  )
}
