///|
using @rabbita {type Cmd, type Emit, type Html, type Val}

///|
const EDITOR_ID = "chore-editor"

///|
const CONFIRM_ID = "confirm-dialog"

///|
const UNDO_DURATION_MS = 8000

///|
fn failed(model : Model, message : String) -> (Model, Cmd) {
  ({ ..model, notice: message, }, @rabbita.none)
}

///|
fn update(model : Model, msg : Msg, emit : Emit[Msg]) -> (Model, Cmd) {
  match msg {
    ReloadPage => (model, @nav.reload())
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
    Complete(id) if model.completing.contains(id) => (model, @rabbita.none)
    Complete(id) =>
      (
        { ..model, notice: "", completing: [..model.completing, id], },
        @http.post("/api/chores/\{id}/complete")
        .with_text("")
        .expect_json(emit.map(result => Completed(id, result))),
      )
    Completed(id, Ok(completed)) =>
      (
        {
          ..model,
          completing: model.completing.filter(c => c != id),
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
    Completed(id, Err(_)) =>
      failed(
        { ..model, completing: model.completing.filter(c => c != id), },
        "Failed to mark as done.",
      )
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
              description: "",
              repeat: AfterDone,
              interval: "7",
              months: "1",
              day: "",
              lead_days: "7",
              next_due,
              labels: model.label_filter.map(id => [id]).unwrap_or([]),
              error: "",
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
                }),
              ),
              panel_open: true,
            },
            @dialog.show(EDITOR_ID, modal=false),
          )
        None => (model, @rabbita.none)
      }
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
    SectionToggled(section, open) => {
      let others = model.open_sections.filter(s => s != section)
      let open_sections = if open { [..others, section] } else { others }
      ({ ..model, open_sections, }, @rabbita.none)
    }
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
                    .expect_json(emit.map(result => LabelSaved(None, result)))
                  Some(id) =>
                    @http.put("/api/labels/\{id}")
                    .with_json(input)
                    .expect_json(
                      emit.map(result => LabelSaved(Some(id), result)),
                    )
                },
              )
          }
        }
        _ => (model, @rabbita.none)
      }
    LabelSaved(id, Ok(label)) => {
      let labels = @core.upsert_label(model.labels, label)
      (
        { ..model, labels, }.edit_label_of(id, _ => new_label_form(labels)),
        @rabbita.none,
      )
    }
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
    LabelDeleted(id, None) => {
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
        .edit_label_of(Some(id), _ => new_label_form(labels))
        .keep_valid_filter(),
        @rabbita.none,
      )
    }
    LabelDeleted(id, Some(_)) =>
      (
        model.label_error(Some(id), "Failed to delete. Please try again."),
        @rabbita.none,
      )
    Submit =>
      match model.editor() {
        Some(editor) =>
          try editor.input(model.labels, model.chores) catch {
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
                    .expect_json(emit.map(result => Saved(None, result)))
                  Some(id) =>
                    @http.put("/api/chores/\{id}")
                    .with_json(input)
                    .expect_json(emit.map(result => Saved(Some(id), result)))
                },
              )
          }
        None => (model, @rabbita.none)
      }
    Saved(id, Ok(chore)) =>
      { ..model, chores: upsert(model.chores, chore), notice: "", }
      .keep_valid_filter()
      .close_editor_of(id)
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
    Archived(id, None) =>
      { ..model, chores: model.chores.filter(c => c.id != id), }
      .keep_valid_filter()
      .close_editor_of(Some(id))
    Archived(id, Some(_)) =>
      (
        model.editor_error(Some(id), "Failed to archive. Please try again."),
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
    AskConfirm(confirm) =>
      ({ ..model, confirm: Some(confirm), }, @dialog.show(CONFIRM_ID))
    ClosePanel => ({ ..model, panel_open: false, }, @dialog.close(EDITOR_ID))
    PanelClosed => ({ ..model, panel_open: false, }, @rabbita.none)
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
          open_sections: [Soon],
          undo: None,
          completing: [],
          confirm: None,
          notice: "",
        },
        emit(Reload),
      )
    },
    update~,
  )
  model.view3(menu_view(emit), chore_menu_view(emit), (model, menu, chore_menu) => {
    view(model, menu, chore_menu, emit)
  })
}

///|
fn main {
  @rabbita.new(app).mount("app")
}
