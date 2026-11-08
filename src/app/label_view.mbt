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
/// The look of a label, shared by every place that shows one,
/// so that a label looks the same as the badge on the rows.
fn label_chip_style(color : @core.LabelColor) -> String {
  let color = color_value(color)
  // Hex alpha suffixes: 0x26 = 15%, 0x66 = 40%.
  "color:\{color};background:\{color}26;border-color:\{color}66"
}

///|
/// A ring around a selected label or color, used by every place where
/// labels are picked or toggled.
fn selected_ring_style(color : @core.LabelColor) -> String {
  let color = color_value(color)
  "box-shadow:0 0 0 2px var(--ui-background),0 0 0 4px \{color}"
}

///|
fn label_badge(label : @core.Label) -> Html {
  @ui.badge(
    variant=Outline,
    style=["font-weight:400", label_chip_style(label.color)],
    label.name,
  )
}

///|
/// A label that can be turned on and off, used by the chore panel.
/// A label that is on has the ring, like the active one of the label filter.
fn label_toggle(
  label : @core.Label,
  pressed : Bool,
  on_click : () -> Unit,
) -> Html {
  @ui.button(
    size=Sm,
    variant=Outline,
    on_click~,
    attrs=@html.Attrs::build().aria_pressed(pressed.to_string()),
    style=[
      "flex-shrink:0;font-weight:400",
      label_chip_style(label.color),
      if pressed {
        selected_ring_style(label.color)
      } else {
        ""
      },
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
    keyed(labels, label => "label-\{label.id}", label_badge),
  )
}
