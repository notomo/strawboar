///|
using @html {div, h1, h2, li, p, span, ul}

///|
let muted = "color:var(--ui-muted-foreground)"

///|
/// Numbers, e.g. dates, days and counts, stand out from the words around them.
let number_style = "font-weight:600;font-variant-numeric:tabular-nums;color:var(--ui-foreground)"

///|
/// A text with its numbers emphasized, so that they are not buried in the words.
fn with_numbers(text : String) -> Array[Html] {
  number_words(text).mapi((i, entry) => {
    let (word, number) = entry
    let word = if i == 0 { word } else { " \{word}" }
    if number {
      span(style=["white-space:nowrap", number_style], word)
    } else {
      @html.text(word)
    }
  })
}

///|
/// Children keyed by an id, so that an element is reused only for the same item.
/// Matched by position instead, an element would be reused for another item when
/// the list changes, and the transitions of the buttons would fade it from the old one.
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
fn view(model : Model, store : Store) -> Html {
  @ui.theme(
    style=[
      "height:100dvh;display:flex;flex-direction:column;background:var(--ui-background);color:var(--ui-foreground)",
    ],
    [
      div(style=["flex-shrink:0;padding:0 1rem"], [sticky_view(model, store)]),
      // Scrolled instead of the page, so that the header and the tabs stay
      // at the top whatever their height is.
      div(
        id="dashboard",
        style=["flex:1;min-height:0;overflow-y:auto;padding:0 1rem"],
        div(
          style=[
            "box-sizing:border-box;max-width:40rem;margin:0 auto;padding:1rem 0 1.25rem",
          ],
          content_view(model, store),
        ),
      ),
      backdrop_view(model.panel_open, store),
      panel_view(model.panel, model.labels, store),
      confirm_view(model, store),
      undo_view(model.undo, store),
    ],
  )
}

///|
/// The header, the label filter and the tabs, kept at the top while scrolling.
/// It is above the backdrop like the rows raised while the panel is open,
/// so that its shadow is not hidden by them, and has its own backdrop instead.
fn sticky_view(model : Model, store : Store) -> Html {
  div(
    style=[
      "box-sizing:border-box;max-width:40rem;margin:0 auto;position:relative;z-index:12;display:flex;flex-direction:column;gap:0.75rem;padding:1.25rem 0 0.75rem;border-bottom:1px solid var(--ui-input);box-shadow:0 8px 12px -8px rgb(0 0 0 / 0.8);background:var(--ui-background)",
    ],
    [
      header_view(model, store),
      label_filter_view(model.labels, model.label_filter, store),
      match (model.load, model.today) {
        (Ready, Some(today)) => tabs_view(model, today, store)
        _ => @html.nothing
      },
      raised_backdrop_view(model.panel_open, store),
    ],
  )
}

///|
/// Closes the panel when tapping an element raised above the backdrop,
/// like `backdrop_view`. The element must be positioned.
fn raised_backdrop_view(panel_open : Bool, store : Store) -> Html {
  if !panel_open {
    return @html.nothing
  }
  div(
    style=[
      "position:absolute;inset:0;background:rgb(0 0 0 / 0.4);cursor:pointer",
    ],
    on_click=() => store.update(model => { ..model, panel_open: false, }),
    "",
  )
}

