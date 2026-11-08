///|
/// Attributes and event handlers of an element, built by chaining.
pub struct Attrs {
  priv attrs : Array[(String, String)]
  priv handlers : Array[(String, (@dom.Event) -> Unit)]
}

///|
pub fn Attrs::build() -> Attrs {
  { attrs: [], handlers: [], }
}

///|
pub fn Attrs::copy(self : Attrs) -> Attrs {
  { attrs: self.attrs.copy(), handlers: self.handlers.copy(), }
}

///|
/// Not public: an attribute name from outside could be an event handler
/// (`onclick`) or a URL (`href`) taking user data. Add a helper with a fixed
/// name instead, like the ones below.
fn Attrs::attr(self : Attrs, name : String, value : String) -> Attrs {
  self.attrs.push((name, value))
  self
}

///|
/// Sets a boolean attribute, which is present only if `value`.
fn Attrs::flag(self : Attrs, name : String, value : Bool) -> Attrs {
  if value {
    self.attr(name, "")
  } else {
    self
  }
}

///|
/// Not public, like `attr`: handlers are added with helpers of fixed names.
fn Attrs::on(
  self : Attrs,
  name : String,
  handler : (@dom.Event) -> Unit,
) -> Attrs {
  self.handlers.push((name, handler))
  self
}

///|
pub fn Attrs::role(self : Attrs, value : String) -> Attrs {
  self.attr("role", value)
}

///|
pub fn Attrs::tabindex(self : Attrs, value : Int32) -> Attrs {
  self.attr("tabindex", value.to_string())
}

///|
/// Sets `data-{name}`.
pub fn Attrs::data_set(self : Attrs, name : String, value : String) -> Attrs {
  self.attr("data-\{name}", value)
}

///|
pub fn Attrs::popover(self : Attrs, value : String) -> Attrs {
  self.attr("popover", value)
}

///|
pub fn Attrs::autofocus(self : Attrs, value : Bool) -> Attrs {
  self.flag("autofocus", value)
}

///|
pub fn Attrs::formnovalidate(self : Attrs, value : Bool) -> Attrs {
  self.flag("formnovalidate", value)
}

///|
pub fn Attrs::aria_label(self : Attrs, value : String) -> Attrs {
  self.attr("aria-label", value)
}

///|
pub fn Attrs::aria_labelledby(self : Attrs, value : String) -> Attrs {
  self.attr("aria-labelledby", value)
}

///|
pub fn Attrs::aria_describedby(self : Attrs, value : String) -> Attrs {
  self.attr("aria-describedby", value)
}

///|
pub fn Attrs::aria_controls(self : Attrs, value : String) -> Attrs {
  self.attr("aria-controls", value)
}

///|
pub fn Attrs::aria_current(self : Attrs, value : String) -> Attrs {
  self.attr("aria-current", value)
}

///|
pub fn Attrs::aria_pressed(self : Attrs, value : String) -> Attrs {
  self.attr("aria-pressed", value)
}

///|
pub fn Attrs::aria_selected(self : Attrs, value : String) -> Attrs {
  self.attr("aria-selected", value)
}

///|
pub fn Attrs::aria_hidden(self : Attrs, value : String) -> Attrs {
  self.attr("aria-hidden", value)
}

///|
pub fn Attrs::aria_haspopup(self : Attrs, value : String) -> Attrs {
  self.attr("aria-haspopup", value)
}

///|
pub fn Attrs::aria_live(self : Attrs, value : String) -> Attrs {
  self.attr("aria-live", value)
}

///|
pub fn Attrs::aria_atomic(self : Attrs, value : String) -> Attrs {
  self.attr("aria-atomic", value)
}

///|
pub fn Attrs::on_keydown(self : Attrs, handler : (@dom.Event) -> Unit) -> Attrs {
  self.on("keydown", handler)
}

///|
pub fn Attrs::on_pointerdown(
  self : Attrs,
  handler : (@dom.Event) -> Unit,
) -> Attrs {
  self.on("pointerdown", handler)
}
