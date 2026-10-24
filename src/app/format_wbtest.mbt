///|
fn test_date(s : String) -> @core.Date {
  @core.Date::parse(s) catch {
    _ => abort("invalid date: \{s}")
  }
}

///|
test "chore_status" {
  let today = test_date("2026-09-24")
  let chore : @core.Chore = {
    id: 1,
    title: "Bath",
    description: "",
    repeat: AfterDone(7),
    next_due: test_date("2026-09-22"),
    last_done: Some(test_date("2026-09-15")),
    labels: [],
  }
  inspect(chore_status(chore, today), content="done 9 days ago")
  inspect(
    chore_status(
      {
        ..chore,
        repeat: AfterDone(10),
        next_due: test_date("2026-09-25"),
        last_done: None,
      },
      today,
    ),
    content="not done yet · due in 1 day",
  )
  inspect(
    chore_status(
      { ..chore, repeat: AfterDone(1), last_done: Some(today), },
      today,
    ),
    content="done today",
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
