///|
using @rabbita {type Cmd, type Emit, type Html, type Val}

///|
const EDITOR_ID = "chore-editor"

///|
const UNDO_DURATION_MS = 8000

///|
enum Load {
  Loading
  Ready
  Failed
} derive(Eq)

///|
enum HistoryState {
  Loading
  Fetched(Array[@core.Date])
  Unavailable
} derive(Eq)

///|
/// Form state of the editor panel. `id` is `None` for a new chore.
/// It is kept after the panel closes: a close event can arrive after
/// another chore was opened, and clearing it then would empty the panel.
struct Editor {
  id : Int?
  title : String
  interval : String
  next_due : String
  /// Selected label ids.
  labels : Array[Int]
  error : String
  history : HistoryState
} derive(Eq)

///|
/// Form state of the import/export panel.
struct Transfer {
  /// Chore definitions as JSON, prefilled with the current ones.
  text : String
  error : String
} derive(Eq)

///|
/// Form state of the labels panel. `id` is `None` for a new label.
struct LabelForm {
  id : Int?
  name : String
  color : @core.LabelColor
  error : String
} derive(Eq)

///|
/// Content of the side panel.
enum Panel {
  ChoreEditor(Editor)
  Transfer(Transfer)
  Labels(LabelForm)
} derive(Eq)

///|
struct Undo {
  completion_id : Int
  title : String
} derive(Eq)

///|
struct Model {
  load : Load
  today : @core.Date?
  /// Sorted by name.
  labels : Array[@core.Label]
  chores : Array[@core.Chore]
  recent : Array[@core.RecentDone]
  /// Kept after the panel closes, like `Editor`.
  panel : Panel?
  /// Whether the panel is shown. Drives the backdrop that closes it.
  panel_open : Bool
  /// Only chores with this label are shown when set.
  label_filter : Int?
  undo : Undo?
  notice : String
} derive(Eq)

///|
enum Msg {
  Reload
  Loaded(Result[@core.ChoreList, Error])
  Complete(Int)
  Completed(Result[@core.Completed, Error])
  UndoCompletion(Int)
  Undone(Result[@core.Chore, Error])
  DismissUndo(Int)
  OpenNew
  OpenEdit(Int)
  HistoryLoaded(Int, Result[@core.History, Error])
  TitleChanged(String)
  IntervalChanged(String)
  NextDueChanged(String)
  ToggleLabel(Int)
  FilterByLabel(Int?)
  OpenLabels
  EditLabel(Int)
  NewLabel
  LabelNameChanged(String)
  LabelColorChanged(@core.LabelColor)
  SubmitLabel
  LabelSaved(Result[@core.Label, Error])
  DeleteLabel
  LabelDeleted(Error?)
  OpenTransfer
  TransferTextChanged(String)
  Import
  Imported(Result[@core.ImportResult, Error])
  Submit
  Saved(Result[@core.Chore, Error])
  Archive
  Archived(Error?)
  ClosePanel
  PanelClosed
}

///|
fn upsert(
  chores : Array[@core.Chore],
  chore : @core.Chore,
) -> Array[@core.Chore] {
  if chores.iter().any(c => c.id == chore.id) {
    chores.map(c => if c.id == chore.id { chore } else { c })
  } else {
    [..chores, chore]
  }
}

///|
fn Editor::input(
  self : Editor,
  labels : Array[@core.Label],
) -> @core.ChoreInput raise @core.ValidationError {
  guard @core.parse_days(self.interval) is Some(interval_days) else {
    raise ValidationError("Interval must be a number of days.")
  }
  // The due date of an existing chore follows its completions.
  let next_due = match self.id {
    Some(_) => None
    None =>
      Some(
        @core.Date::parse(self.next_due) catch {
          _ => raise ValidationError("Next due must be a date.")
        },
      )
  }
  let input : @core.ChoreInput = {
    title: self.title,
    interval_days,
    next_due,
    labels: self.labels,
  }
  input.validate(labels)
}

///|
/// A form for a new label, with a color no label has yet if any.
fn new_label_form(labels : Array[@core.Label]) -> LabelForm {
  let color = @core.label_colors
    .iter()
    .find_first(color => !labels.iter().any(label => label.color == color))
    .unwrap_or(Gray)
  { id: None, name: "", color, error: "", }
}

///|
fn failed(model : Model, message : String) -> (Model, Cmd) {
  ({ ..model, notice: message, }, @rabbita.none)
}

