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
      panel_view(model.panel, model.labels, model.recent, emit),
      undo_view(model.undo, emit),
    ],
  )
}

///|
fn header_view(model : Model, emit : Emit[Msg]) -> Html {
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
      div(style=["display:flex;gap:0.5rem;margin-left:auto"], [
        @rui.button(
          variant=Outline,
          on_click=emit(OpenTransfer),
          "Import / Export",
        ),
        @rui.button(on_click=emit(OpenNew), "+ Add"),
      ]),
    ],
  )
}

///|
fn content_view(model : Model, emit : Emit[Msg]) -> Html {
  match (model.load, model.today) {
    (Ready, Some(today)) => {
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
      let dashboard = @core.Dashboard::new(chores, today)
      let state_of = (chore : @core.Chore) => row_state(model, chore.id)
      let labels_of = (chore : @core.Chore) => chore.labels_in(model.labels)
      div(style=["display:flex;flex-direction:column;gap:1.5rem"], [
        notice_view(model.notice),
        label_filter_view(model.labels, model.label_filter, emit),
        if model.chores.is_empty() {
          p(style=["margin:0", muted], "No chores yet. Add one to get started.")
        } else if dashboard.due.is_empty() && dashboard.soon.is_empty() {
          p(style=["margin:0", muted], "Nothing due. Enjoy your day.")
        } else {
          @html.nothing
        },
        chore_section(Due, "Due", dashboard.due, model, emit, chore => {
          chore_row(chore, labels_of(chore), today, state_of(chore), emit)
        }),
        chore_section(
          Soon,
          soon_title(dashboard),
          dashboard.soon,
          model,
          emit,
          chore => {
            chore_row(chore, labels_of(chore), today, state_of(chore), emit)
          },
        ),
        chore_section(Later, "Later", dashboard.later, model, emit, chore => {
          dated_row(
            chore.id,
            chore.title,
            labels_of(chore),
            chore.next_due,
            state_of(chore),
            emit,
          )
        }),
        recent_view(recent, model, today, emit),
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
/// Filters the dashboard by a label, next to the button that opens the labels panel.
/// Hidden until a label exists, so that it takes no space; the chore editor
/// also opens the labels panel.
fn label_filter_view(
  labels : Array[@core.Label],
  label_filter : Int32?,
  emit : Emit[Msg],
) -> Html {
  if labels.is_empty() {
    return @html.nothing
  }
  let chip = (name : String, content : Array[Html], value : Int32?) => {
    let pressed = label_filter == value
    @rui.button(
      size=Sm,
      variant=if pressed { Default } else { Outline },
      on_click=emit(FilterByLabel(value)),
      // The flex layout would put a space between "#" and the name.
      attrs=@html.Attrs::build()
        .aria_label(name)
        .aria_pressed(pressed.to_string()),
      style=["flex-shrink:0;gap:0"],
      content,
    )
  }
  div(
    style=["display:flex;align-items:center;gap:0.5rem;margin-bottom:-0.5rem"],
    [
      div(
        id="label-filter",
        attrs=@html.Attrs::build().role("group").aria_label("Filter by label"),
        style=["display:flex;gap:0.5rem;overflow-x:auto;flex:1;min-width:0"],
        [
          chip("All", [@html.text("All")], None),
          ..labels.map(label => {
            chip(
              "#\{label.name}",
              [
                span(style=["color:\{color_value(label.color)}"], "#"),
                @html.text(label.name),
              ],
              Some(label.id),
            )
          }),
        ],
      ),
      @rui.button(
        size=Sm,
        variant=Ghost,
        on_click=emit(OpenLabels),
        style=["flex-shrink:0;margin-left:auto"],
        "Edit labels",
      ),
    ],
  )
}

///|
let section_title_style = "font-size:0.75rem;font-weight:600;letter-spacing:0.08em;text-transform:uppercase"

///|
fn list_style() -> String {
  "list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:0.5rem"
}

///|
fn chore_section(
  section : Section,
  title : String,
  chores : Array[@core.Chore],
  model : Model,
  emit : Emit[Msg],
  row : (@core.Chore) -> Html,
) -> Html {
  if chores.is_empty() {
    return @html.nothing
  }
  collapsible_section(
    section,
    "\{title} (\{chores.length()})",
    model,
    emit,
    ul(style=[list_style()], chores.map(row)),
  )
}

///|
/// e.g. `Soon · until 10/20`, so that it is clear which days the section covers.
fn soon_title(dashboard : @core.Dashboard) -> String {
  match dashboard.soon_until() {
    Some(date) => "Soon · until \{short_date(date)}"
    None => "Soon"
  }
}

///|
/// e.g. `Done · 10/12 – 10/18 (3)`, so that it is clear which days the section covers.
fn recent_title(count : Int32, today : @core.Date) -> String {
  let from = today.add_days(1 - @core.RECENT_DAYS)
  "Done · \{short_date(from)} – \{short_date(today)} (\{count})"
}

///|
/// A section whose content is shown by clicking its title.
fn collapsible_section(
  section : Section,
  title : String,
  model : Model,
  emit : Emit[Msg],
  content : Html,
) -> Html {
  let id = match section {
    Due => "due"
    Soon => "soon"
    Later => "later"
    Done => "recent"
  }
  let open = model.open_sections.contains(section)
  let on_open_change = emit.map(open => SectionToggled(section, open))
  @html.section(id~, [
    @rui.collapsible_root(open~, [
      @rui.collapsible_trigger(
        open~,
        controls="\{id}-content",
        on_open_change~,
        id="\{id}-trigger",
        style=["padding:0.375rem 0.5rem;align-items:center"],
        // A heading is not allowed in a button.
        span(style=[section_title_style, muted], title),
      ),
      @rui.collapsible_content(
        open~,
        labelledby="\{id}-trigger",
        id="\{id}-content",
        // A gap between the title and the list, hidden with the content.
        body_style=["padding:0.5rem 0 0"],
        content,
      ),
    ]),
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
fn row_state(model : Model, chore_id : Int32) -> RowState {
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
/// CSS color of a label color, readable on the dark theme.
fn color_value(color : @core.LabelColor) -> String {
  match color {
    Gray => "#a1a1aa"
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
fn label_badge(label : @core.Label) -> Html {
  let color = color_value(label.color)
  @rui.badge(
    variant=Outline,
    // Hex alpha suffixes: 0x26 = 15%, 0x66 = 40%.
    style=[
      "font-weight:400;color:\{color};background:\{color}26;border-color:\{color}66",
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

///|
/// The clickable area that opens the editor. It shows a chevron so it reads as a link.
/// While the panel is open for another chore, it is raised above the backdrop so
/// that tapping it switches the panel to this chore.
fn edit_area(
  chore_id : Int32,
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
fn title_text(title : String, labels : Array[@core.Label]) -> Html {
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
  labels : Array[@core.Label],
  today : @core.Date,
  state : RowState,
  emit : Emit[Msg],
) -> Html {
  card(state, [
    edit_area(chore.id, state, emit, [
      title_text(chore.title, labels),
      span(style=["font-size:0.8125rem", muted], [
        span(
          style=["font-weight:600;color:var(--rui-foreground)"],
          interval_text(chore.repeat),
        ),
        @html.text(" · \{chore_status(chore, today)}"),
      ]),
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
/// A row of a title and a date on the right, used by Later and Done.
fn dated_row(
  chore_id : Int32,
  title : String,
  labels : Array[@core.Label],
  date : @core.Date,
  state : RowState,
  emit : Emit[Msg],
) -> Html {
  card(state, [
    edit_area(chore_id, state, emit, [
      div(
        style=[
          "display:flex;align-items:baseline;justify-content:space-between;gap:0.75rem",
        ],
        [
          title_text(title, labels),
          span(
            style=["font-size:0.8125rem;flex-shrink:0", muted],
            short_date(date),
          ),
        ],
      ),
    ]),
  ])
}

///|
/// "Done", collapsed by default like the later section.
fn recent_view(
  recent : Array[@core.RecentDone],
  model : Model,
  today : @core.Date,
  emit : Emit[Msg],
) -> Html {
  if recent.is_empty() {
    return @html.nothing
  }
  collapsible_section(
    Done,
    recent_title(recent.length(), today),
    model,
    emit,
    ul(
      // The collapsible content is muted by default.
      style=[list_style(), "color:var(--rui-foreground)"],
      @core.recent_monthly_first(recent, model.chores)
      .iter()
      .map(done => {
        match model.chores.iter().find_first(c => c.id == done.chore_id) {
          Some(chore) =>
            dated_row(
              chore.id,
              done.title,
              chore.labels_in(model.labels),
              done.done_on,
              row_state(model, chore.id),
              emit,
            )
          // An archived chore cannot be opened.
          None =>
            li(style=[card_style()], [
              div(
                style=[
                  "flex:1;min-width:0;display:flex;align-items:baseline;justify-content:space-between;gap:0.75rem;padding:0.625rem 0.75rem",
                ],
                [
                  title_text(done.title, []),
                  span(
                    style=["font-size:0.8125rem;flex-shrink:0", muted],
                    short_date(done.done_on),
                  ),
                ],
              ),
            ])
        }
      })
      .collect(),
    ),
  )
}

///|
fn history_view(
  history : HistoryState,
  latest : @core.RecentDone?,
  emit : Emit[Msg],
) -> Html {
  let text = match history {
    Loading => "Loading..."
    Fetched(dates) => history_text(dates)
    Unavailable => "Failed to load history."
  }
  div(
    id="chore-history",
    style=["display:flex;flex-direction:column;gap:0.25rem"],
    [
      div(
        style=[
          "display:flex;align-items:center;justify-content:space-between;gap:0.5rem",
        ],
        [
          span(style=["font-size:0.875rem;font-weight:500"], "History"),
          match latest {
            Some(done) =>
              @rui.button(
                type_="button",
                size=Sm,
                variant=Outline,
                on_click=emit(UndoCompletion(done.completion_id)),
                "Undo \{short_date(done.done_on)}",
              )
            None => @html.nothing
          },
        ],
      ),
      span(id="chore-history-text", style=["font-size:0.875rem", muted], text),
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
fn panel_view(
  panel : Panel?,
  labels : Array[@core.Label],
  recent : Array[@core.RecentDone],
  emit : Emit[Msg],
) -> Html {
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
      Some(ChoreEditor(editor)) => editor_content(editor, labels, recent, emit)
      Some(Transfer(transfer)) => transfer_content(transfer, emit)
      Some(Labels(form)) => labels_content(form, labels, emit)
    },
  )
}

///|
fn editor_content(
  editor : Editor,
  labels : Array[@core.Label],
  recent : Array[@core.RecentDone],
  emit : Emit[Msg],
) -> Array[Html] {
  let is_new = editor.id is None
  [
    @rui.sheet_header([
      @rui.sheet_title(
        id="panel-title",
        if is_new {
          "New"
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
          "chore-description",
          "Description",
          @rui.textarea(
            id="chore-description",
            value=editor.description,
            maxlength=@core.MAX_DESCRIPTION_LENGTH,
            rows=3,
            placeholder="Notes such as the steps",
            style=[
              // Grows with the content up to a limit, then scrolls.
              "max-height:12rem",
            ],
            on_input=emit.map(value => DescriptionChanged(value)),
          ),
        ),
        repeat_picker(editor.repeat, emit),
        ..match editor.repeat {
          AfterDone =>
            [
              number_field(
                "chore-interval",
                "Every (days)",
                min=1,
                max=@core.MAX_INTERVAL_DAYS,
                editor.interval,
                emit.map(value => IntervalChanged(value)),
              ),
            ]
          Monthly =>
            [
              number_field(
                "chore-months",
                "Every (months)",
                min=1,
                max=@core.MAX_INTERVAL_MONTHS,
                editor.months,
                emit.map(value => MonthsChanged(value)),
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
                  emit.map(value => DayChanged(value)),
                )
              },
              number_field(
                "chore-lead-days",
                "Soon from (days before)",
                min=0,
                max=@core.MAX_INTERVAL_MONTHS * 28,
                editor.lead_days,
                emit.map(value => LeadDaysChanged(value)),
              ),
            ]
        },
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
        label_picker(editor.labels, labels, emit),
        if is_new {
          @html.nothing
        } else {
          // The newest completion of the chore can be undone.
          history_view(
            editor.history,
            recent.iter().find_first(done => Some(done.chore_id) == editor.id),
            emit,
          )
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
fn number_field(
  id : String,
  label : String,
  min~ : Int32,
  max~ : Int32,
  value : String,
  on_input : Emit[String],
) -> Html {
  field_view(
    id,
    label,
    @rui.input(
      id~,
      input_type=Number,
      inputmode="numeric",
      min~,
      max~,
      value~,
      on_input~,
    ),
  )
}

///|
/// Chooses whether the chore is due after it was done or on a fixed day.
fn repeat_picker(selected : RepeatKind, emit : Emit[Msg]) -> Html {
  @rui.field([
    @rui.field_label(id="chore-repeat-label", "Repeat"),
    div(
      attrs=@html.Attrs::build()
        .role("group")
        .aria_labelledby("chore-repeat-label"),
      style=["display:flex;flex-wrap:wrap;gap:0.5rem"],
      [(AfterDone, "After done"), (Monthly, "Monthly")].map(option => {
        let (kind, text) = option
        let pressed = selected == kind
        @rui.button(
          size=Sm,
          variant=if pressed { Secondary } else { Outline },
          on_click=emit(RepeatChanged(kind)),
          attrs=@html.Attrs::build().aria_pressed(pressed.to_string()),
          text,
        )
      }),
    ),
  ])
}

///|
/// Toggles the labels of the chore being edited.
fn label_picker(
  selected : Array[Int32],
  labels : Array[@core.Label],
  emit : Emit[Msg],
) -> Html {
  @rui.field([
    div(
      style=["display:flex;align-items:center;justify-content:space-between"],
      [
        @rui.field_label(id="chore-labels-label", "Labels"),
        @rui.button(
          size=Xs,
          variant=Ghost,
          on_click=emit(OpenLabels),
          "Edit labels",
        ),
      ],
    ),
    if labels.is_empty() {
      span(style=["font-size:0.875rem", muted], "No labels yet.")
    } else {
      div(
        attrs=@html.Attrs::build()
          .role("group")
          .aria_labelledby("chore-labels-label"),
        style=["display:flex;flex-wrap:wrap;gap:0.5rem"],
        labels.map(label => {
          let pressed = selected.contains(label.id)
          @rui.button(
            size=Sm,
            variant=if pressed { Secondary } else { Outline },
            on_click=emit(ToggleLabel(label.id)),
            attrs=@html.Attrs::build().aria_pressed(pressed.to_string()),
            style=[
              if pressed {
                "border-color:\{color_value(label.color)}"
              } else {
                ""
              },
            ],
            [
              span(
                attrs=@html.Attrs::build().aria_hidden("true"),
                style=[
                  "width:0.625rem;height:0.625rem;border-radius:9999px;background:\{color_value(label.color)}",
                  if pressed {
                    ""
                  } else {
                    "opacity:0.5"
                  },
                ],
                "",
              ),
              @html.text(label.name),
            ],
          )
        }),
      )
    },
  ])
}

///|
fn labels_content(
  form : LabelForm,
  labels : Array[@core.Label],
  emit : Emit[Msg],
) -> Array[Html] {
  let is_new = form.id is None
  [
    @rui.sheet_header([
      @rui.sheet_title(id="panel-title", "Labels"),
      @rui.sheet_description(
        "Labels are shared by chores. Pick a label to edit it.",
      ),
    ]),
    if labels.is_empty() {
      @html.nothing
    } else {
      ul(
        id="label-list",
        style=[
          "list-style:none;margin:0 0 0.75rem;padding:0;display:flex;flex-wrap:wrap;gap:0.5rem",
        ],
        labels.map(label => {
          let current = form.id == Some(label.id)
          li([
            @rui.button(
              size=Sm,
              variant=if current { Secondary } else { Ghost },
              on_click=emit(EditLabel(label.id)),
              attrs=@html.Attrs::build()
                .aria_label("Edit label: \{label.name}")
                .aria_current(current.to_string()),
              style=["padding:0.25rem"],
              label_badge(label),
            ),
          ])
        }),
      )
    },
    @html.form(
      id="label-form",
      on_submit=emit(SubmitLabel),
      style=[
        "display:flex;flex-direction:column;gap:1.25rem;padding-bottom:1rem;flex:1",
      ],
      [
        h2(
          style=["margin:0;font-size:1rem;font-weight:600"],
          if is_new {
            "New label"
          } else {
            "Edit label"
          },
        ),
        field_view(
          "label-name",
          "Name",
          @rui.input(
            id="label-name",
            value=form.name,
            maxlength=@core.MAX_LABEL_LENGTH,
            placeholder="e.g. kitchen",
            on_input=emit.map(value => LabelNameChanged(value)),
          ),
        ),
        @rui.field([
          @rui.field_label(id="label-color-label", "Color"),
          div(
            attrs=@html.Attrs::build()
              .role("group")
              .aria_labelledby("label-color-label"),
            style=["display:flex;flex-wrap:wrap;gap:0.5rem"],
            @core.label_colors.map(color => {
              let pressed = form.color == color
              @rui.button(
                size=IconSm,
                variant=Outline,
                on_click=emit(LabelColorChanged(color)),
                attrs=@html.Attrs::build()
                  .aria_label(color.name())
                  .aria_pressed(pressed.to_string()),
                style=[
                  "border-radius:9999px;background:\{color_value(color)}",
                  if pressed {
                    "box-shadow:0 0 0 2px var(--rui-background),0 0 0 4px \{color_value(color)}"
                  } else {
                    ""
                  },
                ],
                "",
              )
            }),
          ),
        ]),
        div([
          span(
            style=["font-size:0.875rem;margin-right:0.5rem", muted],
            "Preview",
          ),
          label_badge({
            id: 0,
            name: if form.name.trim() == "" {
              "label"
            } else {
              form.name.trim().to_owned()
            },
            color: form.color,
          }),
        ]),
        if form.error == "" {
          @html.nothing
        } else {
          @rui.field_error(id="label-form-error", form.error)
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
                on_click=emit(DeleteLabel),
                "Delete",
              )
            },
            div(style=["display:flex;gap:0.5rem"], [
              if is_new {
                @html.nothing
              } else {
                @rui.button(
                  type_="button",
                  variant=Outline,
                  on_click=emit(NewLabel),
                  "Cancel",
                )
              },
              @rui.button(
                type_="submit",
                if is_new {
                  "Add label"
                } else {
                  "Save"
                },
              ),
            ]),
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
        "Copy the labels and chores below to export them. To import, edit or paste them and press Import: labels with the same name and chores with the same title are updated, and others are added.",
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
          "Labels and chores (JSON)",
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
