///|
/// CSS color of a label color, readable on the dark theme.
fn color_value(color : @core.LabelColor) -> String {
  match color {
    Red => "#f87171"
    Orange => "#fb923c"
    Yellow => "#facc15"
    Green => "#4ade80"
    Teal => "#2dd4bf"
    Blue => "#60a5fa"
    Purple => "#c084fc"
    Pink => "#f472b6"
  }
}

///|
/// The look of a label, shared by every place that shows one.
/// It is tinted by its color when on, and only has a faint border of it when off,
/// so that a toggled-on label looks the same as the badge on the rows.
fn label_chip_style(color : @core.LabelColor, on~ : Bool = true) -> String {
  let color = color_value(color)
  // Hex alpha suffixes: 0x26 = 15%, 0x66 = 40%.
  if on {
    "color:\{color};background:\{color}26;border-color:\{color}66"
  } else {
    "border-color:\{color}66"
  }
}

///|
/// Without the transition of rui, a badge reused for another label on a tab
/// switch would fade from the color of the previous one.
fn label_badge(label : @core.Label) -> Html {
  @rui.badge(
    variant=Outline,
    style=["font-weight:400;transition:none", label_chip_style(label.color)],
    label.name,
  )
}

///|
/// A label that can be turned on and off, used by the label filter and the chore panel.
fn label_toggle(
  label : @core.Label,
  pressed : Bool,
  on_click : Msg,
  emit : Emit[Msg],
) -> Html {
  @rui.button(
    size=Sm,
    variant=Outline,
    on_click=emit(on_click),
    attrs=@html.Attrs::build().aria_pressed(pressed.to_string()),
    style=[
      "flex-shrink:0;font-weight:400",
      label_chip_style(label.color, on=pressed),
    ],
    label.name,
  )
}

///|
fn labels_view(labels : Array[@core.Label]) -> Html {
  if labels.is_empty() {
    return @html.nothing
  }
  span(
    style=["display:flex;gap:0.25rem;flex-shrink:0"],
    labels.map(label_badge),
  )
}
