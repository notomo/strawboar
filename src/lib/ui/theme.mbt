// A small set of dark-themed components on top of the HTML of Rabbita.
// Each component renders native elements with a class of ui.css, which
// index.html loads, so that hover, focus and open states live in CSS. Inline
// `style` passed to a component is applied last and overrides its class.

///|
fn attrs_or_new(attrs : @html.Attrs?) -> @html.Attrs {
  match attrs {
    Some(attrs) => attrs.copy()
    None => @html.Attrs::build()
  }
}

///|
/// The root of the components, which ui.css gives the colors of the theme.
pub fn[C : @html.IsChildren] theme(
  style~ : Array[String] = [],
  children : C,
) -> @html.Html {
  @html.div(class="ui-theme", style~, children)
}
