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
fn month_label(month : Int) -> String {
  match month {
    1 => "Jan"
    2 => "Feb"
    3 => "Mar"
    4 => "Apr"
    5 => "May"
    6 => "Jun"
    7 => "Jul"
    8 => "Aug"
    9 => "Sep"
    10 => "Oct"
    11 => "Nov"
    _ => "Dec"
  }
}

///|
/// e.g. `Oct 3`
fn short_date(date : @core.Date) -> String {
  let (_, month, day) = date.ymd()
  "\{month_label(month)} \{day}"
}

///|
/// e.g. `Thu, Sep 24`
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
/// e.g. `Vacuum ×2 · Clean bath`, in order of the latest completion.
fn recent_text(recent : Array[@core.RecentDone]) -> String {
  let titles : Array[String] = []
  let counts : Map[String, Int] = Map([])
  recent.each(done => {
    match counts.get(done.title) {
      Some(count) => counts[done.title] = count + 1
      None => {
        titles.push(done.title)
        counts[done.title] = 1
      }
    }
  })
  titles
  .map(title => {
    match counts.get(title) {
      Some(count) if count > 1 => "\{title} ×\{count}"
      _ => title
    }
  })
  .join(" · ")
}

///|
fn history_text(dates : Array[@core.Date]) -> String {
  if dates.is_empty() {
    "Not done yet."
  } else {
    dates.map(short_date).join(" · ")
  }
}
