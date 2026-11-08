///|
/// A list of tabs, which moves between them with the arrow keys.
/// A tab is selected when it gets the focus, as its panel is cheap to show.
pub fn tabs_list(
  aria_label? : String,
  attrs? : @html.Attrs,
  style~ : Array[String] = [],
  children : Array[@html.Html],
) -> @html.Html {
  let attrs = attrs_or_new(attrs).role("tablist").on_keydown(move_between_tabs)
  if aria_label is Some(label) {
    ignore(attrs.aria_label(label))
  }
  @html.div(class="ui-tabs-list", attrs~, style~, children)
}

///|
fn move_between_tabs(event : @dom.KeyboardEvent) -> @cmd.Cmd {
  let step = match event.key() {
    "ArrowRight" | "ArrowDown" => Some(1)
    "ArrowLeft" | "ArrowUp" => Some(-1)
    "Home" => Some(-1000)
    "End" => Some(1000)
    _ => None
  }
  guard step is Some(step) &&
    event.target().to_element() is Some(target) &&
    target.closest("[role=\"tablist\"]") is Some(list) else {
    return @cmd.none
  }
  let tabs = list
    .query_selector_all("[role=\"tab\"]")
    .iter()
    .filter_map(tab => tab.to_html_element())
    .to_array()
  guard tabs.search_by(tab => tab.matches(":focus")) is Some(current) else {
    return @cmd.none
  }
  event.prevent_default()
  let next = (current + step).clamp(min=0, max=tabs.length() - 1)
  tabs[next].focus()
  tabs[next].click()
  @cmd.none
}

///|
pub fn[C : @html.IsChildren] tab(
  id~ : String,
  selected~ : Bool,
  controls~ : String,
  on_select~ : @cmd.Cmd,
  style~ : Array[String] = [],
  children : C,
) -> @html.Html {
  @html.button(
    class="ui-tab",
    id~,
    type_="button",
    on_click=on_select,
    attrs=@html.Attrs::build()
      .role("tab")
      .aria_selected(selected.to_string())
      .aria_controls(controls)
      // Only the selected tab is in the tab order; the arrow keys reach the others.
      .tabindex(if selected { 0 } else { -1 }),
    style~,
    children,
  )
}

///|
/// The panel of a tab, hidden unless it is selected.
pub fn[C : @html.IsChildren] tab_panel(
  id~ : String,
  labelledby~ : String,
  selected~ : Bool,
  style~ : Array[String] = [],
  children : C,
) -> @html.Html {
  @html.div(
    class="ui-tab-panel",
    id~,
    hidden=!selected,
    attrs=@html.Attrs::build()
      .role("tabpanel")
      .aria_labelledby(labelledby)
      .tabindex(0),
    style~,
    children,
  )
}
