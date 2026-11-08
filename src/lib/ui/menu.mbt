// A menu of actions under a button, shown as a popover: the browser puts it
// above everything else and closes it on Escape or a click outside of it,
// giving the focus back to the button.

///|
/// Which edge of the button the menu is aligned to.
pub(all) enum MenuAlign {
  Start
  End
}

///|
fn content_id(id : String) -> String {
  "\{id}-content"
}

///|
fn menu_items(menu : @dom.Node) -> Array[@dom.Node] {
  menu.query_all("[role=\"menuitem\"]")
}

///|
/// Whether the menu was open when the pointer went down on its button.
/// The popover is closed by then as the button is outside of it, so the
/// click must not open it again.
fn was_open(trigger : @dom.Node) -> Bool {
  trigger.attribute("data-was-open") == Some("true")
}

///|
fn toggle(id : String) -> Unit {
  guard @dom.element_by_id(id) is Some(trigger) &&
    @dom.element_by_id(content_id(id)) is Some(menu) else {
    return
  }
  if was_open(trigger) {
    trigger.set_attribute("data-was-open", "false")
    return
  }
  match menu.matches(":popover-open") {
    true => menu.hide_popover()
    false => {
      menu.show_popover()
      if menu_items(menu) is [first, ..] {
        first.focus()
      }
    }
  }
}

///|
fn hide(id : String) -> Unit {
  if @dom.element_by_id(content_id(id)) is Some(menu) &&
    menu.matches(":popover-open") {
    menu.hide_popover()
  }
}

///|
fn move_between_items(event : @dom.Event) -> Unit {
  guard event.target().closest("[role=\"menu\"]") is Some(menu) else { return }
  let items = menu_items(menu)
  let last = items.length() - 1
  let current = items.search_by(item => item.matches(":focus"))
  let next = match (event.key(), current) {
    ("ArrowDown", Some(i)) => Some(if i == last { 0 } else { i + 1 })
    ("ArrowUp", Some(i)) => Some(if i == 0 { last } else { i - 1 })
    ("ArrowDown", None) | ("Home", _) => Some(0)
    ("ArrowUp", None) | ("End", _) => Some(last)
    _ => None
  }
  if next is Some(next) && last >= 0 {
    event.prevent_default()
    items[next].focus()
  }
}

///|
/// A button that opens a menu of `items` made with `menu_item`.
/// `label` names both the button and the menu.
pub fn[C : @html.IsChildren] menu(
  id~ : String,
  label~ : String,
  variant~ : ButtonVariant = Ghost,
  size~ : ButtonSize = Icon,
  align~ : MenuAlign = End,
  trigger_style~ : Array[String] = [],
  trigger : C,
  items : Array[@html.Html],
) -> @html.Html {
  let anchor = "--ui-menu-\{id}"
  @html.fragment([
    button(
      id~,
      variant~,
      size~,
      on_click=() => toggle(id),
      attrs=@html.Attrs::build()
        .aria_label(label)
        .aria_haspopup("menu")
        .aria_controls(content_id(id))
        .on_pointerdown(_ => {
          if @dom.element_by_id(id) is Some(trigger) &&
            @dom.element_by_id(content_id(id)) is Some(menu) {
            trigger.set_attribute(
              "data-was-open",
              menu.matches(":popover-open").to_string(),
            )
          }
        }),
      style=["anchor-name:\{anchor}", ..trigger_style],
      trigger,
    ),
    @html.div(
      class="ui-menu",
      id=content_id(id),
      // A click on an item closes the menu after the item handles it.
      on_click=() => hide(id),
      attrs=@html.Attrs::build()
        .popover("auto")
        .role("menu")
        .aria_label(label)
        .on_keydown(move_between_items),
      style=[
        "position-anchor:\{anchor}",
        match align {
          Start => "--ui-menu-area:bottom span-right"
          End => "--ui-menu-area:bottom span-left"
        },
      ],
      items,
    ),
  ])
}

///|
pub fn menu_item(on_select~ : () -> Unit, text : String) -> @html.Html {
  @html.button(
    class="ui-menu-item",
    type_="button",
    on_click=on_select,
    attrs=@html.Attrs::build().role("menuitem").tabindex(-1),
    text,
  )
}
