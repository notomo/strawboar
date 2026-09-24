///|
fn test_date(s : String) -> @core.Date {
  @core.Date::parse(s) catch {
    _ => abort("invalid date: \{s}")
  }
}

///|
test "chore_meta" {
  let today = test_date("2026-09-24")
  let chore : @core.Chore = {
    id: 1,
    title: "Bath",
    interval_days: 7,
    next_due: test_date("2026-09-22"),
    last_done: Some(test_date("2026-09-15")),
  }
  inspect(chore_meta(chore, today), content="weekly · done 9 days ago")
  inspect(
    chore_meta(
      {
        ..chore,
        interval_days: 10,
        next_due: test_date("2026-09-25"),
        last_done: None,
      },
      today,
    ),
    content="every 10 days · not done yet · due in 1 day",
  )
  inspect(
    chore_meta({ ..chore, interval_days: 1, last_done: Some(today), }, today),
    content="daily · done today",
  )
}

///|
test "dates" {
  inspect(long_date(test_date("2026-09-24")), content="Thu, Sep 24")
  inspect(short_date(test_date("2026-10-03")), content="Oct 3")
}

///|
test "history_text" {
  inspect(
    history_text([test_date("2026-09-24"), test_date("2026-09-17")]),
    content="Sep 24 · Sep 17",
  )
  inspect(history_text([]), content="Not done yet.")
}
