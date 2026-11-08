// The model and the actions on it. An action changes the model with the pure
// methods of state.mbt and sends the requests of api.mbt; the views run them
// as the commands of their events.

///|
struct Store {
  set : Emit[(Model) -> Model]
  /// The latest model, for the actions that depend on it when they run.
  current : Ref[Model]
}

///|
/// Runs `f` after the view is rendered, e.g. to open a dialog it renders.
fn run(f : () -> Unit) -> Cmd {
  @cmd.custom_cmd(kind=@cmd.after_render, _ => f())
}

///|
/// Runs the async `f` and then the command `done` makes of its result. It runs
/// on the event loop of MoonBit's async, which `lib/web` waits for promises on,
/// not on Rabbita's.
fn[A] call(f : async () -> A, done : (Result[A, Error]) -> Cmd) -> Cmd {
  @cmd.custom_cmd(scheduler => {
    @web.spawn(f, result => scheduler.add(done(result)))
  })
}

///|
fn Store::change(self : Store, f : (Model) -> Model) -> (Model) -> Model {
  model => {
    let next = f(model)
    self.current.val = next
    next
  }
}

///|
/// Changes the model, and then opens or closes the panel to follow it.
fn Store::update(self : Store, f : (Model) -> Model) -> Cmd {
  @rabbita.batch([
    (self.set)(self.change(f)),
    run(() => {
      @ui.sync_dialog(EDITOR_ID, open=self.current.val.panel_open, modal=false)
    }),
  ])
}

///|
/// Changes the model with the value of an input.
fn Store::input(self : Store, f : (Model, String) -> Model) -> Emit[String] {
  self.set.map(value => self.change(model => f(model, value)))
}

///|
/// Changes the chore in the panel with the value of an input.
fn Store::edit_input(
  self : Store,
  f : (Editor, String) -> Editor,
) -> Emit[String] {
  self.input((model, value) => model.edit(editor => f(editor, value)))
}

///|
/// Runs the command `f` makes of the model at the time it runs.
fn Store::read(self : Store, f : (Model) -> Cmd) -> Cmd {
  @cmd.custom_cmd(scheduler => scheduler.add(f(self.current.val)))
}

///|
fn Store::reload(self : Store) -> Cmd {
  @rabbita.batch([
    self.update(model => { ..model, load: Loading, }),
    call(fetch_chores, result => {
      self.update(model => {
        match result {
          Ok(list) => model.loaded(list)
          Err(_) => { ..model, load: Failed, }
        }
      })
    }),
  ])
}

///|
/// Marks the chore as done, which can be undone from the toast for a while.
fn Store::complete(self : Store, id : Int32) -> Cmd {
  self.read(model => {
    guard model.start_completing(id) is Some(_) else { return @rabbita.none }
    @rabbita.batch([
      self.update(model => model.start_completing(id).unwrap_or(model)),
      call(() => complete_chore(id), result => {
        match result {
          Ok(completed) =>
            @rabbita.batch([
              self.update(model => model.completed(id, completed)),
              call(() => @web.sleep(UNDO_DURATION_MS), _ => {
                self.update(model => model.dismiss_undo(completed.completion_id))
              }),
            ])
          Err(_) => self.update(model => model.completion_failed(id))
        }
      }),
    ])
  })
}

///|
fn Store::undo_completion(self : Store, completion_id : Int32) -> Cmd {
  @rabbita.batch([
    self.update(model => model.start_undo(completion_id)),
    call(() => undo_completion(completion_id), result => {
      match result {
        Ok(chore) => self.update(model => model.undone(chore))
        // The completion was removed from `recent` optimistically, so reload it.
        Err(_) =>
          @rabbita.batch([
            self.update(model => { ..model, notice: "Failed to undo.", }),
            self.reload(),
          ])
      }
    }),
  ])
}

///|
/// Saves the chore in the panel if it is valid.
fn Store::submit_chore(self : Store) -> Cmd {
  self.read(model => {
    let shown = self.update(model => model.submit_chore().0)
    guard model.submit_chore().1 is Some((id, input)) else { return shown }
    @rabbita.batch([
      shown,
      call(() => save_chore(id, input), result => {
        self.update(model => {
          match result {
            Ok(chore) => model.saved(id, chore)
            Err(_) =>
              model.editor_error(id, "Failed to save. Please try again.")
          }
        })
      }),
    ])
  })
}

///|
/// Archives the chore in the panel.
fn Store::archive(self : Store) -> Cmd {
  self.read(model => {
    guard model.editor() is Some({ id: Some(id), .. }) else {
      return @rabbita.none
    }
    call(() => archive_chore(id), result => {
      self.update(model => {
        match result {
          Ok(_) => model.archived(id)
          Err(_) =>
            model.editor_error(Some(id), "Failed to archive. Please try again.")
        }
      })
    })
  })
}

///|
/// Saves the label in the labels panel if it is valid.
fn Store::submit_label(self : Store) -> Cmd {
  self.read(model => {
    let shown = self.update(model => model.submit_label().0)
    guard model.submit_label().1 is Some((id, input)) else { return shown }
    @rabbita.batch([
      shown,
      call(() => save_label(id, input), result => {
        self.update(model => {
          match result {
            Ok(label) => model.label_saved(id, label)
            Err(_) => model.label_error(id, "Failed to save. Please try again.")
          }
        })
      }),
    ])
  })
}

///|
/// Deletes the label in the labels panel.
fn Store::delete_label(self : Store) -> Cmd {
  self.read(model => {
    guard model.panel is Some(Labels({ id: Some(id), .. })) else {
      return @rabbita.none
    }
    call(() => delete_label(id), result => {
      self.update(model => {
        match result {
          Ok(_) => model.label_deleted(id)
          Err(_) =>
            model.label_error(Some(id), "Failed to delete. Please try again.")
        }
      })
    })
  })
}

///|
/// Imports the definitions in the import/export panel if they are valid.
fn Store::import_definitions(self : Store) -> Cmd {
  self.read(model => {
    let shown = self.update(model => model.submit_import().0)
    guard model.submit_import().1 is Some(text) else { return shown }
    @rabbita.batch([
      shown,
      call(() => import_definitions(text), result => {
        match result {
          Ok(_) =>
            @rabbita.batch([
              self.update(model => { ..model, panel_open: false, }),
              self.reload(),
            ])
          Err(_) =>
            self.update(model => {
              model.edit_transfer(transfer => {
                ..transfer,
                error: "Failed to import. Please try again.",
              })
            })
        }
      }),
    ])
  })
}

///|
/// Asks before an action of the panel.
fn Store::ask_confirm(self : Store, confirm : Confirm) -> Cmd {
  @rabbita.batch([
    self.update(model => { ..model, confirm: Some(confirm), }),
    run(() => @ui.show_dialog(CONFIRM_ID, modal=true)),
  ])
}
