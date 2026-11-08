// Elements with the attributes and events this app uses, as optional
// arguments. `attrs` adds the others, by the helpers of `Attrs` with fixed names.

///|
/// The attributes shared by every element, applied after `attrs`.
fn common(
  attrs : Attrs?,
  id : String?,
  class : String?,
  style : Array[String],
) -> Attrs {
  let attrs = match attrs {
    Some(attrs) => attrs.copy()
    None => Attrs::build()
  }
  if id is Some(id) {
    attrs.attr("id", id) |> ignore
  }
  if class is Some(class) {
    attrs.attr("class", class) |> ignore
  }
  let style = style.filter(s => s != "")
  if !style.is_empty() {
    attrs.attr("style", style.join(";")) |> ignore
  }
  attrs
}

///|
fn make(
  tag : String,
  attrs : Attrs,
  children : Array[Html],
  value? : String,
) -> Html {
  Element({
    tag,
    key: None,
    attrs: attrs.attrs,
    value,
    handlers: attrs.handlers,
    children,
  })
}

///|
fn Attrs::on_click(self : Attrs, handler : (() -> Unit)?) -> Attrs {
  match handler {
    Some(f) => self.on("click", _ => f())
    None => self
  }
}

///|
/// Reads the value of the input or the text area on each change.
fn Attrs::on_input(self : Attrs, handler : ((String) -> Unit)?) -> Attrs {
  match handler {
    Some(f) => self.on("input", event => f(event.target().value()))
    None => self
  }
}

///|
pub fn[C : IsChildren] div(
  style~ : Array[String] = [],
  id? : String,
  class? : String,
  hidden~ : Bool = false,
  on_click? : () -> Unit,
  attrs? : Attrs,
  children : C,
) -> Html {
  let attrs = common(attrs, id, class, style)
    .flag("hidden", hidden)
    .on_click(on_click)
  make("div", attrs, children.to_children())
}

///|
pub fn[C : IsChildren] span(
  style~ : Array[String] = [],
  class? : String,
  attrs? : Attrs,
  children : C,
) -> Html {
  make("span", common(attrs, None, class, style), children.to_children())
}

///|
pub fn[C : IsChildren] ul(
  style~ : Array[String] = [],
  id? : String,
  children : C,
) -> Html {
  make("ul", common(None, id, None, style), children.to_children())
}

///|
pub fn[C : IsChildren] li(
  style~ : Array[String] = [],
  attrs? : Attrs,
  children : C,
) -> Html {
  make("li", common(attrs, None, None, style), children.to_children())
}

///|
pub fn[C : IsChildren] p(
  style~ : Array[String] = [],
  id? : String,
  class? : String,
  children : C,
) -> Html {
  make("p", common(None, id, class, style), children.to_children())
}

///|
pub fn[C : IsChildren] h1(
  style~ : Array[String] = [],
  id? : String,
  children : C,
) -> Html {
  make("h1", common(None, id, None, style), children.to_children())
}

///|
pub fn[C : IsChildren] h2(
  style~ : Array[String] = [],
  id? : String,
  class? : String,
  attrs? : Attrs,
  children : C,
) -> Html {
  make("h2", common(attrs, id, class, style), children.to_children())
}

///|
pub fn[C : IsChildren] button(
  style~ : Array[String] = [],
  id? : String,
  class? : String,
  type_~ : String = "button",
  disabled~ : Bool = false,
  on_click? : () -> Unit,
  attrs? : Attrs,
  children : C,
) -> Html {
  let attrs = common(attrs, id, class, style)
    .attr("type", type_)
    .flag("disabled", disabled)
    .on_click(on_click)
  make("button", attrs, children.to_children())
}

///|
/// A form. `on_submit` replaces the default submission, which a form without
/// it keeps, e.g. `method="dialog"` closing its dialog.
pub fn[C : IsChildren] form(
  style~ : Array[String] = [],
  id? : String,
  class? : String,
  method_? : String,
  on_submit? : () -> Unit,
  children : C,
) -> Html {
  let attrs = common(None, id, class, style)
  if method_ is Some(method_) {
    attrs.attr("method", method_) |> ignore
  }
  if on_submit is Some(f) {
    attrs.on("submit", event => {
      event.prevent_default()
      f()
    })
    |> ignore
  }
  make("form", attrs, children.to_children())
}

///|
pub fn[C : IsChildren] label(
  class? : String,
  for_? : String,
  id? : String,
  children : C,
) -> Html {
  let attrs = common(None, id, class, [])
  if for_ is Some(for_) {
    attrs.attr("for", for_) |> ignore
  }
  make("label", attrs, children.to_children())
}

///|
pub(all) enum InputType {
  Text
  Number
  Date
}

///|
pub fn input(
  class? : String,
  id? : String,
  input_type~ : InputType = Text,
  value? : String,
  maxlength? : Int32,
  min? : Int32,
  max? : Int32,
  inputmode? : String,
  placeholder? : String,
  on_input? : (String) -> Unit,
) -> Html {
  let attrs = common(None, id, class, []).attr(
    "type",
    match input_type {
      Text => "text"
      Number => "number"
      Date => "date"
    },
  )
  let optional = [
    ("maxlength", maxlength.map(n => n.to_string())),
    ("min", min.map(n => n.to_string())),
    ("max", max.map(n => n.to_string())),
    ("inputmode", inputmode),
    ("placeholder", placeholder),
  ]
  optional.each(entry => {
    if entry.1 is Some(value) {
      attrs.attr(entry.0, value) |> ignore
    }
  })
  make("input", attrs.on_input(on_input), [], value?)
}

///|
pub fn textarea(
  style~ : Array[String] = [],
  class? : String,
  id? : String,
  value? : String,
  rows? : Int32,
  maxlength? : Int32,
  placeholder? : String,
  wrap? : String,
  on_input? : (String) -> Unit,
) -> Html {
  let attrs = common(None, id, class, style)
  let optional = [
    ("rows", rows.map(n => n.to_string())),
    ("maxlength", maxlength.map(n => n.to_string())),
    ("placeholder", placeholder),
    ("wrap", wrap),
  ]
  optional.each(entry => {
    if entry.1 is Some(value) {
      attrs.attr(entry.0, value) |> ignore
    }
  })
  make("textarea", attrs.on_input(on_input), [], value?)
}

///|
/// A `<dialog>`. `on_close` runs whenever it closes, e.g. by Escape.
pub fn[C : IsChildren] dialog(
  style~ : Array[String] = [],
  id? : String,
  class? : String,
  closedby? : String,
  on_close? : () -> Unit,
  attrs? : Attrs,
  children : C,
) -> Html {
  let attrs = common(attrs, id, class, style)
  if closedby is Some(closedby) {
    attrs.attr("closedby", closedby) |> ignore
  }
  if on_close is Some(f) {
    attrs.on("close", _ => f()) |> ignore
  }
  make("dialog", attrs, children.to_children())
}
