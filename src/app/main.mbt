///|
using @rabbita {type Cmd, type Emit, type Html, type Val}

///|
const EDITOR_ID = "chore-editor"

///|
const CONFIRM_ID = "confirm-dialog"

///|
const UNDO_DURATION_MS = 8000

///|
fn app() -> Val[Html] {
  let current = Ref(Model::new())
  // The state of Rabbita holds the model and applies the changes given to `set`.
  let (model, set) = @rabbita.create_state_with_init(
    init=set => (Model::new(), Store::{ set, current, }.reload()),
    update=(model, change : (Model) -> Model, _) => {
      (change(model), @rabbita.none)
    },
  )
  let store : Store = { set, current, }
  model.view(model => view(model, store))
}

///|
fn main {
  @rabbita.new(app).mount("app")
}
