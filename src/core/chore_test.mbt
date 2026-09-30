///|
fn date(s : String) -> @core.Date {
  @core.Date::parse(s) catch {
    _ => abort("invalid date: \{s}")
  }
}

///|
fn chore(
  id? : Int = 1,
  title? : String = "chore",
  interval_days? : Int = 10,
  next_due? : String = "2026-09-24",
  last_done? : String,
  labels? : Array[Int] = [],
) -> @core.Chore {
  {
    id,
    title,
    interval_days,
    next_due: date(next_due),
    last_done: last_done.map(date),
    labels,
  }
}

///|
fn urgency_label(chore : @core.Chore, today : String) -> String {
  match chore.urgency(date(today)) {
    Due => "due"
    Soon => "soon"
    Later => "later"
  }
}

///|
test "urgency" {
  let c = chore(interval_days=10, next_due="2026-09-24")
  inspect(urgency_label(c, "2026-09-30"), content="due")
  inspect(urgency_label(c, "2026-09-24"), content="due")
  inspect(urgency_label(c, "2026-09-22"), content="soon")
  inspect(urgency_label(c, "2026-09-21"), content="later")
  // a daily chore is only shown on the day
  let daily = chore(interval_days=1, next_due="2026-09-25")
  inspect(urgency_label(daily, "2026-09-24"), content="later")
}

///|
test "complete" {
  let c = chore(interval_days=7, next_due="2026-09-20").complete(
    date("2026-09-24"),
  )
  inspect(c.next_due, content="2026-10-01")
  assert_eq(c.last_done.map(d => d.to_string()), Some("2026-09-24"))
}

///|
fn edit_input(interval_days : Int) -> @core.ChoreInput {
  { title: "edited", interval_days, next_due: None, labels: [1], }
}

///|
test "edit recalculates the due date from the last completion" {
  let c = chore(interval_days=7, next_due="2026-09-27", last_done="2026-09-20").edit(
    edit_input(30),
  )
  inspect(c.next_due, content="2026-10-20")
  inspect(c.interval_days, content="30")
  inspect(c.title, content="edited")
  assert_eq(c.labels, [1])
}

///|
test "edit keeps the due date of a chore never done" {
  let c = chore(interval_days=7, next_due="2026-09-27").edit(edit_input(30))
  inspect(c.next_due, content="2026-09-27")
}

///|
test "chore input json" {
  let input = edit_input(7)
  inspect(
    input.to_json().stringify(),
    content=(
      #|{"title":"edited","interval_days":7,"labels":[1]}
    ),
  )
  let decoded : @core.ChoreInput = @json.from_json(input.to_json())
  assert_true(decoded.next_due is None)
  let with_due = { ..input, next_due: Some(date("2026-09-24")), }
  let decoded : @core.ChoreInput = @json.from_json(with_due.to_json())
  assert_eq(decoded.next_due.map(d => d.to_string()), Some("2026-09-24"))
  let decoded : @core.ChoreInput = @json.from_json(
    @json.parse(
      (
        #|{"title":"a","interval_days":7,"next_due":null,"labels":[]}
      ),
    ),
  )
  assert_true(decoded.next_due is None)
}

///|
test "dashboard groups and sorts chores" {
  let chores = [
    chore(
      id=1,
      title="weekly overdue 2d",
      interval_days=7,
      next_due="2026-09-22",
    ),
    chore(
      id=2,
      title="monthly overdue 2d",
      interval_days=30,
      next_due="2026-09-22",
    ),
    chore(id=3, title="daily today", interval_days=1, next_due="2026-09-24"),
    chore(id=4, title="soon", interval_days=10, next_due="2026-09-25"),
    chore(id=5, title="later b", interval_days=30, next_due="2026-10-10"),
    chore(id=6, title="later a", interval_days=30, next_due="2026-10-01"),
  ]
  let dashboard = @core.Dashboard::new(chores, date("2026-09-24"))
  let titles = (chores : Array[@core.Chore]) => chores.map(c => c.title)
  // elapsed fraction: 9/7 > 32/30 > 1/1
  assert_eq(titles(dashboard.due), [
    "weekly overdue 2d", "monthly overdue 2d", "daily today",
  ])
  assert_eq(titles(dashboard.soon), ["soon"])
  assert_eq(titles(dashboard.later), ["later a", "later b"])
}

///|
test "chore json round trip" {
  let c = chore(last_done="2026-09-14")
  let json = c.to_json()
  inspect(
    json.stringify(),
    content=(
      #|{"id":1,"title":"chore","interval_days":10,"next_due":"2026-09-24","last_done":"2026-09-14","labels":[]}
    ),
  )
  let decoded : @core.Chore = @json.from_json(json)
  assert_true(decoded == c)
  let never_done = chore()
  let decoded : @core.Chore = @json.from_json(never_done.to_json())
  assert_true(decoded == never_done)
}

