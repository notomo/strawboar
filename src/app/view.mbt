///|
using @html {div, h1, h2, li, p, span, ul}

///|
let muted = "color:var(--rui-muted-foreground)"

///|
/// Children keyed by an id, so that an element is reused only for the same item.
/// Matched by position instead, an element would be reused for another item when
/// the list changes, and the transitions of rui would fade it from the old one.
/// A key includes the kind of the id, e.g. `chore-1`, because the same list
/// element can show other kinds of items, like the list of each tab.
fn[T] keyed(
  items : Array[T],
  key : (T) -> String,
  view : (T) -> Html,
) -> Map[String, Html] {
  Map::from_array(items.map(item => (key(item), view(item))))
}

///|
fn view(
  model : Model,
  menu : Html,
  chore_menu : Html,
  emit : Emit[Msg],
) -> Html {
  @rui.theme(
    mode=Dark,
    style=[
      "height:100dvh;display:flex;flex-direction:column;background:var(--rui-background);color:var(--rui-foreground)",
    ],
    [
      div(style=["flex-shrink:0;padding:0 1rem"], [
        sticky_view(model, menu, emit),
      ]),
      // Scrolled instead of the page, so that the header and the tabs stay
      // at the top whatever their height is.
      div(
        id="dashboard",
        style=["flex:1;min-height:0;overflow-y:auto;padding:0 1rem"],
        div(
          style=[
            "box-sizing:border-box;max-width:40rem;margin:0 auto;padding:1rem 0 1.25rem",
          ],
          content_view(model, emit),
        ),
      ),
      backdrop_view(model.panel_open, emit),
      panel_view(model.panel, model.labels, chore_menu, emit),
      confirm_view(model, emit),
      undo_view(model.undo, emit),
    ],
  )
}

///|
/// The header, the label filter and the tabs, kept at the top while scrolling.
/// It is above the backdrop like the rows raised while the panel is open,
/// so that its shadow is not hidden by them, and has its own backdrop instead.
fn sticky_view(model : Model, menu : Html, emit : Emit[Msg]) -> Html {
  div(
    style=[
      "box-sizing:border-box;max-width:40rem;margin:0 auto;position:relative;z-index:12;display:flex;flex-direction:column;gap:0.75rem;padding:1.25rem 0 0.75rem;border-bottom:1px solid var(--rui-input);box-shadow:0 8px 12px -8px rgb(0 0 0 / 0.8);background:var(--rui-background)",
    ],
    [
      header_view(model, menu, emit),
      label_filter_view(model.labels, model.label_filter, emit),
      match (model.load, model.today) {
        (Ready, Some(today)) => tabs_view(model, today, emit)
        _ => @html.nothing
      },
      raised_backdrop_view(model.panel_open, emit),
    ],
  )
}

///|
/// Closes the panel when tapping an element raised above the backdrop,
/// like `backdrop_view`. The element must be positioned.
fn raised_backdrop_view(panel_open : Bool, emit : Emit[Msg]) -> Html {
  if !panel_open {
    return @html.nothing
  }
  div(
    style=[
      "position:absolute;inset:0;background:rgb(0 0 0 / 0.4);cursor:pointer",
    ],
    on_click=emit(ClosePanel),
    "",
  )
}

///|
fn header_view(model : Model, menu : Html, emit : Emit[Msg]) -> Html {
  div(
    style=[
      "display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:0.5rem",
    ],
    [
      // The buttons wrap below the date on a narrow screen.
      h1(
        id="today",
        style=["margin:0;font-size:1.5rem;font-weight:600;white-space:nowrap"],
        model.today.map(long_date).unwrap_or(""),
      ),
      div(style=["display:flex;gap:0.25rem;margin-left:auto"], [
        @rui.button(size=Lg, on_click=emit(OpenNew), "+ Add"),
        menu,
      ]),
    ],
  )
}

///|
/// The dashboard and the completions of the last days, with the label filter applied.
fn filtered(
  model : Model,
  today : @core.Date,
) -> (@core.Dashboard, Array[@core.RecentDone]) {
  let chores = match model.label_filter {
    Some(id) => model.chores.filter(chore => chore.has_label(id))
    None => model.chores
  }
  // Completions of archived chores are hidden while filtering.
  let recent = match model.label_filter {
    Some(_) =>
      model.recent.filter(done => {
        chores.iter().any(chore => chore.id == done.chore_id)
      })
    None => model.recent
  }
  (@core.Dashboard::new(chores, today), recent)
}

