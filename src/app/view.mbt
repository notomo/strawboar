///|
using @html {div, h1, h2, li, p, span, ul}

///|
let muted = "color:var(--rui-muted-foreground)"

///|
/// Width of the editor panel (rui sheet).
let panel_width = "24rem"

///|
fn view(model : Model, emit : Emit[Msg]) -> Html {
  @rui.theme(
    mode=Dark,
    style=[
      "min-height:100dvh;background:var(--rui-background);color:var(--rui-foreground)",
    ],
    [
      div(
        style=[
          "box-sizing:border-box;padding:1.25rem 1rem;max-width:40rem;margin:0 auto;display:flex;flex-direction:column;gap:1.5rem",
        ],
        [header_view(model, emit), content_view(model, emit)],
      ),
      backdrop_view(model.panel_open, emit),
      panel_view(model.panel, emit),
      undo_view(model.undo, emit),
    ],
  )
}

///|
fn header_view(model : Model, emit : Emit[Msg]) -> Html {
  div(
    style=[
      "display:flex;align-items:center;justify-content:space-between;gap:0.5rem",
    ],
    [
      h1(
        id="today",
        style=["margin:0;font-size:1.5rem;font-weight:600"],
        model.today.map(long_date).unwrap_or(""),
      ),
      div(style=["display:flex;gap:0.5rem"], [
        @rui.button(
          variant=Outline,
          on_click=emit(OpenTransfer),
          "Import / Export",
        ),
        @rui.button(on_click=emit(OpenNew), "+ Add chore"),
      ]),
    ],
  )
}

