///|
enum Load {
  Loading
  Ready
  Failed
} derive(Eq)

///|
enum RepeatKind {
  AfterDone
  Monthly
} derive(Eq)

///|
/// Form state of the editor panel. `id` is `None` for a new chore.
/// It is kept after the panel closes: a close event can arrive after
/// another chore was opened, and clearing it then would empty the panel.
struct Editor {
  id : Int32?
  title : String
  description : String
  repeat : RepeatKind
  interval : String
  months : String
  /// Day of the month. A new chore uses the day of `next_due` instead.
  day : String
  lead_days : String
  next_due : String
  /// Selected label ids.
  labels : Array[Int32]
  error : String
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
  id : Int32?
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
/// A dashboard section that can be collapsed.
enum Section {
  Soon
  Later
  Done
} derive(Eq)

///|
/// An action of the panel that asks for confirmation first.
enum Confirm {
  ConfirmArchive
  ConfirmUndo
  ConfirmDeleteLabel
} derive(Eq)

///|
struct Undo {
  completion_id : Int32
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
  label_filter : Int32?
  /// Expanded sections. Soon is expanded by default, Later and Done are not.
  open_sections : Array[Section]
  undo : Undo?
  /// Chores whose completion is being sent, so that it is not sent twice.
  completing : Array[Int32]
  /// The action shown in the confirmation dialog.
  confirm : Confirm?
  notice : String
} derive(Eq)

///|
enum Msg {
  Reload
  /// Reloads the whole page, which signs in again when the Access session has
  /// expired: its redirect makes every API request fail until then.
  ReloadPage
  Loaded(Result[@core.ChoreList, Error])
  Complete(Int32)
  Completed(Int32, Result[@core.Completed, Error])
  UndoCompletion(Int32)
  Undone(Result[@core.Chore, Error])
  DismissUndo(Int32)
  OpenNew
  OpenEdit(Int32)
  TitleChanged(String)
  DescriptionChanged(String)
  RepeatChanged(RepeatKind)
  IntervalChanged(String)
  MonthsChanged(String)
  DayChanged(String)
  LeadDaysChanged(String)
  NextDueChanged(String)
  ToggleLabel(Int32)
  FilterByLabel(Int32?)
  SectionToggled(Section, Bool)
  OpenLabels
  EditLabel(Int32)
  NewLabel
  LabelNameChanged(String)
  LabelColorChanged(@core.LabelColor)
  SubmitLabel
  /// Responses carry the id they were sent for: the panel may show another
  /// label or chore by the time they arrive.
  LabelSaved(Int32?, Result[@core.Label, Error])
  DeleteLabel
  LabelDeleted(Int32, Error?)
  OpenTransfer
  TransferTextChanged(String)
  Import
  Imported(Result[@core.ImportResult, Error])
  Submit
  Saved(Int32?, Result[@core.Chore, Error])
  Archive
  Archived(Int32, Error?)
  /// Opens the confirmation of an action of the panel.
  AskConfirm(Confirm)
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
  chores : Array[@core.Chore],
) -> @core.ChoreInput raise @core.ValidationError {
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
  let number = fn(
    input : String,
    message : String,
  ) raise @core.ValidationError {
    guard @core.parse_days(input) is Some(n) else {
      raise @core.ValidationError(message)
    }
    n
  }
  let repeat : @core.Repeat = match self.repeat {
    AfterDone =>
      AfterDone(number(self.interval, "Interval must be a number of days."))
    Monthly =>
      Monthly({
        months: number(self.months, "Months must be a number."),
        day: match next_due {
          Some(date) => date.ymd().2
          None => number(self.day, "Day must be a number.")
        },
        lead_days: number(self.lead_days, "Lead days must be a number."),
      })
  }
  let input : @core.ChoreInput = {
    title: self.title,
    description: self.description,
    repeat,
    next_due,
    labels: self.labels,
  }
  input.validate(labels, chores~, id?=self.id)
}

///|
/// A form for a new label, with a color no label has yet if any.
fn new_label_form(labels : Array[@core.Label]) -> LabelForm {
  let color = @core.label_colors
    .iter()
    .find_first(color => !labels.iter().any(label => label.color == color))
    .unwrap_or(@core.label_colors[0])
  { id: None, name: "", color, error: "", }
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
/// Closes the panel if it is open for the chore `id` (`None` for a new one).
fn Model::close_editor_of(self : Model, id : Int32?) -> (Model, Cmd) {
  match (self.panel_open, self.editor()) {
    (true, Some(editor)) if editor.id == id =>
      ({ ..self, panel_open: false, }, @dialog.close(EDITOR_ID))
    _ => (self, @rabbita.none)
  }
}

///|
/// Shows the error in the panel if it is open for the chore `id`, or as a
/// notice otherwise.
fn Model::editor_error(self : Model, id : Int32?, error : String) -> Model {
  match (self.panel_open, self.editor()) {
    (true, Some(editor)) if editor.id == id =>
      self.edit(editor => { ..editor, error, })
    _ => { ..self, notice: error, }
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
/// Edits the label form only if it is for the label `id` (`None` for a new one).
fn Model::edit_label_of(
  self : Model,
  id : Int32?,
  f : (LabelForm) -> LabelForm,
) -> Model {
  self.edit_label(form => if form.id == id { f(form) } else { form })
}

///|
/// Shows the error in the labels panel if it is open for the label `id`, or
/// as a notice otherwise.
fn Model::label_error(self : Model, id : Int32?, error : String) -> Model {
  match (self.panel_open, self.panel) {
    (true, Some(Labels(form))) if form.id == id =>
      self.edit_label(form => { ..form, error, })
    _ => { ..self, notice: error, }
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
/// The latest completion of the chore being edited, which can be undone.
fn Model::latest_done(self : Model) -> @core.RecentDone? {
  match self.editor() {
    Some({ id: Some(id), .. }) =>
      self.recent.iter().find_first(done => done.chore_id == id)
    _ => None
  }
}

///|
/// The chore being edited in the open panel, if any.
fn Model::selected_id(self : Model) -> Int32? {
  match (self.panel_open, self.editor()) {
    (true, Some({ id, .. })) => id
    _ => None
  }
}