///|
fn content_view(model : Model, emit : Emit[Msg]) -> Html {
  match (model.load, model.today) {
    (Ready, Some(today)) => {
      let (dashboard, recent) = filtered(model, today)
      let state_of = (chore : @core.Chore) => row_state(model, chore.id)
      let labels_of = (chore : @core.Chore) => chore.labels_in(model.labels)
      div(style=["display:flex;flex-direction:column;gap:1.5rem"], [
        notice_view(model.notice),
        match model.tab {
          Soon =>
            chore_panel(Soon, soon_caption(dashboard), dashboard.soon, chore => {
              chore_row(
                chore,
                labels_of(chore),
                today,
                state_of(chore),
                model.completing.contains(chore.id),
                emit,
              )
            })
          Later =>
            chore_panel(Later, None, dashboard.later, chore => {
              dated_row(
                chore.id,
                chore.title,
                labels_of(chore),
                chore.next_due,
                state_of(chore),
                emit,
              )
            })
          Done => recent_view(recent, model, today, emit)
        },
      ])
    }
    (Failed, _) =>
      div(
        style=[
          "display:flex;flex-direction:column;gap:0.5rem;align-items:flex-start",
        ],
        [
          p(
            style=["margin:0"],
            "Failed to load chores. Reloading the page also signs in again if the session has expired.",
          ),
          @rui.button(variant=Outline, on_click=emit(ReloadPage), "Reload page"),
        ],
      )
    _ =>
      div(style=["display:flex;justify-content:center;padding:4rem 0"], [
        @rui.spinner(label="Loading", style=["width:2rem;height:2rem", muted]),
      ])
  }
}

///|
fn notice_view(notice : String) -> Html {
  if notice == "" {
    @html.nothing
  } else {
    p(id="notice", style=["margin:0;color:var(--rui-destructive)"], notice)
  }
}

