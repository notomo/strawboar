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
    Soon => "soon"
    Later => "later"
    Done => "recent"
  }
  let open = model.open_sections.contains(section)
  let on_open_change = emit.map(open => SectionToggled(section, open))
  @html.section(id~, [
    @rui.collapsible_root(open~, [
      // Kept at the top of the dashboard while its section is scrolled.
      // It is above the backdrop like the header.
      div(
        style=[
          "position:sticky;top:0;z-index:12;background:var(--rui-background)",
        ],
        [
          @rui.collapsible_trigger(
            open~,
            controls="\{id}-content",
            on_open_change~,
            id="\{id}-trigger",
            style=["padding:0.375rem 0.5rem;align-items:center"],
            // A heading is not allowed in a button.
            span(style=[section_title_style, muted], title),
          ),
          raised_backdrop_view(model.panel_open, emit),
        ],
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
        @html.text(" · \{chore_status(chore, today)}"),
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
/// "Done", collapsed by default like the later section.
fn recent_view(
  recent : Array[@core.RecentDone],
  model : Model,
  today : @core.Date,
  emit : Emit[Msg],
) -> Html {
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
