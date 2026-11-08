///|
pub(all) enum ButtonVariant {
  Default
  Outline
  Ghost
  Destructive
}

///|
pub(all) enum ButtonSize {
  Default
  Sm
  Lg
  Icon
  IconSm
  IconLg
}

///|
fn ButtonVariant::value(self : ButtonVariant) -> String {
  match self {
    Default => "default"
    Outline => "outline"
    Ghost => "ghost"
    Destructive => "destructive"
  }
}

///|
fn ButtonSize::value(self : ButtonSize) -> String {
  match self {
    Default => "default"
    Sm => "sm"
    Lg => "lg"
    Icon => "icon"
    IconSm => "icon-sm"
    IconLg => "icon-lg"
  }
}

///|
pub fn[C : @html.IsChildren] button(
  variant~ : ButtonVariant = Default,
  size~ : ButtonSize = Default,
  disabled~ : Bool = false,
  type_~ : String = "button",
  id? : String,
  on_click? : () -> Unit,
  attrs? : @html.Attrs,
  style~ : Array[String] = [],
  children : C,
) -> @html.Html {
  @html.button(
    class="ui-button",
    id?,
    type_~,
    disabled~,
    on_click?,
    attrs=attrs_or_new(attrs)
      .data_set("variant", variant.value())
      .data_set("size", size.value()),
    style~,
    children,
  )
}

///|
pub(all) enum BadgeVariant {
  Secondary
  Outline
}

///|
pub fn[C : @html.IsChildren] badge(
  variant~ : BadgeVariant = Secondary,
  style~ : Array[String] = [],
  children : C,
) -> @html.Html {
  @html.span(
    class="ui-badge",
    attrs=@html.Attrs::build().data_set(
      "variant",
      match variant {
        Secondary => "secondary"
        Outline => "outline"
      },
    ),
    style~,
    children,
  )
}

///|
pub fn spinner(label~ : String, style~ : Array[String] = []) -> @html.Html {
  @html.span(
    class="ui-spinner",
    attrs=@html.Attrs::build().role("status").aria_label(label),
    style~,
    "",
  )
}

///|
/// A label and its control, stacked.
pub fn field(children : Array[@html.Html]) -> @html.Html {
  @html.div(class="ui-field", children)
}

///|
pub fn field_label(for_? : String, id? : String, text : String) -> @html.Html {
  @html.label(class="ui-label", for_?, id?, text)
}

///|
/// An error of a form, announced when it appears.
pub fn field_error(id~ : String, text : String) -> @html.Html {
  @html.div(
    class="ui-field-error",
    id~,
    attrs=@html.Attrs::build().role("alert"),
    text,
  )
}

///|
pub fn input(
  id~ : String,
  input_type~ : @html.InputType = Text,
  value~ : String,
  maxlength? : Int32,
  min? : Int32,
  max? : Int32,
  inputmode? : String,
  placeholder? : String,
  on_input~ : (String) -> Unit,
) -> @html.Html {
  @html.input(
    class="ui-input",
    id~,
    input_type~,
    value~,
    maxlength?,
    min?,
    max?,
    inputmode?,
    placeholder?,
    on_input~,
  )
}

///|
pub fn textarea(
  id~ : String,
  value~ : String,
  rows~ : Int32,
  maxlength? : Int32,
  placeholder? : String,
  wrap? : String,
  style~ : Array[String] = [],
  on_input~ : (String) -> Unit,
) -> @html.Html {
  @html.textarea(
    class="ui-input",
    id~,
    value~,
    rows~,
    maxlength?,
    placeholder?,
    wrap?,
    style~,
    on_input~,
  )
}
