///|
priv suberror ApiError {
  BadRequest(String)
  NotFound
  InternalError(String)
}

///|
/// Offset of the user's local time (Asia/Tokyo) from UTC.
let local_offset_minutes = 540

///|
fn today() -> @core.Date {
  @core.Date::from_unix_seconds(
    @cloudflare.now_seconds(),
    offset_minutes=local_offset_minutes,
  )
}

///|
fn parse_id(segment : StringView) -> Int raise ApiError {
  guard segment.length() is (1..=9) && segment.iter().all(c => c is ('0'..='9')) else {
    raise NotFound
  }
  @string.parse_int(segment) catch {
    _ => raise NotFound
  }
}

///|
async fn read_json(request : @cloudflare.Request) -> Json {
  @json.parse(request.text()) catch {
    _ => raise BadRequest("Invalid JSON.")
  }
}

///|
async fn read_chore_input(
  request : @cloudflare.Request,
  db : @cloudflare.D1Database,
) -> @core.ChoreInput {
  let json = read_json(request)
  let input : @core.ChoreInput = @json.from_json(json) catch {
    _ => raise BadRequest("Invalid chore.")
  }
  let labels = list_labels(db)
  input.validate(labels) catch {
    ValidationError(message) => raise BadRequest(message)
  }
}

///|
/// `id` is the label being edited.
async fn read_label_input(
  request : @cloudflare.Request,
  db : @cloudflare.D1Database,
  id? : Int,
) -> @core.LabelInput {
  let json = read_json(request)
  let input : @core.LabelInput = @json.from_json(json) catch {
    _ => raise BadRequest("Invalid label.")
  }
  let labels = list_labels(db)
  input.validate(labels, id?) catch {
    ValidationError(message) => raise BadRequest(message)
  }
}

///|
async fn route(
  request : @cloudflare.Request,
  db : @cloudflare.D1Database,
) -> @cloudflare.Response {
  let segments = request
    .pathname()
    .split("/")
    .filter(segment => segment != "")
    .collect()
  match (request.method_(), segments) {
    ("GET", ["api", "chores"]) => {
      let today = today()
      let list : @core.ChoreList = {
        today,
        labels: list_labels(db),
        chores: list_chores(db),
        recent: list_recent_done(db, today.add_days(1 - @core.RECENT_DAYS)),
      }
      json_response(list.to_json(), 200)
    }
    ("POST", ["api", "chores"]) => {
      let input = read_chore_input(request, db)
      guard input.next_due is Some(next_due) else {
        raise BadRequest("Next due is required.")
      }
      json_response(insert_chore(db, input, next_due).to_json(), 201)
    }
    ("POST", ["api", "chores", "import"]) => {
      let text = request.text()
      let labels = list_labels(db)
      let plan = @core.ImportPlan::new(labels, @core.parse_definitions(text)) catch {
        ValidationError(message) => raise BadRequest(message)
      }
      json_response(import_definitions(db, plan, today()).to_json(), 200)
    }
    ("PUT", ["api", "chores", id]) => {
      let id = parse_id(id)
      let input = read_chore_input(request, db)
      let chore = find_chore(db, id).edit(input)
      json_response(update_chore(db, chore).to_json(), 200)
    }
    ("DELETE", ["api", "chores", id]) => {
      archive_chore(db, parse_id(id))
      @cloudflare.Response::empty(204)
    }
    ("POST", ["api", "chores", id, "complete"]) => {
      let completed = complete_chore(db, parse_id(id), today())
      json_response(completed.to_json(), 200)
    }
    ("GET", ["api", "chores", id, "completions"]) =>
      json_response(list_history(db, parse_id(id)).to_json(), 200)
    ("DELETE", ["api", "completions", id]) => {
      let chore = undo_completion(db, parse_id(id))
      json_response(chore.to_json(), 200)
    }
    ("POST", ["api", "labels"]) => {
      let input = read_label_input(request, db)
      json_response(insert_label(db, input).to_json(), 201)
    }
    ("PUT", ["api", "labels", id]) => {
      let id = parse_id(id)
      let input = read_label_input(request, db, id~)
      let label : @core.Label = { id, name: input.name, color: input.color, }
      json_response(update_label(db, label).to_json(), 200)
    }
    ("DELETE", ["api", "labels", id]) => {
      delete_label(db, parse_id(id))
      @cloudflare.Response::empty(204)
    }
    _ => raise NotFound
  }
}