///|
fn update(model : Model, msg : Msg, emit : Emit[Msg]) -> (Model, Cmd) {
  match msg {
    Reload =>
      (
        { ..model, load: Loading, },
        @http.get("/api/chores").expect_json(emit.map(result => Loaded(result))),
      )
    Loaded(Ok(list)) =>
      (
        {
          ..model,
          load: Ready,
          today: Some(list.today),
          labels: list.labels,
          chores: list.chores,
          recent: list.recent,
        }.keep_valid_filter(),
        @rabbita.none,
      )
    Loaded(Err(_)) => ({ ..model, load: Failed, }, @rabbita.none)
    Complete(id) =>
      (
        { ..model, notice: "", },
        @http.post("/api/chores/\{id}/complete")
        .with_text("")
        .expect_json(emit.map(result => Completed(result))),
      )
    Completed(Ok(completed)) =>
      (
        {
          ..model,
          chores: upsert(model.chores, completed.chore),
          undo: Some({
            completion_id: completed.completion_id,
            title: completed.chore.title,
          }),
          recent: match completed.chore.last_done {
            Some(done_on) =>
              [
                {
                  completion_id: completed.completion_id,
                  chore_id: completed.chore.id,
                  title: completed.chore.title,
                  done_on,
                },
                ..model.recent,
              ]
            None => model.recent
          },
        },
        @rabbita.delay(
          emit(DismissUndo(completed.completion_id)),
          UNDO_DURATION_MS,
        ),
      )
    Completed(Err(_)) => failed(model, "Failed to mark as done.")
    UndoCompletion(completion_id) =>
      (
        {
          ..model,
          notice: "",
          undo: model.undo.filter(undo => undo.completion_id != completion_id),
          recent: model.recent.filter(r => r.completion_id != completion_id),
        },
        @http.delete("/api/completions/\{completion_id}").expect_json(
          emit.map(result => Undone(result)),
        ),
      )
    Undone(Ok(chore)) =>
      ({ ..model, chores: upsert(model.chores, chore), }, @rabbita.none)
    // The completion was removed from `recent` optimistically, so reload it.
    Undone(Err(_)) => ({ ..model, notice: "Failed to undo.", }, emit(Reload))
    DismissUndo(id) =>
      match model.undo {
        Some(undo) if undo.completion_id == id =>
          ({ ..model, undo: None, }, @rabbita.none)
        _ => (model, @rabbita.none)
      }
    OpenNew => {
      let next_due = model.today.map(d => d.to_string()).unwrap_or("")
      (
        {
          ..model,
          panel: Some(
            ChoreEditor({
              id: None,
              title: "",
              interval: "7",
              next_due,
              labels: model.label_filter.map(id => [id]).unwrap_or([]),
              error: "",
              history: Fetched([]),
            }),
          ),
          panel_open: true,
        },
        @dialog.show(EDITOR_ID, modal=false),
      )
    }
    OpenEdit(id) =>
      match model.chores.iter().find_first(c => c.id == id) {
        Some(chore) =>
          (
            {
              ..model,
              panel: Some(
                ChoreEditor({
                  id: Some(id),
                  title: chore.title,
                  interval: chore.interval_days.to_string(),
                  next_due: chore.next_due.to_string(),
                  labels: chore.labels,
                  error: "",
                  history: Loading,
                }),
              ),
              panel_open: true,
            },
            @rabbita.batch([
              @dialog.show(EDITOR_ID, modal=false),
              @http.get("/api/chores/\{id}/completions").expect_json(
                emit.map(result => HistoryLoaded(id, result)),
              ),
            ]),
          )
        None => (model, @rabbita.none)
      }
    HistoryLoaded(id, result) =>
      match model.editor() {
        Some(editor) if editor.id == Some(id) => {
          let history = match result {
            Ok(history) => Fetched(history.dates)
            Err(_) => Unavailable
          }
          (model.edit(editor => { ..editor, history, }), @rabbita.none)
        }
        _ => (model, @rabbita.none)
      }
    TitleChanged(title) =>
      (model.edit(editor => { ..editor, title, }), @rabbita.none)
    IntervalChanged(interval) =>
      (model.edit(editor => { ..editor, interval, }), @rabbita.none)
    NextDueChanged(next_due) =>
      (model.edit(editor => { ..editor, next_due, }), @rabbita.none)
    ToggleLabel(id) =>
      (
        model.edit(editor => {
          ..editor,
          labels: if editor.labels.contains(id) {
            editor.labels.filter(l => l != id)
          } else {
            [..editor.labels, id]
          },
        }),
        @rabbita.none,
      )
    FilterByLabel(label_filter) => ({ ..model, label_filter, }, @rabbita.none)
    OpenLabels =>
      (
        {
          ..model,
          panel: Some(Labels(new_label_form(model.labels))),
          panel_open: true,
        },
        @dialog.show(EDITOR_ID, modal=false),
      )
    EditLabel(id) =>
      match model.labels.iter().find_first(l => l.id == id) {
        Some(label) =>
          (
            model.edit_label(_ => {
              id: Some(id),
              name: label.name,
              color: label.color,
              error: "",
            }),
            @rabbita.none,
          )
        None => (model, @rabbita.none)
      }
    NewLabel =>
      (model.edit_label(_ => new_label_form(model.labels)), @rabbita.none)
    LabelNameChanged(name) =>
      (model.edit_label(form => { ..form, name, }), @rabbita.none)
    LabelColorChanged(color) =>
      (model.edit_label(form => { ..form, color, }), @rabbita.none)
    SubmitLabel =>
      match model.panel {
        Some(Labels(form)) => {
          let input : @core.LabelInput = { name: form.name, color: form.color, }
          try input.validate(model.labels, id?=form.id) catch {
            ValidationError(error) =>
              (model.edit_label(form => { ..form, error, }), @rabbita.none)
          } noraise {
            input =>
              (
                model.edit_label(form => { ..form, error: "", }),
                match form.id {
                  None =>
                    @http.post("/api/labels")
                    .with_json(input)
                    .expect_json(emit.map(result => LabelSaved(result)))
                  Some(id) =>
                    @http.put("/api/labels/\{id}")
                    .with_json(input)
                    .expect_json(emit.map(result => LabelSaved(result)))
                },
              )
          }
        }
        _ => (model, @rabbita.none)
      }
    LabelSaved(Ok(label)) => {
      let labels = @core.upsert_label(model.labels, label)
      (
        { ..model, labels, }.edit_label(_ => new_label_form(labels)),
        @rabbita.none,
      )
    }
    LabelSaved(Err(_)) =>
      (
        model.edit_label(form => {
          ..form,
          error: "Failed to save. Please try again.",
        }),
        @rabbita.none,
      )
    DeleteLabel =>
      match model.panel {
        Some(Labels({ id: Some(id), .. })) =>
          (
            model,
            @http.delete("/api/labels/\{id}").expect_empty(
              emit.map(error => LabelDeleted(error)),
            ),
          )
        _ => (model, @rabbita.none)
      }
    LabelDeleted(None) =>
      match model.panel {
        Some(Labels({ id: Some(id), .. })) => {
          let labels = model.labels.filter(l => l.id != id)
          (
            {
              ..model,
              labels,
              chores: model.chores.map(chore => {
                ..chore,
                labels: chore.labels.filter(l => l != id),
              }),
            }
            .edit_label(_ => new_label_form(labels))
            .keep_valid_filter(),
            @rabbita.none,
          )
        }
        _ => (model, @rabbita.none)
      }
    LabelDeleted(Some(_)) =>
      (
        model.edit_label(form => {
          ..form,
          error: "Failed to delete. Please try again.",
        }),
        @rabbita.none,
      )
    Submit =>
      match model.editor() {
        Some(editor) =>
          try editor.input(model.labels) catch {
            ValidationError(error) =>
              (model.edit(editor => { ..editor, error, }), @rabbita.none)
          } noraise {
            input =>
              (
                model.edit(editor => { ..editor, error: "", }),
                match editor.id {
                  None =>
                    @http.post("/api/chores")
                    .with_json(input)
                    .expect_json(emit.map(result => Saved(result)))
                  Some(id) =>
                    @http.put("/api/chores/\{id}")
                    .with_json(input)
                    .expect_json(emit.map(result => Saved(result)))
                },
              )
          }
        None => (model, @rabbita.none)
      }
    Saved(Ok(chore)) =>
      (
        {
          ..model,
          chores: upsert(model.chores, chore),
          notice: "",
          panel_open: false,
        }.keep_valid_filter(),
        @dialog.close(EDITOR_ID),
      )
    Saved(Err(_)) =>
      (
        model.edit(editor => {
          ..editor,
          error: "Failed to save. Please try again.",
        }),
        @rabbita.none,
      )
    Archive =>
      match model.editor() {
        Some({ id: Some(id), .. }) =>
          (
            model,
            @http.delete("/api/chores/\{id}").expect_empty(
              emit.map(error => Archived(error)),
            ),
          )
        _ => (model, @rabbita.none)
      }
    Archived(None) => {
      let id = model.editor().bind(editor => editor.id)
      (
        {
          ..model,
          chores: model.chores.filter(c => Some(c.id) != id),
          panel_open: false,
        }.keep_valid_filter(),
        @dialog.close(EDITOR_ID),
      )
    }
    Archived(Some(_)) =>
      (
        model.edit(editor => {
          ..editor,
          error: "Failed to archive. Please try again.",
        }),
        @rabbita.none,
      )
    OpenTransfer =>
      (
        {
          ..model,
          panel: Some(
            Transfer({
              text: @core.export_text(model.labels, model.chores),
              error: "",
            }),
          ),
          panel_open: true,
        },
        @dialog.show(EDITOR_ID, modal=false),
      )
    TransferTextChanged(text) =>
      (model.edit_transfer(transfer => { ..transfer, text, }), @rabbita.none)
    Import =>
      match (model.panel, model.today) {
        (Some(Transfer(transfer)), Some(_)) =>
          // Validated here too, so that the user sees why it is rejected.
          try
            @core.ImportPlan::new(
              model.labels,
              @core.parse_definitions(transfer.text),
            )
          catch {
            ValidationError(error) =>
              (
                model.edit_transfer(transfer => { ..transfer, error, }),
                @rabbita.none,
              )
          } noraise {
            _ =>
              (
                model.edit_transfer(transfer => { ..transfer, error: "", }),
                @http.post("/api/chores/import")
                .with_text(transfer.text)
                .expect_json(emit.map(result => Imported(result))),
              )
          }
        _ => (model, @rabbita.none)
      }
    Imported(Ok(_)) =>
      (
        { ..model, panel_open: false, },
        @rabbita.batch([@dialog.close(EDITOR_ID), emit(Reload)]),
      )
    Imported(Err(_)) =>
      (
        model.edit_transfer(transfer => {
          ..transfer,
          error: "Failed to import. Please try again.",
        }),
        @rabbita.none,
      )
    ClosePanel => ({ ..model, panel_open: false, }, @dialog.close(EDITOR_ID))
    PanelClosed => ({ ..model, panel_open: false, }, @rabbita.none)
  }
}

