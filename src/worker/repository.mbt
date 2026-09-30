///|
let chore_columns = "id, title, interval_days, next_due, last_done, labels"

///|
/// `labels` is stored as a JSON text column of label ids.
fn decode_chore(row : Json) -> @core.Chore raise ApiError {
  guard row is Object(fields) && fields.get("labels") is Some(String(labels)) else {
    raise InternalError("invalid chore row: labels")
  }
  let fields = fields.copy()
  fields["labels"] = @json.parse(labels) catch {
    error => raise InternalError("invalid chore labels: \{error}")
  }
  @json.from_json(Json::object(fields)) catch {
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
fn labels_param(labels : Array[Int]) -> @cloudflare.D1Param {
  Text(labels.to_json().stringify())
}

///|
async fn list_chores(db : @cloudflare.D1Database) -> Array[@core.Chore] {
  let rows = db
    .prepare(
      "SELECT \{chore_columns} FROM chores WHERE archived = 0 ORDER BY id",
    )
    .all()
  decode_rows(rows).map(decode_chore)
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
  next_due : @core.Date,
) -> @core.Chore {
  let rows = insert_chore_statement(db, input, next_due).all()
  guard first_row(rows) is Some(row) else {
    raise InternalError("insert returned no row")
  }
  decode_chore(row)
}

///|
fn insert_chore_statement(
  db : @cloudflare.D1Database,
  input : @core.ChoreInput,
  next_due : @core.Date,
) -> @cloudflare.D1PreparedStatement {
  db
  .prepare(
    "INSERT INTO chores (title, interval_days, next_due, labels) VALUES (?, ?, ?, ?) RETURNING \{chore_columns}",
  )
  .bind([
    Text(input.title),
    Integer(input.interval_days),
    Text(next_due.to_string()),
    labels_param(input.labels),
  ])
}

///|
fn update_chore_statement(
  db : @cloudflare.D1Database,
  chore : @core.Chore,
) -> @cloudflare.D1PreparedStatement {
  db
  .prepare(
    "UPDATE chores SET title = ?, interval_days = ?, next_due = ?, labels = ? WHERE id = ? AND archived = 0 RETURNING \{chore_columns}",
  )
  .bind([
    Text(chore.title),
    Integer(chore.interval_days),
    Text(chore.next_due.to_string()),
    labels_param(chore.labels),
    Integer(chore.id),
  ])
}

///|
/// Applies an import. Labels are saved first, because chores refer to their
/// ids; each step runs in a single transaction.
async fn import_definitions(
  db : @cloudflare.D1Database,
  plan : @core.ImportPlan,
  today : @core.Date,
) -> @core.ImportResult {
  batch(
    db,
    [
      ..plan.label_updates.map(label => update_label_statement(db, label)),
      ..plan.label_creates.map(input => insert_label_statement(db, input)),
    ],
  )
  let existing = list_chores(db)
  let labels = list_labels(db)
  let changes = plan.chore_changes(existing, labels, today) catch {
    ValidationError(message) => raise BadRequest(message)
  }
  batch(
    db,
    [
      ..changes.updates.map(chore => update_chore_statement(db, chore)),
      ..changes.creates.map(create => {
        insert_chore_statement(db, create.0, create.1)
      }),
    ],
  )
  { created: changes.creates.length(), updated: changes.updates.length(), }
}

///|
async fn batch(
  db : @cloudflare.D1Database,
  statements : Array[@cloudflare.D1PreparedStatement],
) -> Unit {
  if !statements.is_empty() {
    ignore(db.batch(statements))
  }
}

///|
async fn update_chore(
  db : @cloudflare.D1Database,
  chore : @core.Chore,
) -> @core.Chore {
  let rows = update_chore_statement(db, chore).all()
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
/// Only the latest completion of a chore can be undone (see `@core.RecentDone::can_undo`).
async fn undo_completion(
  db : @cloudflare.D1Database,
  completion_id : Int,
) -> @core.Chore {
  let rows = db
    .prepare(
      "SELECT chore_id, previous_next_due, previous_last_done, (SELECT MAX(latest.id) FROM completions AS latest WHERE latest.chore_id = completions.chore_id) AS latest_id FROM completions WHERE id = ?",
    )
    .bind([Integer(completion_id)])
    .all()
  guard first_row(rows)
    is Some(
      {
        "chore_id": Number(chore_id, ..),
        "previous_next_due": String(_) as previous_next_due,
        "previous_last_done": previous_last_done,
        "latest_id": Number(latest_id, ..),
        ..
      }
    ) else {
    raise NotFound
  }
  guard latest_id.to_int() == completion_id else {
    raise BadRequest("Only the latest completion of a chore can be undone.")
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

///|
fn decode_rows(rows : Json) -> Array[Json] {
  match rows {
    Array(rows) => rows
    _ => []
  }
}

///|
async fn list_recent_done(
  db : @cloudflare.D1Database,
  since : @core.Date,
) -> Array[@core.RecentDone] {
  let rows = db
    .prepare(
      "SELECT completions.id AS completion_id, completions.chore_id, chores.title, completions.done_on FROM completions JOIN chores ON chores.id = completions.chore_id WHERE completions.done_on >= ? ORDER BY completions.done_on DESC, completions.id DESC",
    )
    .bind([Text(since.to_string())])
    .all()
  decode_rows(rows).map(row => {
    @json.from_json(row) catch {
      error => raise InternalError("invalid completion row: \{error}")
    }
  })
}

///|
let history_limit = 20

///|
async fn list_history(db : @cloudflare.D1Database, id : Int) -> @core.History {
  // Also checks that the chore exists.
  let _ = find_chore(db, id)
  let rows = db
    .prepare(
      "SELECT done_on FROM completions WHERE chore_id = ? ORDER BY done_on DESC, id DESC LIMIT ?",
    )
    .bind([Integer(id), Integer(history_limit)])
    .all()
  let dates = decode_rows(rows).map(row => {
    guard row is { "done_on": done_on, .. } else {
      raise InternalError("invalid history row")
    }
    let date : @core.Date = @json.from_json(done_on) catch {
      error => raise InternalError("invalid history row: \{error}")
    }
    date
  })
  { dates, }
}

///|
let label_columns = "id, name, color"

///|
fn decode_label(row : Json) -> @core.Label raise ApiError {
  @json.from_json(row) catch {
    error => raise InternalError("invalid label row: \{error}")
  }
}

///|
async fn list_labels(db : @cloudflare.D1Database) -> Array[@core.Label] {
  let rows = db
    .prepare("SELECT \{label_columns} FROM labels ORDER BY name")
    .all()
  decode_rows(rows).map(decode_label)
}

///|
fn insert_label_statement(
  db : @cloudflare.D1Database,
  input : @core.LabelInput,
) -> @cloudflare.D1PreparedStatement {
  db
  .prepare(
    "INSERT INTO labels (name, color) VALUES (?, ?) RETURNING \{label_columns}",
  )
  .bind([Text(input.name), Text(input.color.name())])
}

///|
fn update_label_statement(
  db : @cloudflare.D1Database,
  label : @core.Label,
) -> @cloudflare.D1PreparedStatement {
  db
  .prepare(
    "UPDATE labels SET name = ?, color = ? WHERE id = ? RETURNING \{label_columns}",
  )
  .bind([Text(label.name), Text(label.color.name()), Integer(label.id)])
}

///|
async fn insert_label(
  db : @cloudflare.D1Database,
  input : @core.LabelInput,
) -> @core.Label {
  let rows = insert_label_statement(db, input).all()
  guard first_row(rows) is Some(row) else {
    raise InternalError("insert returned no row")
  }
  decode_label(row)
}

///|
async fn update_label(
  db : @cloudflare.D1Database,
  label : @core.Label,
) -> @core.Label {
  let rows = update_label_statement(db, label).all()
  guard first_row(rows) is Some(row) else { raise NotFound }
  decode_label(row)
}

///|
/// Deletes the label and removes it from every chore, archived ones included.
async fn delete_label(db : @cloudflare.D1Database, id : Int) -> Unit {
  let results = db.batch([
    db
    .prepare(
      "UPDATE chores SET labels = (SELECT json_group_array(value) FROM json_each(chores.labels) WHERE value != ?) WHERE EXISTS (SELECT 1 FROM json_each(chores.labels) WHERE value = ?)",
    )
    .bind([Integer(id), Integer(id)]),
    db
    .prepare("DELETE FROM labels WHERE id = ? RETURNING id")
    .bind([Integer(id)]),
  ])
  guard results is [_, deleted] && first_row(deleted) is Some(_) else {
    raise NotFound
  }
}
