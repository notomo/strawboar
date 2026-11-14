// The model and the actions on it. An action changes the model with the pure
// methods of state.mbt and sends the requests of api.mbt; the views run them
// on their events.

///|
struct Store {
  app : @html.App[Model]
}

///|
/// Runs the async `f`, and then `done` with its result.
fn[A] call(f : async () -> A, done : (Result[A, Error]) -> Unit) -> Unit {
  @web.spawn(f, done)
}

///|
fn Store::model(self : Store) -> Model {
  self.app.model()
}

///|
/// Changes the model, and then opens or closes the panel to follow it.
fn Store::update(self : Store, f : (Model) -> Model) -> Unit {
  self.app.update(f)
  self.app.after_render(() => {
    @ui.sync_dialog(EDITOR_ID, open=self.model().panel_open, modal=false)
  })
}

///|
/// Changes the model with the value of an input.
fn Store::input(self : Store, f : (Model, String) -> Model) -> (String) -> Unit {
  value => self.update(model => f(model, value))
}

///|
/// Changes the chore in the panel with the value of an input.
fn Store::edit_input(
  self : Store,
  f : (Editor, String) -> Editor,
) -> (String) -> Unit {
  self.input((model, value) => model.edit(editor => f(editor, value)))
}

///|
fn Store::reload(self : Store) -> Unit {
  self.update(model => { ..model, load: Loading, })
  call(fetch_chores, result => {
    self.update(model => {
      match result {
        Ok(list) => model.loaded(list)
        Err(_) => { ..model, load: Failed, }
      }
    })
  })
}

///|
/// Marks the chore as done, which can be undone from the toast for a while.
fn Store::complete(self : Store, id : Int32) -> Unit {
  guard self.model().start_completing(id) is Some(next) else { return }
  self.update(_ => next)
  call(() => complete_chore(id), result => {
    match result {
      Ok(completed) => {
        self.update(model => model.completed(id, completed))
        call(() => @web.sleep(UNDO_DURATION_MS), _ => {
          self.update(model => model.dismiss_undo(completed.completion_id))
        })
      }
      Err(_) => self.update(model => model.completion_failed(id))
    }
  })
}

///|
fn Store::undo_completion(self : Store, completion_id : Int32) -> Unit {
  self.update(model => model.start_undo(completion_id))
  call(() => undo_completion(completion_id), result => {
    match result {
      Ok(chore) => self.update(model => model.undone(chore))
      // The completion was removed from `recent` optimistically, so reload it.
      Err(_) => {
        self.update(model => { ..model, notice: "Failed to undo.", })
        self.reload()
      }
    }
  })
}

///|
/// Saves the chore in the panel if it is valid.
fn Store::submit_chore(self : Store) -> Unit {
  let (next, request) = self.model().submit_chore()
  self.update(_ => next)
  guard request is Some((id, input)) else { return }
  call(() => save_chore(id, input), result => {
    self.update(model => {
      match result {
        Ok(chore) => model.saved(id, chore)
        Err(_) => model.editor_error(id, "Failed to save. Please try again.")
      }
    })
  })
}

///|
/// Archives the chore in the panel.
fn Store::archive(self : Store) -> Unit {
  guard self.model().editor() is Some({ id: Some(id), .. }) else { return }
  call(() => archive_chore(id), result => {
    self.update(model => {
      match result {
        Ok(_) => model.archived(id)
        Err(_) =>
          model.editor_error(Some(id), "Failed to archive. Please try again.")
      }
    })
  })
}

///|
/// Saves the label in the labels panel if it is valid.
fn Store::submit_label(self : Store) -> Unit {
  let (next, request) = self.model().submit_label()
  self.update(_ => next)
  guard request is Some((id, input)) else { return }
  call(() => save_label(id, input), result => {
    self.update(model => {
      match result {
        Ok(label) => model.label_saved(id, label)
        Err(_) => model.label_error(id, "Failed to save. Please try again.")
      }
    })
  })
}

///|
/// Deletes the label in the labels panel.
fn Store::delete_label(self : Store) -> Unit {
  guard self.model().panel is Some(Labels({ id: Some(id), .. })) else { return }
  call(() => delete_label(id), result => {
    self.update(model => {
      match result {
        Ok(_) => model.label_deleted(id)
        Err(_) =>
          model.label_error(Some(id), "Failed to delete. Please try again.")
      }
    })
  })
}

///|
/// Imports the definitions in the import/export panel if they are valid.
fn Store::import_definitions(self : Store) -> Unit {
  let (next, text) = self.model().submit_import()
  self.update(_ => next)
  guard text is Some(text) else { return }
  call(() => import_definitions(text), result => {
    match result {
      Ok(_) => {
        self.update(model => { ..model, panel_open: false, })
        self.reload()
      }
      Err(_) =>
        self.update(model => {
          model.edit_transfer(transfer => {
            ..transfer,
            error: "Failed to import. Please try again.",
          })
        })
    }
  })
}

///|
/// Asks before an action.
fn Store::ask_confirm(self : Store, confirm : Confirm) -> Unit {
  self.update(model => { ..model, confirm: Some(confirm), })
  self.app.after_render(() => @ui.show_dialog(CONFIRM_ID, modal=true))
}
