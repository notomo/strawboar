///|
let chore_columns = "id, title, interval_days, next_due, last_done"

///|
fn decode_chore(row : Json) -> @core.Chore raise ApiError {
  @json.from_json(row) catch {
    error => raise InternalError("invalid chore row: \{error}")
  }
}

///|
fn first_row(rows : Json) -> Json? {
  match rows {
    [row, ..] => Some(row)
    _ => None
  }
}

///|
fn date_param(date : @core.Date?) -> @cloudflare.D1Param {
  match date {
    Some(date) => Text(date.to_string())
    None => Null
  }
}

///|
async fn list_chores(db : @cloudflare.D1Database) -> Array[@core.Chore] {
  let rows = db
    .prepare(
      "SELECT \{chore_columns} FROM chores WHERE archived = 0 ORDER BY id",
    )
    .all()
  guard rows is Array(rows) else { return [] }
  rows.map(decode_chore)
}

///|
async fn find_chore(db : @cloudflare.D1Database, id : Int) -> @core.Chore {
  let rows = db
    .prepare(
      "SELECT \{chore_columns} FROM chores WHERE id = ? AND archived = 0",
    )
    .bind([Integer(id)])
    .all()
  guard first_row(rows) is Some(row) else { raise NotFound }
  decode_chore(row)
}

///|
async fn insert_chore(
  db : @cloudflare.D1Database,
  input : @core.ChoreInput,
) -> @core.Chore {
  let rows = db
    .prepare(
      "INSERT INTO chores (title, interval_days, next_due) VALUES (?, ?, ?) RETURNING \{chore_columns}",
    )
    .bind([
      Text(input.title),
      Integer(input.interval_days),
      Text(input.next_due.to_string()),
    ])
    .all()
  guard first_row(rows) is Some(row) else {
    raise InternalError("insert returned no row")
  }
  decode_chore(row)
}

///|
async fn update_chore(
  db : @cloudflare.D1Database,
  id : Int,
  input : @core.ChoreInput,
) -> @core.Chore {
  let rows = db
    .prepare(
      "UPDATE chores SET title = ?, interval_days = ?, next_due = ? WHERE id = ? AND archived = 0 RETURNING \{chore_columns}",
    )
    .bind([
      Text(input.title),
      Integer(input.interval_days),
      Text(input.next_due.to_string()),
      Integer(id),
    ])
    .all()
  guard first_row(rows) is Some(row) else { raise NotFound }
  decode_chore(row)
}

///|
async fn archive_chore(db : @cloudflare.D1Database, id : Int) -> Unit {
  let changes = db
    .prepare("UPDATE chores SET archived = 1 WHERE id = ? AND archived = 0")
    .bind([Integer(id)])
    .run()
  guard changes > 0 else { raise NotFound }
}

///|
async fn save_schedule(
  db : @cloudflare.D1Database,
  chore : @core.Chore,
) -> @core.Chore {
  let rows = db
    .prepare(
      "UPDATE chores SET next_due = ?, last_done = ? WHERE id = ? AND archived = 0 RETURNING \{chore_columns}",
    )
    .bind([
      date_param(Some(chore.next_due)),
      date_param(chore.last_done),
      Integer(chore.id),
    ])
    .all()
  guard first_row(rows) is Some(row) else { raise NotFound }
  decode_chore(row)
}

///|
async fn complete_chore(
  db : @cloudflare.D1Database,
  id : Int,
  today : @core.Date,
) -> @core.Completed {
  let before = find_chore(db, id)
  let after = before.complete(today)
  let results = db.batch([
    db
    .prepare(
      "UPDATE chores SET next_due = ?, last_done = ? WHERE id = ? RETURNING \{chore_columns}",
    )
    .bind([
      date_param(Some(after.next_due)),
      date_param(after.last_done),
      Integer(id),
    ]),
    db
    .prepare(
      "INSERT INTO completions (chore_id, done_on, previous_next_due, previous_last_done) VALUES (?, ?, ?, ?) RETURNING id",
    )
    .bind([
      Integer(id),
      Text(today.to_string()),
      date_param(Some(before.next_due)),
      date_param(before.last_done),
    ]),
  ])
  guard results is [chore_rows, completion_rows] &&
    first_row(chore_rows) is Some(chore_row) &&
    first_row(completion_rows) is Some({ "id": Number(completion_id, ..), .. }) else {
    raise InternalError("unexpected batch result")
  }
  { chore: decode_chore(chore_row), completion_id: completion_id.to_int(), }
}

///|
/// Deletes the completion and restores the chore to the state before it.
async fn undo_completion(
  db : @cloudflare.D1Database,
  completion_id : Int,
) -> @core.Chore {
  let rows = db
    .prepare(
      "SELECT chore_id, previous_next_due, previous_last_done FROM completions WHERE id = ?",
    )
    .bind([Integer(completion_id)])
    .all()
  guard first_row(rows)
    is Some(
      {
        "chore_id": Number(chore_id, ..),
        "previous_next_due": String(_) as previous_next_due,
        "previous_last_done": previous_last_done,
        ..
      }
    ) else {
    raise NotFound
  }
  let results = db.batch([
    db
    .prepare(
      "UPDATE chores SET next_due = ?, last_done = ? WHERE id = ? RETURNING \{chore_columns}",
    )
    .bind([
      text_or_null(previous_next_due),
      text_or_null(previous_last_done),
      Integer(chore_id.to_int()),
    ]),
    db
    .prepare("DELETE FROM completions WHERE id = ?")
    .bind([Integer(completion_id)]),
  ])
  guard results is [chore_rows, _] && first_row(chore_rows) is Some(chore_row) else {
    raise NotFound
  }
  decode_chore(chore_row)
}

///|
fn text_or_null(value : Json) -> @cloudflare.D1Param {
  match value {
    String(s) => Text(s)
    _ => Null
  }
}
