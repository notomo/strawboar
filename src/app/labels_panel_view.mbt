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
        keyed(labels, label => "label-\{label.id}", label => {
          let current = form.id == Some(label.id)
          // The label being edited has a ring like the selected color below.
          // Clicking it again goes back to a new label, like the label filter.
          li([
            @rui.button(
              size=Sm,
              variant=Outline,
              on_click=emit(
                if current {
                  NewLabel
                } else {
                  EditLabel(label.id)
                },
              ),
              attrs=@html.Attrs::build()
                .aria_label("Edit label: \{label.name}")
                .aria_current(current.to_string()),
              style=[
                "font-weight:400",
                label_chip_style(label.color),
                if current {
                  selected_ring_style(label.color)
                } else {
                  ""
                },
              ],
              label.name,
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
                    selected_ring_style(color)
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
                on_click=emit(AskConfirm(ConfirmDeleteLabel)),
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
