///|
using @rabbita {type Cmd, type Emit, type Html, type Val}

///|
const EDITOR_ID = "chore-editor"

///|
const CONFIRM_ID = "confirm-dialog"

///|
const UNDO_DURATION_MS = 8000

///|
/// Shows or closes the panel when `panel_open` changes.
fn sync_panel(before : Model, after : Model) -> Cmd {
  match (before.panel_open, after.panel_open) {
    (false, true) => @dialog.show(EDITOR_ID, modal=false)
    (true, false) => @dialog.close(EDITOR_ID)
    _ => @rabbita.none
  }
}

///|
fn update(model : Model, msg : Msg, emit : Emit[Msg]) -> (Model, Cmd) {
  let (next, cmd) = transition(model, msg, emit)
  (next, @rabbita.batch([cmd, sync_panel(model, next)]))
}

///|
/// The next model and the requests to send for `msg`.
fn transition(model : Model, msg : Msg, emit : Emit[Msg]) -> (Model, Cmd) {
  match msg {
    ReloadPage => (model, @nav.reload())
    Reload =>
      (
        { ..model, load: Loading, },
        @http.get("/api/chores").expect_json(emit.map(result => Loaded(result))),
      )
    Loaded(Ok(list)) => (model.loaded(list), @rabbita.none)
    Loaded(Err(_)) => ({ ..model, load: Failed, }, @rabbita.none)
    Complete(id) =>
      match model.start_completing(id) {
        Some(next) =>
          (
            next,
            @http.post("/api/chores/\{id}/complete")
            .with_text("")
            .expect_json(emit.map(result => Completed(id, result))),
          )
        None => (model, @rabbita.none)
      }
    Completed(id, Ok(completed)) =>
      (
        model.completed(id, completed),
        @rabbita.delay(
          emit(DismissUndo(completed.completion_id)),
          UNDO_DURATION_MS,
        ),
      )
    Completed(id, Err(_)) => (model.completion_failed(id), @rabbita.none)
    UndoCompletion(completion_id) =>
      (
        model.start_undo(completion_id),
        @http.delete("/api/completions/\{completion_id}").expect_json(
          emit.map(result => Undone(result)),
        ),
      )
    Undone(Ok(chore)) => (model.undone(chore), @rabbita.none)
    // The completion was removed from `recent` optimistically, so reload it.
    Undone(Err(_)) => ({ ..model, notice: "Failed to undo.", }, emit(Reload))
    DismissUndo(id) => (model.dismiss_undo(id), @rabbita.none)
    OpenNew => (model.open_new(), @rabbita.none)
    OpenEdit(id) => (model.open_chore(id), @rabbita.none)
    TitleChanged(title) =>
      (model.edit(editor => { ..editor, title, }), @rabbita.none)
    DescriptionChanged(description) =>
      (model.edit(editor => { ..editor, description, }), @rabbita.none)
    RepeatChanged(repeat) =>
      (model.edit(editor => { ..editor, repeat, }), @rabbita.none)
    IntervalChanged(interval) =>
      (model.edit(editor => { ..editor, interval, }), @rabbita.none)
    MonthsChanged(months) =>
      (model.edit(editor => { ..editor, months, }), @rabbita.none)
    DayChanged(day) => (model.edit(editor => { ..editor, day, }), @rabbita.none)
    LeadDaysChanged(lead_days) =>
      (model.edit(editor => { ..editor, lead_days, }), @rabbita.none)
    NextDueChanged(next_due) =>
      (model.edit(editor => { ..editor, next_due, }), @rabbita.none)
    ToggleLabel(id) =>
      (model.edit(editor => editor.toggle_label(id)), @rabbita.none)
    FilterByLabel(label_filter) => ({ ..model, label_filter, }, @rabbita.none)
    TabSelected(tab) => ({ ..model, tab, }, @rabbita.none)
    OpenLabels => (model.open_labels(), @rabbita.none)
    EditLabel(id) => (model.select_label(id), @rabbita.none)
    NewLabel =>
      (model.edit_label(_ => new_label_form(model.labels)), @rabbita.none)
    LabelNameChanged(name) =>
      (model.edit_label(form => { ..form, name, }), @rabbita.none)
    LabelColorChanged(color) =>
      (model.edit_label(form => { ..form, color, }), @rabbita.none)
    SubmitLabel =>
      match model.submit_label() {
        (next, Some((None, input))) =>
          (
            next,
            @http.post("/api/labels")
            .with_json(input)
            .expect_json(emit.map(result => LabelSaved(None, result))),
          )
        (next, Some((Some(id), input))) =>
          (
            next,
            @http.put("/api/labels/\{id}")
            .with_json(input)
            .expect_json(emit.map(result => LabelSaved(Some(id), result))),
          )
        (next, None) => (next, @rabbita.none)
      }
    LabelSaved(id, Ok(label)) => (model.label_saved(id, label), @rabbita.none)
    LabelSaved(id, Err(_)) =>
      (
        model.label_error(id, "Failed to save. Please try again."),
        @rabbita.none,
      )
    DeleteLabel =>
      match model.panel {
        Some(Labels({ id: Some(id), .. })) =>
          (
            model,
            @http.delete("/api/labels/\{id}").expect_empty(
              emit.map(error => LabelDeleted(id, error)),
            ),
          )
        _ => (model, @rabbita.none)
      }
    LabelDeleted(id, None) => (model.label_deleted(id), @rabbita.none)
    LabelDeleted(id, Some(_)) =>
      (
        model.label_error(Some(id), "Failed to delete. Please try again."),
        @rabbita.none,
      )
    Submit =>
      match model.submit_chore() {
        (next, Some((None, input))) =>
          (
            next,
            @http.post("/api/chores")
            .with_json(input)
            .expect_json(emit.map(result => Saved(None, result))),
          )
        (next, Some((Some(id), input))) =>
          (
            next,
            @http.put("/api/chores/\{id}")
            .with_json(input)
            .expect_json(emit.map(result => Saved(Some(id), result))),
          )
        (next, None) => (next, @rabbita.none)
      }
    Saved(id, Ok(chore)) => (model.saved(id, chore), @rabbita.none)
    Saved(id, Err(_)) =>
      (
        model.editor_error(id, "Failed to save. Please try again."),
        @rabbita.none,
      )
    Archive =>
      match model.editor() {
        Some({ id: Some(id), .. }) =>
          (
            model,
            @http.delete("/api/chores/\{id}").expect_empty(
              emit.map(error => Archived(id, error)),
            ),
          )
        _ => (model, @rabbita.none)
      }
    Archived(id, None) => (model.archived(id), @rabbita.none)
    Archived(id, Some(_)) =>
      (
        model.editor_error(Some(id), "Failed to archive. Please try again."),
        @rabbita.none,
      )
    OpenTransfer => (model.open_transfer(), @rabbita.none)
    TransferTextChanged(text) =>
      (model.edit_transfer(transfer => { ..transfer, text, }), @rabbita.none)
    Import =>
      match model.submit_import() {
        (next, Some(text)) =>
          (
            next,
            @http.post("/api/chores/import")
            .with_text(text)
            .expect_json(emit.map(result => Imported(result))),
          )
        (next, None) => (next, @rabbita.none)
      }
    Imported(Ok(_)) => ({ ..model, panel_open: false, }, emit(Reload))
    Imported(Err(_)) =>
      (
        model.edit_transfer(transfer => {
          ..transfer,
          error: "Failed to import. Please try again.",
        }),
        @rabbita.none,
      )
    AskConfirm(confirm) =>
      ({ ..model, confirm: Some(confirm), }, @dialog.show(CONFIRM_ID))
    ClosePanel | PanelClosed => ({ ..model, panel_open: false, }, @rabbita.none)
  }
}

///|
fn app() -> Val[Html] {
  let (model, emit) = @rabbita.create_state_with_init(
    init=emit => (Model::new(), emit(Reload)),
    update~,
  )
  model.view(model => view(model, emit))
}

///|
fn main {
  @rabbita.new(app).mount("app")
}