///|
fn header_view(model : Model, store : Store) -> Html {
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
        // A new chore is due today by default, which is known once the chores are loaded.
        @ui.button(
          size=Lg,
          disabled=model.today is None,
          on_click=() => store.update(model => model.open_new()),
          "+ Add",
        ),
        menu_view(store),
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
fn content_view(model : Model, store : Store) -> Html {
  match (model.load, model.today) {
    (Ready, Some(today)) => {
      let (dashboard, recent) = filtered(model, today)
      let state_of = (chore : @core.Chore) => row_state(model, chore.id)
      let labels_of = (chore : @core.Chore) => chore.labels_in(model.labels)
      div(style=["display:flex;flex-direction:column;gap:1.5rem"], [
        notice_view(model.notice),
        match model.tab {
          Soon =>
            chore_panel(Soon, dashboard.soon, chore => {
              chore_row(
                chore,
                labels_of(chore),
                today,
                state_of(chore),
                model.completing.contains(chore.id),
                store,
              )
            })
          Later =>
            chore_panel(Later, dashboard.later, chore => {
              dated_row(
                chore.id,
                chore.title,
                labels_of(chore),
                chore.next_due,
                state_of(chore),
                store,
              )
            })
          Done => recent_view(recent, model, today, store)
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
          @ui.button(
            variant=Outline,
            on_click=() => @web.reload(),
            "Reload page",
          ),
        ],
      )
    _ =>
      div(style=["display:flex;justify-content:center;padding:4rem 0"], [
        @ui.spinner(label="Loading", style=["width:2rem;height:2rem", muted]),
      ])
  }
}

///|
fn notice_view(notice : String) -> Html {
  if notice == "" {
    @html.nothing
  } else {
    p(id="notice", style=["margin:0;color:var(--ui-destructive)"], notice)
  }
}

///|
/// Filters the dashboard by a label. Hidden until a label exists, so that it takes no space.
fn label_filter_view(
  labels : Array[@core.Label],
  label_filter : Int32?,
  store : Store,
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
      @ui.button(
        size=Sm,
        variant=Outline,
        on_click=() => {
          store.update(model => {
            ..model,
            label_filter: if pressed {
              None
            } else {
              Some(label.id)
            },
          })
        },
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
fn menu_view(store : Store) -> Html {
  @ui.menu(
    id="app-menu",
    label="Menu",
    size=IconLg,
    // Wider than the icon size so that it is easy to tap.
    trigger_style=["width:3rem;font-size:1.25rem"],
    "⋮",
    [
      @ui.menu_item(
        on_select=() => store.update(model => model.open_transfer()),
        "Import / Export",
      ),
      @ui.menu_item(
        on_select=() => store.update(model => model.open_labels()),
        "Labels",
      ),
    ],
  )
}

///|
/// The menu next to the save button of the chore panel.
fn chore_menu_view(store : Store) -> Html {
  @ui.menu(
    id="chore-menu",
    label="Chore actions",
    trigger_style=["font-size:1.25rem"],
    "⋮",
    [
      @ui.menu_item(
        on_select=() => store.ask_confirm(ConfirmUndo),
        "Undo last done",
      ),
      @ui.menu_item(
        on_select=() => store.ask_confirm(ConfirmArchive),
        "Archive",
      ),
    ],
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
fn undo_view(undo : Undo?, store : Store) -> Html {
  match undo {
    None => @html.nothing
    Some(undo) =>
      div(
        style=[
          "position:fixed;z-index:100;left:50%;bottom:1rem;transform:translateX(-50%);width:min(24rem,calc(100% - 2rem))",
        ],
        // The default toast shares the page background, so raise it with a
        // lighter surface, a visible border and a filled action.
        @ui.toast(
          id="undo-toast",
          title="Done: \{undo.title}",
          action=@ui.button(
            size=Sm,
            on_click=() => store.undo_completion(undo.completion_id),
            "Undo",
          ),
          style=[
            "background:var(--ui-secondary);border-color:var(--ui-ring);box-shadow:0 8px 24px rgb(0 0 0 / 0.6)",
          ],
        ),
      )
  }
}

///|
/// Asks before an action that is hard to undo: archiving the chore or
/// deleting the label open in the panel.
fn confirm_view(model : Model, store : Store) -> Html {
  // `None` as the action only lets the dialog be closed.
  let (title, description, action) = match (model.confirm, model.panel) {
    (Some(ConfirmDeleteLabel), Some(Labels({ id: Some(_), name, .. }))) =>
      (
        "Delete label?",
        "\"\{name}\" is removed from every chore.",
        Some(("Delete", () => store.delete_label())),
      )
    (Some(ConfirmArchive), Some(ChoreEditor({ id: Some(_), title, .. }))) =>
      (
        "Archive chore?",
        "\"\{title}\" is hidden from the dashboard.",
        Some(("Archive", () => store.archive())),
      )
    (Some(ConfirmUndo), Some(ChoreEditor({ id: Some(_), title, .. }))) =>
      match model.latest_done() {
        Some(done) =>
          (
            "Undo last done?",
            "\"\{title}\" done on \{short_date(done.done_on)} is undone.",
            Some(("Undo", () => store.undo_completion(done.completion_id))),
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
  @ui.alert_dialog(
    id=CONFIRM_ID,
    closedby="any",
    attrs=@html.Attrs::build()
      .aria_labelledby("confirm-title")
      .aria_describedby("confirm-description"),
    style=["position:fixed;z-index:30"],
    @html.form(method_="dialog", [
      @ui.dialog_header([
        @ui.dialog_title(id="confirm-title", title),
        @ui.dialog_description(id="confirm-description", description),
      ]),
      @ui.dialog_footer(
        match action {
          Some((text, action)) =>
            [
              @ui.dialog_cancel("Cancel"),
              // Submitting the form closes the dialog. Closing it otherwise does nothing.
              @ui.button(
                type_="submit",
                variant=Destructive,
                on_click=action,
                text,
              ),
            ]
          None => [@ui.dialog_cancel("OK")]
        },
      ),
    ]),
  )
}
