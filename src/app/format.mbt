///|
fn plural(count : Int, unit : String) -> String {
  if count == 1 {
    "1 \{unit}"
  } else {
    "\{count} \{unit}s"
  }
}

///|
fn interval_text(days : Int) -> String {
  match days {
    1 => "daily"
    7 => "weekly"
    _ => "every \{plural(days, "day")}"
  }
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
fn chore_meta(chore : @core.Chore, today : @core.Date) -> String {
  let due = match chore.days_left(today) {
    left if left > 0 => " · due in \{plural(left, "day")}"
    _ => ""
  }
  "\{interval_text(chore.interval_days)} · \{last_done_text(chore.last_done, today)}\{due}"
}

///|
fn history_text(dates : Array[@core.Date]) -> String {
  if dates.is_empty() {
    "Not done yet."
  } else {
    dates.map(short_date).join(" · ")
  }
}
