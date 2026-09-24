///|
using @html {div, h1, h2, li, p, span, ul}

///|
let muted = "color:var(--rui-muted-foreground)"

///|
/// Width of the editor panel (rui sheet).
let panel_width = "24rem"

///|
/// Content width plus the panel width. Below this, the panel covers the content.
let side_by_side_width = "64rem"

///|
fn view(model : Model, emit : Emit[Msg]) -> Html {
  // Makes room for the panel only when both fit side by side:
  // the calc is hugely negative (clamped to 0) on narrow screens.
  let room_for_panel = match model.editor {
    Some(_) =>
      "padding-right:clamp(0px,calc((100vw - \{side_by_side_width}) * 1000),\{panel_width})"
    None => ""
  }
  @rui.theme(
    mode=Dark,
    style=[
      "min-height:100dvh;background:var(--rui-background);color:var(--rui-foreground)",
    ],
    div(style=[room_for_panel], [
      div(
        style=[
          "box-sizing:border-box;padding:1.25rem 1rem;max-width:40rem;margin:0 auto;display:flex;flex-direction:column;gap:1.5rem",
        ],
        [header_view(model, emit), content_view(model, emit)],
      ),
      editor_view(model.editor, emit),
      undo_view(model.undo, emit),
    ]),
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
      @rui.button(on_click=emit(OpenNew), "+ Add chore"),
    ],
  )
}

///|
fn content_view(model : Model, emit : Emit[Msg]) -> Html {
  match (model.load, model.today) {
    (Ready, Some(today)) => {
      let dashboard = @core.Dashboard::new(model.chores, today)
      div(style=["display:flex;flex-direction:column;gap:1.5rem"], [
        notice_view(model.notice),
        if model.chores.is_empty() {
          p(style=["margin:0", muted], "No chores yet. Add one to get started.")
        } else if dashboard.due.is_empty() && dashboard.soon.is_empty() {
          p(style=["margin:0", muted], "Nothing due. Enjoy your day.")
        } else {
          @html.nothing
        },
        chore_section("due", "Due", dashboard.due, chore => {
          chore_row(chore, today, emit)
        }),
        chore_section("soon", "Soon", dashboard.soon, chore => {
          chore_row(chore, today, emit)
        }),
        chore_section("later", "Later", dashboard.later, chore => {
          later_row(chore, emit)
        }),
        recent_view(model.recent),
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
/// The clickable area that opens the editor. It shows a chevron so it reads as a link.
fn edit_area(chore_id : Int, emit : Emit[Msg], content : Array[Html]) -> Html {
  @rui.button(
    variant=Ghost,
    on_click=emit(OpenEdit(chore_id)),
    style=[
      "flex:1;min-width:0;height:auto;justify-content:space-between;gap:0.75rem;padding:0.625rem 0.75rem;text-align:left;white-space:normal;font-weight:inherit",
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
fn title_text(title : String) -> Html {
  span(
    style=[
      "font-size:1rem;font-weight:500;overflow:hidden;text-overflow:ellipsis;white-space:nowrap",
    ],
    title,
  )
}

///|
fn chore_row(chore : @core.Chore, today : @core.Date, emit : Emit[Msg]) -> Html {
  li(style=[card_style()], [
    edit_area(chore.id, emit, [
      title_text(chore.title),
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
fn later_row(chore : @core.Chore, emit : Emit[Msg]) -> Html {
  li(style=[card_style()], [
    edit_area(chore.id, emit, [
      div(
        style=[
          "display:flex;align-items:baseline;justify-content:space-between;gap:0.75rem",
        ],
        [
          title_text(chore.title),
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
fn recent_view(recent : Array[@core.RecentDone]) -> Html {
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
              "display:flex;justify-content:space-between;gap:0.75rem;padding:0.25rem 0.75rem",
            ],
            [
              span(
                style=[
                  "overflow:hidden;text-overflow:ellipsis;white-space:nowrap",
                ],
                "✓ \{done.title}",
              ),
              span(style=["flex-shrink:0"], short_date(done.done_on)),
            ],
          )
        })
        .collect(),
        if hidden > 0 {
          li(style=["padding:0.25rem 0.75rem"], "and \{hidden} more")
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
/// A non-modal panel on the right, so the dashboard stays visible and usable.
fn editor_view(editor : Editor?, emit : Emit[Msg]) -> Html {
  @rui.sheet(
    id=EDITOR_ID,
    side=SheetRight,
    on_close=emit.map(_ => EditorClosed),
    attrs=@html.Attrs::build().aria_labelledby("chore-editor-title"),
    style=[
      "width:min(\{panel_width},100vw);max-width:100vw;box-shadow:-8px 0 24px rgb(0 0 0 / 0.4)",
    ],
    match editor {
      None => []
      Some(editor) => editor_content(editor, emit)
    },
  )
}

///|
fn editor_content(editor : Editor, emit : Emit[Msg]) -> Array[Html] {
  let is_new = editor.id is None
  [
    @rui.sheet_header([
      @rui.sheet_title(
        id="chore-editor-title",
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
        field_view(
          "chore-next-due",
          "Next due",
          @rui.input(
            id="chore-next-due",
            input_type=Date,
            value=editor.next_due,
            on_input=emit.map(value => NextDueChanged(value)),
          ),
        ),
        if is_new {
          @html.nothing
        } else {
          postpone_view(emit)
        },
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
fn postpone_view(emit : Emit[Msg]) -> Html {
  div(style=["display:flex;flex-direction:column;gap:0.5rem"], [
    span(style=["font-size:0.875rem;font-weight:500"], "Postpone"),
    div(
      style=["display:flex;gap:0.5rem"],
      [1, 3, 7].map(days => {
        @rui.button(
          type_="button",
          variant=Outline,
          on_click=emit(Postpone(days)),
          "+\{days}d",
        )
      }),
    ),
  ])
}

///|
fn undo_view(undo : Undo?, emit : Emit[Msg]) -> Html {
  match undo {
    None => @html.nothing
    Some(undo) =>
      div(
        style=[
          "position:fixed;left:50%;bottom:1rem;transform:translateX(-50%);width:min(24rem,calc(100% - 2rem))",
        ],
        @rui.toast(open=true, id="undo-toast", [
          @rui.toast_title("Done: \{undo.title}"),
          @rui.toast_action(on_click=emit(UndoCompletion), "Undo"),
        ]),
      )
  }
}
