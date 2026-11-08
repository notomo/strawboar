// The API of the Worker, as async functions that fail when a request fails.

///|
async fn[T : @json.FromJson] send_json(
  method_ : String,
  url : String,
  body? : Json,
) -> T {
  let text = match body {
    Some(json) =>
      @web.send(
        method_~,
        url,
        body=json.stringify(),
        content_type="application/json",
      )
    None => @web.send(method_~, url)
  }
  @json.from_json(@json.parse(text))
}

///|
async fn fetch_chores() -> @core.ChoreList {
  send_json("GET", "/api/chores")
}

///|
async fn complete_chore(id : Int32) -> @core.Completed {
  send_json("POST", "/api/chores/\{id}/complete")
}

///|
/// Returns the chore with its previous due date.
async fn undo_completion(completion_id : Int32) -> @core.Chore {
  send_json("DELETE", "/api/completions/\{completion_id}")
}

///|
/// Adds a chore if `id` is `None`, or updates it.
async fn save_chore(id : Int32?, input : @core.ChoreInput) -> @core.Chore {
  match id {
    None => send_json("POST", "/api/chores", body=input.to_json())
    Some(id) => send_json("PUT", "/api/chores/\{id}", body=input.to_json())
  }
}

///|
async fn archive_chore(id : Int32) -> Unit {
  @web.send(method_="DELETE", "/api/chores/\{id}") |> ignore
}

///|
/// Adds a label if `id` is `None`, or updates it.
async fn save_label(id : Int32?, input : @core.LabelInput) -> @core.Label {
  match id {
    None => send_json("POST", "/api/labels", body=input.to_json())
    Some(id) => send_json("PUT", "/api/labels/\{id}", body=input.to_json())
  }
}

///|
async fn delete_label(id : Int32) -> Unit {
  @web.send(method_="DELETE", "/api/labels/\{id}") |> ignore
}

///|
async fn import_definitions(text : String) -> @core.ImportResult {
  @json.from_json(
    @json.parse(@web.send(method_="POST", "/api/chores/import", body=text)),
  )
}