///|
/// Filters the dashboard by a label. Hidden until a label exists, so that it takes no space.
fn label_filter_view(
  labels : Array[@core.Label],
  label_filter : Int32?,
  emit : Emit[Msg],
) -> Html {
  if labels.is_empty() {
    return @html.nothing
  }
  div(
    id="label-filter",
    attrs=@html.Attrs::build().role("group").aria_label("Filter by label"),
    // Padded so that the ring of the active label is not cut off by the scroll,
    // with a negative margin to keep the labels aligned with the header.
    style=[
      "display:flex;gap:0.75rem;overflow-x:auto;min-width:0;padding:4px;margin:-4px",
    ],
    keyed(labels, label => "label-\{label.id}", label => {
      let pressed = label_filter == Some(label.id)
      // Shown like the badges on the rows, with the ring of the label being
      // edited in the labels panel on the active one.
      // Clicking the active label clears the filter.
      @rui.button(
        size=Sm,
        variant=Outline,
        on_click=emit(
          FilterByLabel(if pressed { None } else { Some(label.id) }),
        ),
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
    }),
  )
}

///|
/// The menu next to the add button, for actions used less often.
/// It is stateful, so it is created once and passed to `view`.
fn menu_view(emit : Emit[Msg]) -> Val[Html] {
  @rui.dropdown_menu(id="app-menu", menu => {
    span([
      @rui.dropdown_menu_trigger(
        menu,
        variant=Ghost,
        size=IconLg,
        aria_label="Menu",
        // Wider than the icon size so that it is easy to tap.
        style=["width:3rem;font-size:1.25rem"],
        "⋮",
      ),
      @rui.dropdown_menu_content(
        menu,
        align=End,
        aria_label="Menu",
        // Fit the items instead of the default minimum width.
        style=["--rui-menu-min-width:0"],
        [
          menu_item(menu, emit(OpenTransfer), "Import / Export"),
          menu_item(menu, emit(OpenLabels), "Labels"),
        ],
      ),
    ])
  })
}

///|
/// The menu next to the save button of the chore panel. It is created once
/// like the app menu, so its items do not depend on the chore.
fn chore_menu_view(emit : Emit[Msg]) -> Val[Html] {
  @rui.dropdown_menu(id="chore-menu", menu => {
    span([
      @rui.dropdown_menu_trigger(
        menu,
        variant=Ghost,
        size=Icon,
        aria_label="Chore actions",
        style=["font-size:1.25rem"],
        "⋮",
      ),
      @rui.dropdown_menu_content(
        menu,
        align=End,
        aria_label="Chore actions",
        style=["--rui-menu-min-width:0"],
        [
          menu_item(menu, emit(AskConfirm(ConfirmUndo)), "Undo last done"),
          menu_item(menu, emit(AskConfirm(ConfirmArchive)), "Archive"),
        ],
      ),
    ])
  })
}

///|
fn menu_item(
  menu : @rui.DropdownMenuScope,
  on_select : Cmd,
  label : String,
) -> Html {
  @rui.dropdown_menu_item(
    menu,
    on_select~,
    style=["padding:0.5rem 0.75rem"],
    label,
  )
}

///|
/// How a chore row relates to the editor panel.
enum RowState {
  /// The panel is closed.
  Normal
  /// The chore is open in the panel.
  Selected
  /// The panel is open for another chore (or a new one).
  Behind
}

///|
fn undo_view(undo : Undo?, emit : Emit[Msg]) -> Html {
  match undo {
    None => @html.nothing
    Some(undo) =>
      div(
        style=[
          "position:fixed;z-index:100;left:50%;bottom:1rem;transform:translateX(-50%);width:min(24rem,calc(100% - 2rem))",
        ],
        // The default toast shares the page background, so raise it with a
        // lighter surface, a visible border and a filled action.
        @rui.toast(
          open=true,
          id="undo-toast",
          style=[
            "align-items:center;background:var(--rui-secondary);border-color:var(--rui-ring);box-shadow:0 8px 24px rgb(0 0 0 / 0.6)",
          ],
          [
            @rui.toast_title("Done: \{undo.title}"),
            @rui.button(
              size=Sm,
              slot="toast-action",
              on_click=emit(UndoCompletion(undo.completion_id)),
              "Undo",
            ),
          ],
        ),
      )
  }
}

///|
/// Asks before an action that is hard to undo: archiving the chore or
/// deleting the label open in the panel.
fn confirm_view(model : Model, emit : Emit[Msg]) -> Html {
  // `None` as the action only lets the dialog be closed.
  let (title, description, action) = match (model.confirm, model.panel) {
    (Some(ConfirmDeleteLabel), Some(Labels({ id: Some(_), name, .. }))) =>
      (
        "Delete label?",
        "\"\{name}\" is removed from every chore.",
        Some(("Delete", DeleteLabel)),
      )
    (Some(ConfirmArchive), Some(ChoreEditor({ id: Some(_), title, .. }))) =>
      (
        "Archive chore?",
        "\"\{title}\" is hidden from the dashboard.",
        Some(("Archive", Archive)),
      )
    (Some(ConfirmUndo), Some(ChoreEditor({ id: Some(_), title, .. }))) =>
      match model.latest_done() {
        Some(done) =>
          (
            "Undo last done?",
            "\"\{title}\" done on \{short_date(done.done_on)} is undone.",
            Some(("Undo", UndoCompletion(done.completion_id))),
          )
        None =>
          (
            "Nothing to undo",
            "\"\{title}\" was not done in the last 7 days.",
            None,
          )
      }
    _ => ("", "", None)
  }
  @rui.alert_dialog(
    id=CONFIRM_ID,
    closedby="any",
    attrs=@html.Attrs::build()
      .aria_labelledby("confirm-title")
      .aria_describedby("confirm-description"),
    style=["position:fixed;z-index:30"],
    @html.form(method_="dialog", [
      @rui.alert_dialog_header([
        @rui.alert_dialog_title(id="confirm-title", title),
        @rui.alert_dialog_description(id="confirm-description", description),
      ]),
      @rui.alert_dialog_footer(
        match action {
          Some((text, msg)) =>
            [
              @rui.alert_dialog_cancel("Cancel"),
              // Submitting the form closes the dialog. Closing it otherwise does nothing.
              @rui.button(
                type_="submit",
                variant=Destructive,
                on_click=emit(msg),
                text,
              ),
            ]
          None => [@rui.alert_dialog_cancel("OK")]
        },
      ),
    ]),
  )
}
