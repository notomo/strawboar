// How the model changes on each event, without the requests or the dialogs
// they lead to: `update` sends those, so that these can be tested alone.

///|
/// The model before the chores are loaded.
fn Model::new() -> Model {
  {
    load: Loading,
    today: None,
    labels: [],
    chores: [],
    recent: [],
    panel: None,
    panel_open: false,
    label_filter: None,
    tab: Soon,
    undo: None,
    completing: [],
    confirm: None,
    notice: "",
  }
}

///|
fn Model::loaded(self : Model, list : @core.ChoreList) -> Model {
  {
    ..self,
    load: Ready,
    today: Some(list.today),
    labels: list.labels,
    chores: list.chores,
    recent: list.recent,
  }.keep_valid_filter()
}

///|
/// `None` if the completion of the chore is already being sent.
fn Model::start_completing(self : Model, id : Int32) -> Model? {
  if self.completing.contains(id) {
    None
  } else {
    Some({ ..self, notice: "", completing: [..self.completing, id], })
  }
}

///|
/// The chore is done: it can be undone from the toast for a while, and it is
/// added to the recent completions.
fn Model::completed(
  self : Model,
  id : Int32,
  completed : @core.Completed,
) -> Model {
  let chore = completed.chore
  {
    ..self,
    completing: self.completing.filter(c => c != id),
    chores: upsert(self.chores, chore),
    undo: Some({ completion_id: completed.completion_id, title: chore.title, }),
    recent: match chore.last_done {
      Some(done_on) =>
        [
          {
            completion_id: completed.completion_id,
            chore_id: chore.id,
            title: chore.title,
            done_on,
          },
          ..self.recent,
        ]
      None => self.recent
    },
  }
}

///|
fn Model::completion_failed(self : Model, id : Int32) -> Model {
  {
    ..self,
    completing: self.completing.filter(c => c != id),
    notice: "Failed to mark as done.",
  }
}

///|
/// Removes the completion before the response, so that it disappears at once.
fn Model::start_undo(self : Model, completion_id : Int32) -> Model {
  {
    ..self,
    notice: "",
    undo: self.undo.filter(undo => undo.completion_id != completion_id),
    recent: self.recent.filter(r => r.completion_id != completion_id),
  }
}

///|
fn Model::undone(self : Model, chore : @core.Chore) -> Model {
  { ..self, chores: upsert(self.chores, chore), }
}

///|
/// Hides the toast unless it is already for a newer completion.
fn Model::dismiss_undo(self : Model, completion_id : Int32) -> Model {
  match self.undo {
    Some(undo) if undo.completion_id == completion_id => { ..self, undo: None, }
    _ => self
  }
}

///|
/// Opens the panel for a new chore, due today and with the filtered label.
fn Model::open_new(self : Model) -> Model {
  let editor : Editor = {
    id: None,
    title: "",
    description: "",
    repeat: AfterDone,
    interval: "7",
    months: "1",
    day: "",
    lead_days: "7",
    next_due: self.today.map(d => d.to_string()).unwrap_or(""),
    labels: self.label_filter.map(id => [id]).unwrap_or([]),
    error: "",
  }
  { ..self, panel: Some(ChoreEditor(editor)), panel_open: true, }
}

///|
/// Opens the panel for the chore `id`, or does nothing if it is not shown.
fn Model::open_chore(self : Model, id : Int32) -> Model {
  guard self.chores.iter().find_first(c => c.id == id) is Some(chore) else {
    return self
  }
  let editor : Editor = {
    id: Some(id),
    title: chore.title,
    description: chore.description,
    repeat: match chore.repeat {
      AfterDone(_) => AfterDone
      Monthly(_) => Monthly
    },
    interval: chore.repeat.approx_days().to_string(),
    months: match chore.repeat {
      Monthly({ months, .. }) => months.to_string()
      AfterDone(_) => "1"
    },
    day: match chore.repeat {
      Monthly({ day, .. }) => day.to_string()
      AfterDone(_) => chore.next_due.ymd().2.to_string()
    },
    lead_days: match chore.repeat {
      Monthly({ lead_days, .. }) => lead_days.to_string()
      AfterDone(_) => "7"
    },
    next_due: chore.next_due.to_string(),
    labels: chore.labels,
    error: "",
  }
  { ..self, panel: Some(ChoreEditor(editor)), panel_open: true, }
}

