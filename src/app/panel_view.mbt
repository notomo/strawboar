///|
/// Width of the editor panel.
let panel_width = "24rem"

///|
fn field_view(id : String, label : String, input : Html) -> Html {
  @ui.field([@ui.field_label(for_=id, label), input])
}

///|
/// Closes the panel when tapping outside of it. The native `closedby` light
/// dismiss is not supported by every browser (e.g. on tablets), so it is disabled.
/// `cursor:pointer` makes iOS Safari dispatch taps on this plain element.
fn backdrop_view(panel_open : Bool, store : Store) -> Html {
  if !panel_open {
    return @html.nothing
  }
  div(
    id="editor-backdrop",
    style=[
      "position:fixed;inset:0;z-index:10;background:rgb(0 0 0 / 0.4);cursor:pointer",
    ],
    on_click=store.update(model => { ..model, panel_open: false, }),
    "",
  )
}

///|
/// A non-modal panel over the right side of the dashboard.
fn panel_view(
  panel : Panel?,
  labels : Array[@core.Label],
  store : Store,
) -> Html {
  @ui.sheet(
    id=EDITOR_ID,
    closedby="closerequest",
    on_close=store.input((model, _) => { ..model, panel_open: false, }),
    attrs=@html.Attrs::build().aria_labelledby("panel-title"),
    style=[
      "position:fixed;z-index:20;width:min(\{panel_width},100vw);max-width:100vw;box-shadow:-8px 0 24px rgb(0 0 0 / 0.4)",
    ],
    match panel {
      None => []
      Some(ChoreEditor(editor)) => editor_content(editor, labels, store)
      Some(Transfer(transfer)) => transfer_content(transfer, store)
      Some(Labels(form)) => labels_content(form, labels, store)
    },
  )
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
    @ui.input(
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
