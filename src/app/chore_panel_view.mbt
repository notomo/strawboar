///|
fn editor_content(
  editor : Editor,
  labels : Array[@core.Label],
  store : Store,
) -> Array[Html] {
  let is_new = editor.id is None
  [
    @ui.dialog_header([
      @ui.dialog_title(id="panel-title", if is_new { "New" } else { "Edit" }),
    ]),
    @html.form(
      on_submit=() => store.submit_chore(),
      style=[
        "display:flex;flex-direction:column;gap:1.25rem;padding-bottom:1rem;flex:1",
      ],
      [
        field_view(
          "chore-title",
          "Title",
          @ui.input(
            id="chore-title",
            value=editor.title,
            maxlength=@core.MAX_TITLE_LENGTH,
            on_input=store.edit_input((editor, title) => { ..editor, title, }),
          ),
        ),
        field_view(
          "chore-description",
          "Description",
          @ui.textarea(
            id="chore-description",
            value=editor.description,
            maxlength=@core.MAX_DESCRIPTION_LENGTH,
            rows=3,
            placeholder="Notes such as the steps",
            style=[
              // Grows with the content up to a limit, then scrolls.
              "max-height:12rem",
            ],
            on_input=store.edit_input((editor, description) => {
              ..editor,
              description,
            }),
          ),
        ),
        label_picker(editor.labels, labels, store),
        repeat_tabs(
          editor.repeat,
          [
            (
              AfterDone,
              "After done",
              [
                number_field(
                  "chore-interval",
                  "Every (days)",
                  min=1,
                  max=@core.MAX_INTERVAL_DAYS,
                  editor.interval,
                  store.edit_input((editor, interval) => { ..editor, interval, }),
                ),
              ],
            ),
            (
              Monthly,
              "Monthly",
              [
                number_field(
                  "chore-months",
                  "Every (months)",
                  min=1,
                  max=@core.MAX_INTERVAL_MONTHS,
                  editor.months,
                  store.edit_input((editor, months) => { ..editor, months, }),
                ),
                // A new chore is due on the day of its first due date.
                if is_new {
                  @html.nothing
                } else {
                  number_field(
                    "chore-day",
                    "Day of month",
                    min=1,
                    max=31,
                    editor.day,
                    store.edit_input((editor, day) => { ..editor, day, }),
                  )
                },
                number_field(
                  "chore-lead-days",
                  "Soon from (days before)",
                  min=0,
                  max=@core.MAX_INTERVAL_MONTHS * 28,
                  editor.lead_days,
                  store.edit_input((editor, lead_days) => {
                    ..editor,
                    lead_days,
                  }),
                ),
              ],
            ),
          ],
          store,
        ),
        if is_new {
          field_view(
            "chore-next-due",
            "First due",
            @ui.input(
              id="chore-next-due",
              input_type=Date,
              value=editor.next_due,
              on_input=store.edit_input((editor, next_due) => {
                ..editor,
                next_due,
              }),
            ),
          )
        } else {
          @html.nothing
        },
        if editor.error == "" {
          @html.nothing
        } else {
          @ui.field_error(id="chore-editor-error", editor.error)
        },
        div(
          style=[
            "display:flex;justify-content:flex-end;gap:0.5rem;margin-top:auto",
          ],
          [
            @ui.button(type_="submit", "Save"),
            if is_new {
              @html.nothing
            } else {
              chore_menu_view(store)
            },
          ],
        ),
      ],
    ),
  ]
}

///|
/// Chooses whether the chore is due after it was done or on a fixed day,
/// showing the fields of the selected kind.
fn repeat_tabs(
  selected : RepeatKind,
  kinds : Array[(RepeatKind, String, Array[Html])],
  store : Store,
) -> Html {
  let value = (kind : RepeatKind) => {
    match kind {
      AfterDone => "after-done"
      Monthly => "monthly"
    }
  }
  @ui.field([
    @ui.field_label(id="chore-repeat-label", "Repeat"),
    div(
      style=["display:flex;flex-direction:column;gap:1rem"],
      [
        @ui.tabs_list(
          attrs=@html.Attrs::build().aria_labelledby("chore-repeat-label"),
          style=["width:100%"],
          kinds.map(kind => {
            let (kind, text, _) = kind
            @ui.tab(
              id="chore-repeat-\{value(kind)}",
              selected=selected == kind,
              controls="chore-repeat-\{value(kind)}-panel",
              on_select=() => {
                store.update(model => {
                  model.edit(editor => { ..editor, repeat: kind, })
                })
              },
              text,
            )
          }),
        ),
        ..kinds.map(kind => {
          let (kind, _, fields) = kind
          @ui.tab_panel(
            id="chore-repeat-\{value(kind)}-panel",
            labelledby="chore-repeat-\{value(kind)}",
            selected=selected == kind,
            // Only the fields of the selected kind are rendered.
            if selected == kind {
              div(
                style=["display:flex;flex-direction:column;gap:1.25rem"],
                fields,
              )
            } else {
              @html.nothing
            },
          )
        }),
      ],
    ),
  ])
}

///|
/// Toggles the labels of the chore being edited.
fn label_picker(
  selected : Array[Int32],
  labels : Array[@core.Label],
  store : Store,
) -> Html {
  @ui.field([
    @ui.field_label(id="chore-labels-label", "Labels"),
    if labels.is_empty() {
      span(
        style=["font-size:0.875rem", muted],
        "No labels yet. Add them from Labels in the ⋮ menu.",
      )
    } else {
      div(
        attrs=@html.Attrs::build()
          .role("group")
          .aria_labelledby("chore-labels-label"),
        // Padded so that the ring of a label that is on is not cut off,
        // with a negative margin to keep the labels aligned with the field.
        style=[
          "display:flex;flex-wrap:wrap;gap:0.75rem;padding:4px;margin:-4px",
        ],
        keyed(labels, label => "label-\{label.id}", label => {
          label_toggle(label, selected.contains(label.id), () => {
            store.update(model => {
              model.edit(editor => editor.toggle_label(label.id))
            })
          })
        }),
      )
    },
  ])
}
