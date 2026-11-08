// HTML to render: elements built with the functions of elements.mbt, which
// render.mbt turns into the DOM and updates by their differences.

///|
/// An element to render.
struct Element {
  tag : String
  /// Identifies the element among its siblings, so that the same element is
  /// updated when they are reordered. See `IsChildren` for `Map`.
  key : String?
  attrs : Array[(String, String)]
  /// The `value` property of an input or a text area.
  value : String?
  handlers : Array[(String, (@dom.Event) -> Unit)]
  children : Array[Html]
}

///|
pub enum Html {
  Element(Element)
  Text(String)
  /// Children rendered in place of it, without an element around them.
  Fragment(Array[Html])
}

///|
/// Renders nothing.
pub let nothing : Html = Fragment([])

///|
pub fn text(text : String) -> Html {
  Text(text)
}

///|
pub fn fragment(children : Array[Html]) -> Html {
  Fragment(children)
}

///|
/// What can be given as the children of an element.
pub(open) trait IsChildren {
  fn to_children(Self) -> Array[Html]
}

///|
pub impl IsChildren for String with fn to_children(self) {
  [Text(self)]
}

///|
pub impl IsChildren for Html with fn to_children(self) {
  [self]
}

///|
pub extend Html with IsChildren::{to_children}

///|
pub impl IsChildren for Array[Html] with fn to_children(self) {
  self
}

///|
/// Children keyed by the keys of the map, in its order.
pub impl IsChildren for Map[String, Html] with fn to_children(self) {
  self
  .iter()
  .map(entry => {
    let (key, html) = entry
    match html {
      Element(element) => Element({ ..element, key: Some(key), })
      html => html
    }
  })
  .collect()
}
