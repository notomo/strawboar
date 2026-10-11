///|
fn plural(count : Int, unit : String) -> String {
  if count == 1 {
    "1 \{unit}"
  } else {
    "\{count} \{unit}s"
  }
}

///|
fn interval_text(repeat : @core.Repeat) -> String {
  match repeat {
    AfterDone(1) => "daily"
    AfterDone(7) => "weekly"
    AfterDone(days) => "every \{plural(days, "day")}"
    Monthly({ months: 1, day, .. }) => "monthly on the \{ordinal(day)}"
    Monthly({ months, day, .. }) =>
      "every \{months} months on the \{ordinal(day)}"
  }
}

///|
/// e.g. `1st`, `22nd`
fn ordinal(n : Int) -> String {
  let suffix = match (n % 100, n % 10) {
    (11..=13, _) => "th"
    (_, 1) => "st"
    (_, 2) => "nd"
    (_, 3) => "rd"
    _ => "th"
  }
  "\{n}\{suffix}"
}

///|
fn last_done_text(last_done : @core.Date?, today : @core.Date) -> String {
  match last_done {
    None => "not done yet"
    Some(date) =>
      match date.days_until(today) {
        0 => "done today"
        1 => "done yesterday"
        days => "done \{plural(days, "day")} ago"
      }
  }
}

///|
/// e.g. `10/03`
fn short_date(date : @core.Date) -> String {
  let (_, month, day) = date.ymd()
  let pad = (n : Int) => if n < 10 { "0\{n}" } else { n.to_string() }
  "\{pad(month)}/\{pad(day)}"
}

///|
/// e.g. `Thu, 09/24`
fn long_date(date : @core.Date) -> String {
  "\{date.weekday().label()}, \{short_date(date)}"
}

///|
/// The status following the interval in a due chore row.
fn chore_status(chore : @core.Chore, today : @core.Date) -> String {
  let due = match chore.days_left(today) {
    left if left > 0 => " · due in \{plural(left, "day")}"
    _ => ""
  }
  "\{last_done_text(chore.last_done, today)}\{due}"
}

///|
fn history_text(dates : Array[@core.Date]) -> String {
  if dates.is_empty() {
    "Not done yet."
  } else {
    dates.map(short_date).join(" · ")
  }
}
