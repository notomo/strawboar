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
    interval_days: 7,
    next_due: test_date("2026-09-22"),
    last_done: Some(test_date("2026-09-15")),
    labels: [],
  }
  inspect(chore_status(chore, today), content="done 9 days ago")
  inspect(
    chore_status(
      {
        ..chore,
        interval_days: 10,
        next_due: test_date("2026-09-25"),
        last_done: None,
      },
      today,
    ),
    content="not done yet · due in 1 day",
  )
  inspect(
    chore_status({ ..chore, interval_days: 1, last_done: Some(today), }, today),
    content="done today",
  )
}

///|
test "interval_text" {
  inspect(interval_text(1), content="daily")
  inspect(interval_text(7), content="weekly")
  inspect(interval_text(10), content="every 10 days")
}

///|
test "dates" {
  inspect(long_date(test_date("2026-09-24")), content="Thu, 09/24")
  inspect(short_date(test_date("2026-10-03")), content="10/03")
}

///|
test "history_text" {
  inspect(
    history_text([test_date("2026-09-24"), test_date("2026-09-17")]),
    content="09/24 · 09/17",
  )
  inspect(history_text([]), content="Not done yet.")
}
