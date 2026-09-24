///|
using @html {div, h1, h2, li, p, span, ul}

///|
let muted = "color:var(--rui-muted-foreground)"

///|
fn view(model : Model, emit : Emit[Msg]) -> Html {
  @rui.theme(
    mode=Light,
    div(
      style=[
        "min-height:100dvh;box-sizing:border-box;padding:1rem;max-width:40rem;margin:0 auto;display:flex;flex-direction:column;gap:1rem",
      ],
      [
        header_view(model, emit),
        content_view(model, emit),
        editor_view(model.editor, emit),
        undo_view(model.undo, emit),
      ],
    ),
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
        style=["margin:0;font-size:1.25rem;font-weight:600"],
        model.today.map(long_date).unwrap_or(""),
      ),
      @rui.button(variant=Outline, size=Sm, on_click=emit(OpenNew), "Add"),
    ],
  )
}

///|
fn content_view(model : Model, emit : Emit[Msg]) -> Html {
  match (model.load, model.today) {
    (Ready, Some(today)) => {
      let dashboard = @core.Dashboard::new(model.chores, today)
      div(style=["display:flex;flex-direction:column;gap:1rem"], [
        notice_view(model.notice),
        if model.chores.is_empty() {
          p(style=[muted], "No chores yet. Add one to get started.")
        } else if dashboard.due.is_empty() && dashboard.soon.is_empty() {
          p(style=[muted], "Nothing due. Enjoy your day.")
        } else {
          @html.nothing
        },
        section_view("due", "Due", dashboard.due, today, emit),
        section_view("soon", "Soon", dashboard.soon, today, emit),
        later_view(dashboard.later, emit),
      ])
    }
    (Failed, _) =>
      div(
        style=[
          "display:flex;flex-direction:column;gap:0.5rem;align-items:flex-start",
        ],
        [
          p(style=["margin:0"], "Failed to load chores."),
          @rui.button(variant=Outline, size=Sm, on_click=emit(Reload), "Retry"),
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
      "margin:0 0 0.25rem;font-size:0.75rem;font-weight:600;letter-spacing:0.05em;text-transform:uppercase",
      muted,
    ],
    title,
  )
}

///|
fn section_view(
  id : String,
  title : String,
  chores : Array[@core.Chore],
  today : @core.Date,
  emit : Emit[Msg],
) -> Html {
  if chores.is_empty() {
    return @html.nothing
  }
  @html.section(id~, [
    section_title(title),
    ul(
      style=[
        "list-style:none;margin:0;padding:0;display:flex;flex-direction:column",
      ],
      chores.map(chore => chore_row(chore, today, emit)),
    ),
  ])
}

///|
fn chore_row(chore : @core.Chore, today : @core.Date, emit : Emit[Msg]) -> Html {
  li(
    style=[
      "display:flex;align-items:center;gap:0.75rem;padding:0.5rem 0;border-bottom:1px solid var(--rui-border)",
    ],
    [
      @rui.button(
        variant=Outline,
        size=Sm,
        on_click=emit(Complete(chore.id)),
        attrs=@html.Attrs::build().aria_label("Done: \{chore.title}"),
        "Done",
      ),
      @html.button(
        style=[
          "all:unset;cursor:pointer;display:flex;flex-direction:column;min-width:0;flex:1",
        ],
        on_click=emit(OpenEdit(chore.id)),
        [
          span(
            style=[
              "font-weight:500;overflow:hidden;text-overflow:ellipsis;white-space:nowrap",
            ],
            chore.title,
          ),
          span(style=["font-size:0.8125rem", muted], chore_meta(chore, today)),
        ],
      ),
    ],
  )
}

///|
fn later_view(chores : Array[@core.Chore], emit : Emit[Msg]) -> Html {
  if chores.is_empty() {
    return @html.nothing
  }
  @html.section(id="later", [
    section_title("Later"),
    div(
      style=["display:flex;flex-wrap:wrap;gap:0.375rem"],
      chores.map(chore => {
        @rui.button(
          variant=Secondary,
          size=Xs,
          on_click=emit(OpenEdit(chore.id)),
          "\{chore.title} · \{short_date(chore.next_due)}",
        )
      }),
    ),
  ])
}

///|
fn field_view(id : String, label : String, input : Html) -> Html {
  @rui.field([@rui.field_label(for_=id, label), input])
}

///|
fn editor_view(editor : Editor?, emit : Emit[Msg]) -> Html {
  @rui.dialog(
    id=EDITOR_ID,
    on_close=emit.map(_ => EditorClosed),
    attrs=@html.Attrs::build().aria_labelledby("chore-editor-title"),
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
    @rui.dialog_header([
      @rui.dialog_title(
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
      style=["display:flex;flex-direction:column;gap:1rem"],
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
        div(style=["display:flex;gap:0.75rem"], [
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
        ]),
        if is_new {
          @html.nothing
        } else {
          postpone_view(emit)
        },
        if editor.error == "" {
          @html.nothing
        } else {
          @rui.field_error(id="chore-editor-error", editor.error)
        },
        @rui.dialog_footer([
          if is_new {
            @html.nothing
          } else {
            @rui.button(
              type_="button",
              variant=Ghost,
              on_click=emit(Archive),
              "Archive",
            )
          },
          @rui.button(type_="submit", "Save"),
        ]),
      ],
    ),
  ]
}

///|
fn postpone_view(emit : Emit[Msg]) -> Html {
  div(
    style=["display:flex;align-items:center;gap:0.375rem;flex-wrap:wrap"],
    [
      span(style=["font-size:0.875rem", muted], "Postpone"),
      ..[1, 3, 7].map(days => {
        @rui.button(
          type_="button",
          variant=Outline,
          size=Xs,
          on_click=emit(Postpone(days)),
          "+\{days}d",
        )
      }),
    ],
  )
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