///|
fn Model::editor(self : Model) -> Editor? {
  match self.panel {
    Some(ChoreEditor(editor)) => Some(editor)
    _ => None
  }
}

///|
fn Model::edit(self : Model, f : (Editor) -> Editor) -> Model {
  match self.panel {
    Some(ChoreEditor(editor)) =>
      { ..self, panel: Some(ChoreEditor(f(editor))), }
    _ => self
  }
}

///|
fn Model::edit_transfer(self : Model, f : (Transfer) -> Transfer) -> Model {
  match self.panel {
    Some(Transfer(transfer)) => { ..self, panel: Some(Transfer(f(transfer))), }
    _ => self
  }
}

///|
fn Model::edit_label(self : Model, f : (LabelForm) -> LabelForm) -> Model {
  match self.panel {
    Some(Labels(form)) => { ..self, panel: Some(Labels(f(form))), }
    _ => self
  }
}

///|
/// Clears the label filter when the label is deleted.
fn Model::keep_valid_filter(self : Model) -> Model {
  match self.label_filter {
    Some(id) if !self.labels.iter().any(l => l.id == id) =>
      { ..self, label_filter: None, }
    _ => self
  }
}

///|
/// The chore being edited in the open panel, if any.
fn Model::selected_id(self : Model) -> Int? {
  match (self.panel_open, self.editor()) {
    (true, Some({ id, .. })) => id
    _ => None
  }
}

///|
fn app() -> Val[Html] {
  let (model, emit) = @rabbita.create_state_with_init(
    init=emit => {
      (
        {
          load: Loading,
          today: None,
          labels: [],
          chores: [],
          recent: [],
          panel: None,
          panel_open: false,
          label_filter: None,
          undo: None,
          notice: "",
        },
        emit(Reload),
      )
    },
    update~,
  )
  model.view(model => view(model, emit))
}

///|
fn main {
  @rabbita.new(app).mount("app")
}
