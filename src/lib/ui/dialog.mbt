// Native dialogs, opened with `show_dialog` and closed with `close_dialog`.

///|
/// A panel on the right edge of the viewport with a close button.
/// Open it with `show_dialog(id, modal=false)` to keep the page usable.
pub fn sheet(
  id~ : String,
  closedby~ : String,
  on_close? : @cmd.Emit[String],
  attrs? : @html.Attrs,
  style~ : Array[String] = [],
  children : Array[@html.Html],
) -> @html.Html {
  @html.dialog(
    class="ui-sheet",
    id~,
    closedby~,
    on_close?,
    attrs=attrs_or_new(attrs),
    style~,
    [
      ..children,
      @html.form(
        class="ui-sheet-close",
        method_="dialog",
        button(
          variant=Ghost,
          size=IconSm,
          type_="submit",
          attrs=@html.Attrs::build().aria_label("Close").formnovalidate(true),
          @html.span(attrs=@html.Attrs::build().aria_hidden("true"), "✕"),
        ),
      ),
    ],
  )
}

///|
/// A modal dialog that asks before an action. Put its buttons in a
/// `<form method="dialog">`, so that each of them closes it.
pub fn[C : @html.IsChildren] alert_dialog(
  id~ : String,
  closedby~ : String = "closerequest",
  attrs? : @html.Attrs,
  style~ : Array[String] = [],
  children : C,
) -> @html.Html {
  @html.dialog(
    class="ui-dialog",
    id~,
    closedby~,
    attrs=attrs_or_new(attrs).role("alertdialog"),
    style~,
    children,
  )
}

///|
pub fn dialog_header(children : Array[@html.Html]) -> @html.Html {
  @html.div(class="ui-dialog-header", children)
}

///|
pub fn dialog_title(
  id~ : String,
  attrs? : @html.Attrs,
  style~ : Array[String] = [],
  text : String,
) -> @html.Html {
  @html.h2(class="ui-dialog-title", id~, attrs?, style~, text)
}

///|
pub fn dialog_description(id? : String, text : String) -> @html.Html {
  @html.p(class="ui-dialog-description", id?, text)
}

///|
pub fn dialog_footer(children : Array[@html.Html]) -> @html.Html {
  @html.div(class="ui-dialog-footer", children)
}

///|
/// Closes the dialog without its action. It has the focus when the dialog opens.
pub fn dialog_cancel(text : String) -> @html.Html {
  button(
    variant=Outline,
    type_="submit",
    attrs=@html.Attrs::build().formnovalidate(true).autofocus(true),
    text,
  )
}

///|
fn dialog_by_id(id : String) -> @dom.HTMLDialogElement? {
  @dom.document()
  .get_element_by_id(id)
  .to_option()
  .bind(element => element.to_html_element())
  .bind(element => element.to_html_dialog_element())
}

///|
/// Opens the dialog `id`. A dialog that is not modal leaves the page usable.
pub fn show_dialog(id : String, modal~ : Bool) -> Unit {
  match (dialog_by_id(id), modal) {
    (Some(dialog), true) => dialog.show_modal()
    (Some(dialog), false) => dialog.show()
    (None, _) => ()
  }
}

///|
pub fn close_dialog(id : String) -> Unit {
  if dialog_by_id(id) is Some(dialog) {
    dialog.close()
  }
}

///|
/// Opens or closes the dialog `id` so that it is open only if `open`.
pub fn sync_dialog(id : String, open~ : Bool, modal~ : Bool) -> Unit {
  match (dialog_by_id(id), open) {
    (Some(dialog), true) if !dialog.open() => show_dialog(id, modal~)
    (Some(dialog), false) if dialog.open() => dialog.close()
    _ => ()
  }
}
