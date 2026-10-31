///|
fn test_date(s : String) -> @core.Date {
  @core.Date::parse(s) catch {
    _ => abort("invalid date: \{s}")
  }
}

///|
test "last_done_text" {
  let today = test_date("2026-09-24")
  inspect(last_done_text(None, today), content="not done yet")
  inspect(last_done_text(Some(today), today), content="done today")
  inspect(
    last_done_text(Some(test_date("2026-09-23")), today),
    content="done yesterday",
  )
  inspect(
    last_done_text(Some(test_date("2026-09-15")), today),
    content="done 9 days ago",
  )
}

///|
test "interval_text" {
  inspect(interval_text(AfterDone(1)), content="daily")
  inspect(interval_text(AfterDone(7)), content="weekly")
  inspect(interval_text(AfterDone(10)), content="every 10 days")
  inspect(
    interval_text(Monthly({ months: 1, day: 28, lead_days: 7, })),
    content="monthly on the 28th",
  )
  inspect(
    interval_text(Monthly({ months: 3, day: 1, lead_days: 7, })),
    content="every 3 months on the 1st",
  )
}

///|
test "ordinal" {
  assert_eq([1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 31].map(ordinal), [
    "1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st", "22nd", "23rd", "31st",
  ])
}

///|
test "dates" {
  inspect(long_date(test_date("2026-09-24")), content="2026-09-24 (Thu)")
  inspect(short_date(test_date("2026-10-03")), content="10/03")
}

///|
test "recent_caption" {
  inspect(recent_caption(test_date("2026-10-03")), content="09/27 – 10/03")
}

///|
test "number_words" {
  assert_eq(number_words("done 9 days ago"), [
    ("done", false),
    ("9", true),
    ("days", false),
    ("ago", false),
  ])
  assert_eq(number_words("monthly on the 5th"), [
    ("monthly", false),
    ("on", false),
    ("the", false),
    ("5th", true),
  ])
  assert_eq(number_words("09/27 – 10/03"), [
    ("09/27", true),
    ("–", false),
    ("10/03", true),
  ])
}