///|
fn label(
  id : Int,
  name : String,
  color? : @core.LabelColor = Gray,
) -> @core.Label {
  { id, name, color, }
}

///|
fn validation_message(input : @core.ChoreInput) -> String {
  try input.validate([label(1, "bath"), label(2, "weekly")]) catch {
    ValidationError(message) => message
  } noraise {
    valid =>
      "ok: \{valid.title} \{valid.labels.map(id => id.to_string()).join(",")}"
  }
}

///|
test "validate" {
  let input : @core.ChoreInput = {
    title: "  Clean the bath  ",
    interval_days: 7,
    next_due: Some(date("2026-09-24")),
    labels: [],
  }
  inspect(validation_message(input), content="ok: Clean the bath ")
  inspect(
    validation_message({ ..input, title: "   ", }),
    content="Title is required.",
  )
  inspect(
    validation_message({ ..input, title: "a".repeat(101), }),
    content="Title must be at most 100 characters.",
  )
  inspect(
    validation_message({ ..input, interval_days: 0, }),
    content="Interval must be between 1 and 3650 days.",
  )
  inspect(
    validation_message({ ..input, labels: [2, 1, 2], }),
    content="ok: Clean the bath 2,1",
  )
  inspect(
    validation_message({ ..input, labels: [3], }),
    content="Unknown label.",
  )
  inspect(
    validation_message({ ..input, labels: Array::makei(11, i => i), }),
    content="A chore can have at most 10 labels.",
  )
}

///|
test "labels_in" {
  let labels = [label(1, "bath"), label(2, "kitchen"), label(3, "weekly")]
  let c = chore(labels=[3, 1])
  assert_eq(c.labels_in(labels).map(l => l.name), ["bath", "weekly"])
  assert_true(c.has_label(3))
  assert_false(c.has_label(2))
}

///|
fn label_message(input : @core.LabelInput, id? : Int) -> String {
  try input.validate([label(1, "bath"), label(2, "weekly")], id?) catch {
    ValidationError(message) => message
  } noraise {
    valid => "ok: \{valid.name}"
  }
}

///|
test "validate label" {
  let input : @core.LabelInput = { name: " kitchen ", color: Blue, }
  inspect(label_message(input), content="ok: kitchen")
  inspect(label_message({ ..input, name: " ", }), content="Name is required.")
  inspect(
    label_message({ ..input, name: "a".repeat(31), }),
    content="Name must be at most 30 characters.",
  )
  inspect(
    label_message({ ..input, name: "bath", }),
    content="A label named bath already exists.",
  )
  // Renaming a label to its own name is allowed.
  inspect(label_message({ ..input, name: "bath", }, id=1), content="ok: bath")
}

///|
test "label json" {
  let l = label(1, "bath", color=Teal)
  inspect(
    l.to_json().stringify(),
    content=(
      #|{"id":1,"name":"bath","color":"teal"}
    ),
  )
  let decoded : @core.Label = @json.from_json(l.to_json())
  assert_true(decoded == l)
  let json = @json.parse(
    (
      #|{"id":1,"name":"bath","color":"black"}
    ),
  )
  let invalid = try {
    let _ : @core.Label = @json.from_json(json)
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}

///|
test "upsert_label" {
  let labels = [label(1, "bath"), label(2, "weekly")]
  let labels = @core.upsert_label(labels, label(3, "kitchen"))
  assert_eq(labels.map(l => l.name), ["bath", "kitchen", "weekly"])
  let labels = @core.upsert_label(labels, label(1, "zoo"))
  assert_eq(labels.map(l => l.name), ["kitchen", "weekly", "zoo"])
}

///|
test "can_undo" {
  let done = (completion_id : Int, chore_id : Int) => {
    let r : @core.RecentDone = {
      completion_id,
      chore_id,
      title: "chore",
      done_on: date("2026-09-24"),
    }
    r
  }
  let recent = [done(3, 1), done(2, 2), done(1, 1)]
  assert_eq(recent.map(r => r.can_undo(recent)), [true, true, false])
}

///|
test "parse_days" {
  assert_eq(@core.parse_days(" 14 "), Some(14))
  assert_eq(@core.parse_days(""), None)
  assert_eq(@core.parse_days("-1"), None)
  assert_eq(@core.parse_days("1.5"), None)
  assert_eq(@core.parse_days("999999"), None)
}
