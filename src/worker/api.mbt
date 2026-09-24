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
async fn read_chore_input(request : @cloudflare.Request) -> @core.ChoreInput {
  let json = read_json(request)
  let input : @core.ChoreInput = @json.from_json(json) catch {
    _ => raise BadRequest("Invalid chore.")
  }
  input.validate() catch {
    ValidationError(message) => raise BadRequest(message)
  }
}

///|
async fn read_postpone_days(request : @cloudflare.Request) -> Int {
  let json = read_json(request)
  let postpone : @core.Postpone = @json.from_json(json) catch {
    _ => raise BadRequest("Invalid postpone.")
  }
  guard postpone.days is (1..=365) else {
    raise BadRequest("Days must be between 1 and 365.")
  }
  postpone.days
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
        chores: list_chores(db),
        recent: list_recent_done(db, today.add_days(1 - @core.RECENT_DAYS)),
      }
      json_response(list.to_json(), 200)
    }
    ("POST", ["api", "chores"]) => {
      let input = read_chore_input(request)
      json_response(insert_chore(db, input).to_json(), 201)
    }
    ("PUT", ["api", "chores", id]) => {
      let id = parse_id(id)
      let input = read_chore_input(request)
      json_response(update_chore(db, id, input).to_json(), 200)
    }
    ("DELETE", ["api", "chores", id]) => {
      archive_chore(db, parse_id(id))
      @cloudflare.Response::empty(204)
    }
    ("POST", ["api", "chores", id, "complete"]) => {
      let completed = complete_chore(db, parse_id(id), today())
      json_response(completed.to_json(), 200)
    }
    ("POST", ["api", "chores", id, "postpone"]) => {
      let id = parse_id(id)
      let days = read_postpone_days(request)
      let chore = find_chore(db, id).postpone(today(), days)
      json_response(save_schedule(db, chore).to_json(), 200)
    }
    ("GET", ["api", "chores", id, "completions"]) =>
      json_response(list_history(db, parse_id(id)).to_json(), 200)
    ("DELETE", ["api", "completions", id]) => {
      let chore = undo_completion(db, parse_id(id))
      json_response(chore.to_json(), 200)
    }
    _ => raise NotFound
  }
}
