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
) -> @core.Chore {
  {
    id,
    title,
    interval_days,
    next_due: date(next_due),
    last_done: last_done.map(date),
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
test "postpone from today when overdue" {
  let c = chore(next_due="2026-09-20").postpone(date("2026-09-24"), 3)
  inspect(c.next_due, content="2026-09-27")
}

///|
test "postpone from due date when not yet due" {
  let c = chore(next_due="2026-09-30").postpone(date("2026-09-24"), 3)
  inspect(c.next_due, content="2026-10-03")
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
      #|{"id":1,"title":"chore","interval_days":10,"next_due":"2026-09-24","last_done":"2026-09-14"}
    ),
  )
  let decoded : @core.Chore = @json.from_json(json)
  assert_true(decoded == c)
  let never_done = chore()
  let decoded : @core.Chore = @json.from_json(never_done.to_json())
  assert_true(decoded == never_done)
}

///|
fn validation_message(input : @core.ChoreInput) -> String {
  try input.validate() catch {
    ValidationError(message) => message
  } noraise {
    valid => "ok: \{valid.title}"
  }
}

///|
test "validate" {
  let input : @core.ChoreInput = {
    title: "  Clean the bath  ",
    interval_days: 7,
    next_due: date("2026-09-24"),
  }
  inspect(validation_message(input), content="ok: Clean the bath")
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
}

///|
test "parse_days" {
  assert_eq(@core.parse_days(" 14 "), Some(14))
  assert_eq(@core.parse_days(""), None)
  assert_eq(@core.parse_days("-1"), None)
  assert_eq(@core.parse_days("1.5"), None)
  assert_eq(@core.parse_days("999999"), None)
}