///|
fn Editor::toggle_label(self : Editor, id : Int32) -> Editor {
  {
    ..self,
    labels: if self.labels.contains(id) {
      self.labels.filter(l => l != id)
    } else {
      [..self.labels, id]
    },
  }
}

///|
/// Validates the chore in the panel. Returns the input to send with the id of
/// the chore (`None` for a new one), or `None` with the error shown.
fn Model::submit_chore(self : Model) -> (Model, (Int32?, @core.ChoreInput)?) {
  guard self.editor() is Some(editor) else { return (self, None) }
  try editor.input(self.labels, self.chores) catch {
    ValidationError(error) => (self.edit(editor => { ..editor, error, }), None)
  } noraise {
    input =>
      (self.edit(editor => { ..editor, error: "", }), Some((editor.id, input)))
  }
}

///|
/// The chore is saved: the panel closes if it is still open for it.
fn Model::saved(self : Model, id : Int32?, chore : @core.Chore) -> Model {
  { ..self, chores: upsert(self.chores, chore), notice: "", }
  .keep_valid_filter()
  .close_editor_of(id)
}

///|
fn Model::archived(self : Model, id : Int32) -> Model {
  { ..self, chores: self.chores.filter(c => c.id != id), }
  .keep_valid_filter()
  .close_editor_of(Some(id))
}

///|
fn Model::open_labels(self : Model) -> Model {
  {
    ..self,
    panel: Some(Labels(new_label_form(self.labels))),
    panel_open: true,
  }
}

///|
/// Edits the label `id` in the labels panel.
fn Model::select_label(self : Model, id : Int32) -> Model {
  match self.labels.iter().find_first(l => l.id == id) {
    Some(label) =>
      self.edit_label(_ => {
        id: Some(id),
        name: label.name,
        color: label.color,
        error: "",
      })
    None => self
  }
}

///|
/// Validates the label in the panel, like `submit_chore`.
fn Model::submit_label(self : Model) -> (Model, (Int32?, @core.LabelInput)?) {
  guard self.panel is Some(Labels(form)) else { return (self, None) }
  let input : @core.LabelInput = { name: form.name, color: form.color, }
  try input.validate(self.labels, id?=form.id) catch {
    ValidationError(error) =>
      (self.edit_label(form => { ..form, error, }), None)
  } noraise {
    input =>
      (self.edit_label(form => { ..form, error: "", }), Some((form.id, input)))
  }
}

///|
/// The label is saved: the form goes back to a new label if it was for it.
fn Model::label_saved(self : Model, id : Int32?, label : @core.Label) -> Model {
  let labels = @core.upsert_label(self.labels, label)
  { ..self, labels, }.edit_label_of(id, _ => new_label_form(labels))
}

///|
/// The label is deleted: it is removed from every chore and from the filter.
fn Model::label_deleted(self : Model, id : Int32) -> Model {
  let labels = self.labels.filter(l => l.id != id)
  {
    ..self,
    labels,
    chores: self.chores.map(chore => {
      ..chore,
      labels: chore.labels.filter(l => l != id),
    }),
  }
  .edit_label_of(Some(id), _ => new_label_form(labels))
  .keep_valid_filter()
}

///|
/// Opens the panel with the current labels and chores to export.
fn Model::open_transfer(self : Model) -> Model {
  {
    ..self,
    panel: Some(
      Transfer({ text: @core.export_text(self.labels, self.chores), error: "", }),
    ),
    panel_open: true,
  }
}

///|
/// Validates the definitions to import, like `submit_chore`. They are also
/// validated by the Worker, but here the user sees why they are rejected.
fn Model::submit_import(self : Model) -> (Model, String?) {
  guard self.panel is Some(Transfer(transfer)) && self.today is Some(_) else {
    return (self, None)
  }
  try
    @core.ImportPlan::new(self.labels, @core.parse_definitions(transfer.text))
  catch {
    ValidationError(error) =>
      (self.edit_transfer(transfer => { ..transfer, error, }), None)
  } noraise {
    _ =>
      (
        self.edit_transfer(transfer => { ..transfer, error: "", }),
        Some(transfer.text),
      )
  }
}