///|
fn content_view(model : Model, emit : Emit[Msg]) -> Html {
  match (model.load, model.today) {
    (Ready, Some(today)) => {
      let chores = match model.label_filter {
        Some(label) => model.chores.filter(chore => chore.has_label(label))
        None => model.chores
      }
      let dashboard = @core.Dashboard::new(chores, today)
      let state_of = (chore : @core.Chore) => row_state(model, chore.id)
      div(style=["display:flex;flex-direction:column;gap:1.5rem"], [
        notice_view(model.notice),
        label_filter_view(model.chores, model.label_filter, emit),
        if model.chores.is_empty() {
          p(style=["margin:0", muted], "No chores yet. Add one to get started.")
        } else if dashboard.due.is_empty() && dashboard.soon.is_empty() {
          p(style=["margin:0", muted], "Nothing due. Enjoy your day.")
        } else {
          @html.nothing
        },
        chore_section("due", "Due", dashboard.due, chore => {
          chore_row(chore, today, state_of(chore), emit)
        }),
        chore_section("soon", "Soon", dashboard.soon, chore => {
          chore_row(chore, today, state_of(chore), emit)
        }),
        chore_section("later", "Later", dashboard.later, chore => {
          later_row(chore, state_of(chore), emit)
        }),
        recent_view(model.recent, emit),
      ])
    }
    (Failed, _) =>
      div(
        style=[
          "display:flex;flex-direction:column;gap:0.5rem;align-items:flex-start",
        ],
        [
          p(style=["margin:0"], "Failed to load chores."),
          @rui.button(variant=Outline, on_click=emit(Reload), "Retry"),
        ],
      )
    _ => @rui.spinner(label="Loading")
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
/// Filters the dashboard by a label. Hidden until some chore has a label.
fn label_filter_view(
  chores : Array[@core.Chore],
  label_filter : String?,
  emit : Emit[Msg],
) -> Html {
  let labels = @core.all_labels(chores)
  if labels.is_empty() {
    return @html.nothing
  }
  let chip = (text : String, value : String?) => {
    let pressed = label_filter == value
    @rui.button(
      size=Sm,
      variant=if pressed { Default } else { Outline },
      on_click=emit(FilterByLabel(value)),
      attrs=@html.Attrs::build().aria_pressed(pressed.to_string()),
      style=["flex-shrink:0"],
      text,
    )
  }
  div(
    id="label-filter",
    attrs=@html.Attrs::build().role("group").aria_label("Filter by label"),
    style=["display:flex;gap:0.5rem;overflow-x:auto;margin-bottom:-0.5rem"],
    [chip("All", None), ..labels.map(label => chip("#\{label}", Some(label)))],
  )
}

///|
fn section_title(title : String) -> Html {
  h2(
    style=[
      "margin:0 0 0.5rem;font-size:0.75rem;font-weight:600;letter-spacing:0.08em;text-transform:uppercase",
      muted,
    ],
    title,
  )
}

///|
fn list_style() -> String {
  "list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:0.5rem"
}

///|
fn chore_section(
  id : String,
  title : String,
  chores : Array[@core.Chore],
  row : (@core.Chore) -> Html,
) -> Html {
  if chores.is_empty() {
    return @html.nothing
  }
  @html.section(id~, [
    section_title(title),
    ul(style=[list_style()], chores.map(row)),
  ])
}

///|
fn card_style() -> String {
  "display:flex;align-items:center;gap:0.5rem;padding:0.375rem;border:1px solid var(--rui-border);border-radius:var(--rui-radius);background:var(--rui-card)"
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
fn row_state(model : Model, chore_id : Int) -> RowState {
  match (model.panel_open, model.selected_id()) {
    (false, _) => Normal
    (true, Some(id)) if id == chore_id => Selected
    (true, _) => Behind
  }
}

///|
/// A row of a chore. The one open in the editor is highlighted and raised above
/// the backdrop; it ignores taps so that tapping it closes the panel like the backdrop.
fn card(state : RowState, content : Array[Html]) -> Html {
  if state is Selected {
    li(
      attrs=@html.Attrs::build().aria_current("true"),
      style=[
        card_style(),
        "position:relative;z-index:11;pointer-events:none;border-color:var(--rui-primary);box-shadow:0 0 0 1px var(--rui-primary);background:var(--rui-accent)",
      ],
      content,
    )
  } else {
    li(style=[card_style()], content)
  }
}

///|
fn labels_view(labels : Array[String]) -> Html {
  if labels.is_empty() {
    return @html.nothing
  }
  span(
    style=["display:flex;gap:0.25rem;flex-shrink:0"],
    labels.map(label => {
      @rui.badge(variant=Secondary, style=["font-weight:400"], label)
    }),
  )
}

///|
/// The clickable area that opens the editor. It shows a chevron so it reads as a link.
/// While the panel is open for another chore, it is raised above the backdrop so
/// that tapping it switches the panel to this chore.
fn edit_area(
  chore_id : Int,
  state : RowState,
  emit : Emit[Msg],
  content : Array[Html],
) -> Html {
  @rui.button(
    variant=Ghost,
    on_click=emit(OpenEdit(chore_id)),
    style=[
      "flex:1;min-width:0;height:auto;justify-content:space-between;gap:0.75rem;padding:0.625rem 0.75rem;text-align:left;white-space:normal;font-weight:inherit",
      match state {
        Behind => "position:relative;z-index:11"
        Normal | Selected => ""
      },
    ],
    [
      div(
        style=[
          "display:flex;flex-direction:column;gap:0.25rem;min-width:0;flex:1",
        ],
        content,
      ),
      span(
        attrs=@html.Attrs::build().aria_hidden("true"),
        style=["font-size:1.25rem;line-height:1", muted],
        "›",
      ),
    ],
  )
}

///|
fn title_text(title : String, labels : Array[String]) -> Html {
  span(style=["display:flex;align-items:center;gap:0.5rem;min-width:0"], [
    span(
      style=[
        "font-size:1rem;font-weight:500;overflow:hidden;text-overflow:ellipsis;white-space:nowrap",
      ],
      title,
    ),
    labels_view(labels),
  ])
}

///|
fn chore_row(
  chore : @core.Chore,
  today : @core.Date,
  state : RowState,
  emit : Emit[Msg],
) -> Html {
  card(state, [
    edit_area(chore.id, state, emit, [
      title_text(chore.title, chore.labels),
      span(style=["font-size:0.8125rem", muted], chore_meta(chore, today)),
    ]),
    @rui.button(
      variant=Outline,
      on_click=emit(Complete(chore.id)),
      attrs=@html.Attrs::build().aria_label("Done: \{chore.title}"),
      style=["flex-shrink:0;margin-right:0.25rem"],
      "✓ Done",
    ),
  ])
}

///|
fn later_row(chore : @core.Chore, state : RowState, emit : Emit[Msg]) -> Html {
  card(state, [
    edit_area(chore.id, state, emit, [
      div(
        style=[
          "display:flex;align-items:baseline;justify-content:space-between;gap:0.75rem",
        ],
        [
          title_text(chore.title, chore.labels),
          span(
            style=["font-size:0.8125rem;flex-shrink:0", muted],
            short_date(chore.next_due),
          ),
        ],
      ),
    ]),
  ])
}

///|
/// Number of completions shown in "Done this week".
let recent_limit = 5

///|
fn recent_view(recent : Array[@core.RecentDone], emit : Emit[Msg]) -> Html {
  if recent.is_empty() {
    return @html.nothing
  }
  let hidden = recent.length() - recent_limit
  @html.section(id="recent", [
    section_title("Done this week"),
    ul(
      style=[list_style(), "gap:0.25rem;font-size:0.875rem", muted],
      [
        ..recent
        .iter()
        .take(recent_limit)
        .map(done => {
          li(
            style=[
              "display:flex;align-items:center;gap:0.75rem;min-height:1.75rem;padding:0 0.75rem",
            ],
            [
              span(
                style=[
                  "flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap",
                ],
                "✓ \{done.title}",
              ),
              if done.can_undo(recent) {
                @rui.button(
                  size=Xs,
                  variant=Ghost,
                  on_click=emit(UndoCompletion(done.completion_id)),
                  attrs=@html.Attrs::build().aria_label("Undo: \{done.title}"),
                  style=["flex-shrink:0"],
                  "Undo",
                )
              } else {
                @html.nothing
              },
              span(style=["flex-shrink:0"], short_date(done.done_on)),
            ],
          )
        })
        .collect(),
        if hidden > 0 {
          li(style=["padding:0 0.75rem"], "and \{hidden} more")
        } else {
          @html.nothing
        },
      ],
    ),
  ])
}

///|
fn history_view(history : HistoryState) -> Html {
  let text = match history {
    Loading => "Loading..."
    Fetched(dates) => history_text(dates)
    Unavailable => "Failed to load history."
  }
  div(
    id="chore-history",
    style=["display:flex;flex-direction:column;gap:0.25rem"],
    [
      span(style=["font-size:0.875rem;font-weight:500"], "History"),
      span(style=["font-size:0.875rem", muted], text),
    ],
  )
}

///|
fn field_view(id : String, label : String, input : Html) -> Html {
  @rui.field([@rui.field_label(for_=id, label), input])
}

///|
/// Closes the panel when tapping outside of it. The native `closedby` light
/// dismiss is not supported by every browser (e.g. on tablets), so it is disabled.
/// `cursor:pointer` makes iOS Safari dispatch taps on this plain element.
fn backdrop_view(panel_open : Bool, emit : Emit[Msg]) -> Html {
  if !panel_open {
    return @html.nothing
  }
  div(
    id="editor-backdrop",
    style=[
      "position:fixed;inset:0;z-index:10;background:rgb(0 0 0 / 0.4);cursor:pointer",
    ],
    on_click=emit(ClosePanel),
    "",
  )
}

///|
/// A non-modal panel over the right side of the dashboard.
fn panel_view(panel : Panel?, emit : Emit[Msg]) -> Html {
  @rui.sheet(
    id=EDITOR_ID,
    side=SheetRight,
    closedby="closerequest",
    on_close=emit.map(_ => PanelClosed),
    attrs=@html.Attrs::build().aria_labelledby("panel-title"),
    style=[
      "position:fixed;z-index:20;width:min(\{panel_width},100vw);max-width:100vw;box-shadow:-8px 0 24px rgb(0 0 0 / 0.4)",
    ],
    match panel {
      None => []
      Some(ChoreEditor(editor)) => editor_content(editor, emit)
      Some(Transfer(transfer)) => transfer_content(transfer, emit)
    },
  )
}

///|
fn editor_content(editor : Editor, emit : Emit[Msg]) -> Array[Html] {
  let is_new = editor.id is None
  [
    @rui.sheet_header([
      @rui.sheet_title(
        id="panel-title",
        if is_new {
          "New chore"
        } else {
          "Edit chore"
        },
      ),
    ]),
    @html.form(
      on_submit=emit(Submit),
      style=[
        "display:flex;flex-direction:column;gap:1.25rem;padding-bottom:1rem;flex:1",
      ],
      [
        field_view(
          "chore-title",
          "Title",
          @rui.input(
            id="chore-title",
            value=editor.title,
            maxlength=@core.MAX_TITLE_LENGTH,
            on_input=emit.map(value => TitleChanged(value)),
          ),
        ),
        field_view(
          "chore-interval",
          "Every (days)",
          @rui.input(
            id="chore-interval",
            input_type=Number,
            inputmode="numeric",
            min=1,
            max=@core.MAX_INTERVAL_DAYS,
            value=editor.interval,
            on_input=emit.map(value => IntervalChanged(value)),
          ),
        ),
        if is_new {
          field_view(
            "chore-next-due",
            "First due",
            @rui.input(
              id="chore-next-due",
              input_type=Date,
              value=editor.next_due,
              on_input=emit.map(value => NextDueChanged(value)),
            ),
          )
        } else {
          @html.nothing
        },
        field_view(
          "chore-labels",
          "Labels",
          @rui.input(
            id="chore-labels",
            value=editor.labels,
            placeholder="e.g. kitchen, weekly",
            on_input=emit.map(value => LabelsChanged(value)),
          ),
        ),
        if is_new {
          @html.nothing
        } else {
          history_view(editor.history)
        },
        if editor.error == "" {
          @html.nothing
        } else {
          @rui.field_error(id="chore-editor-error", editor.error)
        },
        div(
          style=[
            "display:flex;justify-content:space-between;gap:0.5rem;margin-top:auto",
          ],
          [
            if is_new {
              span("")
            } else {
              @rui.button(
                type_="button",
                variant=Ghost,
                on_click=emit(Archive),
                "Archive",
              )
            },
            @rui.button(type_="submit", "Save"),
          ],
        ),
      ],
    ),
  ]
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
fn transfer_content(transfer : Transfer, emit : Emit[Msg]) -> Array[Html] {
  [
    @rui.sheet_header([
      // Focusing the text area would put the caret at the end and scroll it
      // to the bottom, so the title takes the initial focus instead.
      @rui.sheet_title(
        id="panel-title",
        attrs=@html.Attrs::build().autofocus(true).tabindex(-1),
        style=["outline:none"],
        "Import / Export",
      ),
      @rui.sheet_description(
        "Copy the chores below to export them. To import, edit or paste chores and press Import: chores with the same title are updated and others are added.",
      ),
    ]),
    @html.form(
      on_submit=emit(Import),
      style=[
        "display:flex;flex-direction:column;gap:1.25rem;padding-bottom:1rem;flex:1",
      ],
      [
        field_view(
          "chore-definitions",
          "Chores (JSON)",
          @rui.textarea(
            id="chore-definitions",
            value=transfer.text,
            wrap="off",
            rows=14,
            // A fixed height keeps the Import button in view for long lists.
            style=[
              "field-sizing:fixed;font-family:monospace;font-size:0.8125rem",
            ],
            on_input=emit.map(value => TransferTextChanged(value)),
          ),
        ),
        if transfer.error == "" {
          @html.nothing
        } else {
          @rui.field_error(id="transfer-error", transfer.error)
        },
        div(style=["display:flex;justify-content:flex-end;margin-top:auto"], [
          @rui.button(type_="submit", "Import"),
        ]),
      ],
    ),
  ]
}
