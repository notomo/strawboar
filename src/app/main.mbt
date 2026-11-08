///|
using @html {type Html}

///|
const EDITOR_ID = "chore-editor"

///|
const CONFIRM_ID = "confirm-dialog"

///|
const UNDO_DURATION_MS = 8000

///|
fn main {
  let store : Store = { app: @html.App::new("app", Model::new()), }
  store.app.mount(model => view(model, store))
  store.reload()
}
