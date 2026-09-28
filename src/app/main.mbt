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
  /// Comma-separated labels.
  labels : String
  error : String
  history : HistoryState
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
  chores : Array[@core.Chore]
  recent : Array[@core.RecentDone]
  editor : Editor?
  /// Whether the editor panel is shown. Drives the backdrop that closes it.
  panel_open : Bool
  /// Only chores with this label are shown when set.
  label_filter : String?
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
  LabelsChanged(String)
  FilterByLabel(String?)
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
fn Editor::input(self : Editor) -> @core.ChoreInput raise @core.ValidationError {
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
    labels: @core.parse_labels(self.labels),
  }
  input.validate()
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
          editor: Some({
            id: None,
            title: "",
            interval: "7",
            next_due,
            labels: model.label_filter.unwrap_or(""),
            error: "",
            history: Fetched([]),
          }),
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
              editor: Some({
                id: Some(id),
                title: chore.title,
                interval: chore.interval_days.to_string(),
                next_due: chore.next_due.to_string(),
                labels: chore.labels.join(", "),
                error: "",
                history: Loading,
              }),
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
      match model.editor {
        Some(editor) if editor.id == Some(id) => {
          let history = match result {
            Ok(history) => Fetched(history.dates)
            Err(_) => Unavailable
          }
          ({ ..model, editor: Some({ ..editor, history, }), }, @rabbita.none)
        }
        _ => (model, @rabbita.none)
      }
    TitleChanged(title) =>
      (model.edit(editor => { ..editor, title, }), @rabbita.none)
    IntervalChanged(interval) =>
      (model.edit(editor => { ..editor, interval, }), @rabbita.none)
    NextDueChanged(next_due) =>
      (model.edit(editor => { ..editor, next_due, }), @rabbita.none)
    LabelsChanged(labels) =>
      (model.edit(editor => { ..editor, labels, }), @rabbita.none)
    FilterByLabel(label_filter) => ({ ..model, label_filter, }, @rabbita.none)
    Submit =>
      match model.editor {
        Some(editor) =>
          try editor.input() catch {
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
      match model.editor {
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
      let id = model.editor.bind(editor => editor.id)
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
    ClosePanel => ({ ..model, panel_open: false, }, @dialog.close(EDITOR_ID))
    PanelClosed => ({ ..model, panel_open: false, }, @rabbita.none)
  }
}

///|
fn Model::edit(self : Model, f : (Editor) -> Editor) -> Model {
  { ..self, editor: self.editor.map(f), }
}

///|
/// Clears the label filter when no chore has the label anymore.
fn Model::keep_valid_filter(self : Model) -> Model {
  match self.label_filter {
    Some(label) if !self.chores.iter().any(c => c.has_label(label)) =>
      { ..self, label_filter: None, }
    _ => self
  }
}

///|
/// The chore being edited in the open panel, if any.
fn Model::selected_id(self : Model) -> Int? {
  match (self.panel_open, self.editor) {
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
          chores: [],
          recent: [],
          editor: None,
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
