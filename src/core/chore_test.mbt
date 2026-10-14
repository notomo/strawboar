///|
fn date(s : String) -> @core.Date {
  @core.Date::parse(s) catch {
    _ => abort("invalid date: \{s}")
  }
}

///|
fn chore(
  id~ : Int32 = 1,
  title~ : String = "chore",
  interval_days~ : Int32 = 10,
  repeat? : @core.Repeat,
  next_due~ : String = "2026-09-24",
  last_done? : String,
  description~ : String = "",
  labels~ : Array[Int32] = [],
) -> @core.Chore {
  {
    id,
    title,
    description,
    repeat: repeat.unwrap_or(AfterDone(interval_days)),
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
fn edit_input(interval_days : Int32) -> @core.ChoreInput {
  edit_repeat(AfterDone(interval_days))
}

///|
fn edit_repeat(repeat : @core.Repeat) -> @core.ChoreInput {
  { title: "edited", description: "", repeat, next_due: None, labels: [1], }
}

///|
test "edit recalculates the due date from the last completion" {
  let c = chore(interval_days=7, next_due="2026-09-27", last_done="2026-09-20").edit(
    edit_input(30),
  )
  inspect(c.next_due, content="2026-10-20")
  assert_true(c.repeat == AfterDone(30))
  inspect(c.title, content="edited")
  assert_eq(c.labels, [1])
  let c = chore(description="old").edit({ ..edit_input(7), description: "new", })
  inspect(c.description, content="new")
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
  let with_description = { ..input, description: "steps\nmore", }
  let decoded : @core.ChoreInput = @json.from_json(with_description.to_json())
  inspect(decoded.description, content="steps\nmore")
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
  let c = chore(last_done="2026-09-14", description="1. Fill\n2. Wash")
  let json = c.to_json()
  inspect(
    json.stringify(),
    content=(
      #|{"id":1,"title":"chore","description":"1. Fill\n2. Wash","interval_days":10,"next_due":"2026-09-24","last_done":"2026-09-14","labels":[]}
    ),
  )
  let decoded : @core.Chore = @json.from_json(json)
  assert_true(decoded == c)
  let never_done = chore()
  let decoded : @core.Chore = @json.from_json(never_done.to_json())
  assert_eq(decoded.description, "")
  assert_true(decoded == never_done)
}

///|
fn label(
  id : Int32,
  name : String,
  color~ : @core.LabelColor = Gray,
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
    description: "",
    repeat: AfterDone(7),
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
  let valid = input.validate([]) catch { _ => abort("invalid") }
  inspect(valid.description, content="")
  let valid = { ..input, description: "  1. Fill\n2. Wash\n\n", }.validate([]) catch {
    _ => abort("invalid")
  }
  inspect(
    valid.description,
    content=(
      #|1. Fill
      #|2. Wash
    ),
  )
  inspect(
    validation_message({ ..input, description: "a".repeat(2001), }),
    content="Description must be at most 2000 characters.",
  )
  inspect(
    validation_message({ ..input, repeat: AfterDone(0), }),
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
fn label_message(input : @core.LabelInput, id? : Int32) -> String {
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
  let done = (completion_id : Int32, chore_id : Int32) => {
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

///|
fn monthly(
  months~ : Int32 = 1,
  day~ : Int32 = 28,
  lead_days~ : Int32 = 7,
) -> @core.Repeat {
  Monthly({ months, day, lead_days, })
}

///|
test "monthly urgency follows the lead days" {
  let c = chore(repeat=monthly(lead_days=21), next_due="2026-10-28")
  inspect(urgency_label(c, "2026-10-06"), content="later")
  inspect(urgency_label(c, "2026-10-07"), content="soon")
  inspect(urgency_label(c, "2026-10-28"), content="due")
  let no_lead = chore(repeat=monthly(lead_days=0), next_due="2026-10-28")
  inspect(urgency_label(no_lead, "2026-10-27"), content="later")
}

///|
test "monthly complete moves to the next due date whenever done" {
  let c = chore(repeat=monthly(day=31), next_due="2026-10-31")
  // done late
  let late = c.complete(date("2026-11-03"))
  inspect(late.next_due, content="2026-11-30")
  assert_eq(late.last_done.map(d => d.to_string()), Some("2026-11-03"))
  // the day is kept after a shorter month
  inspect(late.complete(date("2026-11-30")).next_due, content="2026-12-31")
  // done early
  let c = chore(repeat=monthly(months=3, day=1), next_due="2026-12-01")
  inspect(c.complete(date("2026-11-20")).next_due, content="2027-03-01")
}

///|
test "edit moves a monthly chore to its day in the month it is due" {
  let c = chore(
    repeat=monthly(day=28),
    next_due="2026-10-28",
    last_done="2026-09-27",
  )
  let edited = c.edit(edit_repeat(monthly(day=25, lead_days=10)))
  inspect(edited.next_due, content="2026-10-25")
  assert_true(edited.repeat == monthly(day=25, lead_days=10))
  // from after done
  let c = chore(interval_days=14, next_due="2026-10-12", last_done="2026-09-28")
  inspect(c.edit(edit_repeat(monthly(day=31))).next_due, content="2026-10-31")
  // back to after done
  inspect(edited.edit(edit_input(7)).next_due, content="2026-10-04")
}

///|
test "first_due" {
  let input : @core.ChoreInput = {
    title: "Rent",
    description: "",
    repeat: monthly(day=31),
    next_due: Some(date("2026-11-10")),
    labels: [],
  }
  inspect(input.first_due(date("2026-10-11")), content="2026-11-30")
  inspect(
    { ..input, next_due: None, }.first_due(date("2026-10-11")),
    content="2026-10-31",
  )
  inspect(
    { ..input, repeat: AfterDone(7), }.first_due(date("2026-10-11")),
    content="2026-11-10",
  )
}

///|
test "monthly json" {
  let c = chore(repeat=monthly(months=2, day=5, lead_days=3))
  let json = c.to_json()
  inspect(
    json.stringify(),
    content=(
      #|{"id":1,"title":"chore","description":"","monthly":{"months":2,"day":5,"lead_days":3},"next_due":"2026-09-24","last_done":null,"labels":[]}
    ),
  )
  let decoded : @core.Chore = @json.from_json(json)
  assert_true(decoded == c)
}

///|
test "validate monthly" {
  let input : @core.ChoreInput = {
    title: "Rent",
    description: "",
    repeat: monthly(),
    next_due: Some(date("2026-10-28")),
    labels: [],
  }
  inspect(validation_message(input), content="ok: Rent ")
  inspect(
    validation_message({ ..input, repeat: monthly(months=0), }),
    content="Months must be between 1 and 120.",
  )
  inspect(
    validation_message({ ..input, repeat: monthly(day=32), }),
    content="Day must be between 1 and 31.",
  )
  inspect(
    validation_message({ ..input, repeat: monthly(lead_days=28), }),
    content="Lead days must be between 0 and 27.",
  )
  inspect(
    validation_message({ ..input, repeat: monthly(months=2, lead_days=55), }),
    content="ok: Rent ",
  )
}

///|
test "dashboard sorts monthly chores by the approximate interval" {
  let chores = [
    chore(id=1, title="weekly", interval_days=7, next_due="2026-10-12"),
    chore(
      id=2,
      title="rent",
      repeat=monthly(lead_days=21),
      next_due="2026-10-13",
    ),
  ]
  let dashboard = @core.Dashboard::new(chores, date("2026-10-11"))
  // elapsed fraction: 28/30 > 6/7
  assert_eq(dashboard.soon.map(c => c.title), ["rent", "weekly"])
}

///|
test "dashboard puts monthly chores first in each section" {
  let rent = (id : Int32, title : String, next_due : String) => {
    chore(id~, title~, repeat=monthly(lead_days=3), next_due~)
  }
  let chores = [
    chore(id=1, title="weekly due", interval_days=7, next_due="2026-10-09"),
    rent(2, "rent due", "2026-10-11"),
    chore(id=3, title="weekly soon", interval_days=7, next_due="2026-10-12"),
    rent(4, "rent soon", "2026-10-13"),
    chore(id=5, title="weekly later", interval_days=7, next_due="2026-10-15"),
    rent(6, "rent later", "2026-11-01"),
  ]
  let dashboard = @core.Dashboard::new(chores, date("2026-10-11"))
  let titles = (chores : Array[@core.Chore]) => chores.map(c => c.title)
  assert_eq(titles(dashboard.due), ["rent due", "weekly due"])
  assert_eq(titles(dashboard.soon), ["rent soon", "weekly soon"])
  assert_eq(titles(dashboard.later), ["rent later", "weekly later"])
  assert_eq(dashboard.soon_until().map(d => d.to_string()), Some("2026-10-13"))
}

///|
test "dashboard has no soon range without soon chores" {
  let chores = [chore(next_due="2026-10-30")]
  let dashboard = @core.Dashboard::new(chores, date("2026-10-11"))
  assert_true(dashboard.soon_until() is None)
}
