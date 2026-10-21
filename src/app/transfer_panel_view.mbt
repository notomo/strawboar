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
