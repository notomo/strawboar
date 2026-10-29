///|
fn list_style() -> String {
  "list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:0.5rem"
}

///|
fn tab_id(tab : Tab) -> String {
  match tab {
    Soon => "soon"
    Later => "later"
    Done => "recent"
  }
}

///|
/// The tabs with their counts. They are in the header so that every tab can be
/// reached however long the list of the selected one is.
fn tabs_view(model : Model, today : @core.Date, emit : Emit[Msg]) -> Html {
  let (dashboard, recent) = filtered(model, today)
  @rui.tabs_list(
    aria_label="Chores",
    // The active tab is outlined like the row open in the editor.
    style=[
      "width:100%;--rui-tabs-active-bg:var(--rui-accent);--rui-tabs-active-border:var(--rui-primary);--rui-tabs-active-shadow:0 0 0 1px var(--rui-primary)",
    ],
    [
      (Soon, "Soon", dashboard.soon.length()),
      (Later, "Later", dashboard.later.length()),
      (Done, "Done", recent.length()),
    ].map(entry => {
      let (tab, name, count) = entry
      let id = tab_id(tab)
      let selected = model.tab == tab
      @rui.tabs_trigger(
        value=id,
        selected~,
        controls=id,
        on_value_change=emit.map(_ => TabSelected(tab)),
        id="\{id}-tab",
        style=[
          "padding-block:0.375rem;padding-inline:1rem;justify-content:space-between",
          if selected {
            "font-weight:600"
          } else {
            ""
          },
        ],
        [
          @html.text("\{name} "),
          // Lighter than the list, which is the color of Secondary.
          @rui.badge(
            variant=Secondary,
            style=[
              "font-variant-numeric:tabular-nums;--rui-badge-bg:var(--rui-input)",
            ],
            "\{count}",
          ),
        ],
      )
    }),
  )
}

///|
/// The content of the selected tab, below a caption of the days it covers.
fn tab_panel(tab : Tab, caption : String?, content : Html) -> Html {
  let id = tab_id(tab)
  @rui.tabs_content(
    value=id,
    selected=true,
    labelledby="\{id}-tab",
    id~,
    style=["display:flex;flex-direction:column;gap:0.5rem"],
    [
      match caption {
        Some(caption) =>
          p(
            id="\{id}-caption",
            style=["margin:0 0.5rem;font-size:0.8125rem", muted],
            caption,
          )
        None => @html.nothing
      },
      content,
    ],
  )
}

///|
fn chore_panel(
  tab : Tab,
  caption : String?,
  chores : Array[@core.Chore],
  row : (@core.Chore) -> Html,
) -> Html {
  tab_panel(tab, caption, ul(style=[list_style()], chores.map(row)))
}

///|
/// e.g. `Until 10/20`, so that it is clear which days Soon covers.
fn soon_caption(dashboard : @core.Dashboard) -> String? {
  dashboard.soon_until().map(date => "Until \{short_date(date)}")
}

///|
/// e.g. `10/12 – 10/18`, so that it is clear which days Done covers.
fn recent_caption(today : @core.Date) -> String {
  let from = today.add_days(1 - @core.RECENT_DAYS)
  "\{short_date(from)} – \{short_date(today)}"
}

///|
fn card_style() -> String {
  "display:flex;align-items:center;gap:0.5rem;padding:0.375rem;border:1px solid var(--rui-border);border-radius:var(--rui-radius);background:var(--rui-card)"
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
  completing : Bool,
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
        @html.text(" · \{last_done_text(chore.last_done, today)}"),
      ]),
    ]),
    @rui.button(
      variant=Outline,
      disabled=completing,
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
/// "Done": all completions of the last days.
fn recent_view(
  recent : Array[@core.RecentDone],
  model : Model,
  today : @core.Date,
  emit : Emit[Msg],
) -> Html {
  tab_panel(
    Done,
    Some(recent_caption(today)),
    ul(
      style=[list_style()],
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
