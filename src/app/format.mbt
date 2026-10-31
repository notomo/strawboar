///|
/// Short, e.g. `14d` or `monthly 5th`, because every row shows one.
/// The panel has the full settings.
fn interval_text(repeat : @core.Repeat) -> String {
  match repeat {
    AfterDone(1) => "daily"
    AfterDone(7) => "weekly"
    AfterDone(days) => "\{days}d"
    Monthly({ months: 1, day, .. }) => "monthly \{ordinal(day)}"
    Monthly({ months, day, .. }) => "\{months}mo \{ordinal(day)}"
  }
}

///|
/// e.g. `1st`, `22nd`
fn ordinal(n : Int32) -> String {
  let suffix = match (n % 100, n % 10) {
    (11..<=13, _) => "th"
    (_, 1) => "st"
    (_, 2) => "nd"
    (_, 3) => "rd"
    _ => "th"
  }
  "\{n}\{suffix}"
}

///|
/// Short like `interval_text`, e.g. `21d ago`.
fn last_done_text(last_done : @core.Date?, today : @core.Date) -> String {
  match last_done {
    None => "never"
    Some(date) =>
      match date.days_until(today) {
        0 => "today"
        1 => "yesterday"
        days => "\{days}d ago"
      }
  }
}

///|
/// e.g. `10/03`
fn short_date(date : @core.Date) -> String {
  let (_, month, day) = date.ymd()
  let pad = (n : Int32) => if n < 10 { "0\{n}" } else { n.to_string() }
  "\{pad(month)}/\{pad(day)}"
}

///|
/// e.g. `2026-09-24 (Thu)`
fn long_date(date : @core.Date) -> String {
  "\{date} (\{date.weekday().label()})"
}

///|
/// Splits a text into words, marking the ones with a digit, e.g. `14`, `5th` or
/// `10/03`, so that they can be emphasized.
fn number_words(text : String) -> Array[(String, Bool)] {
  text
  .split(" ")
  .map(word => (word.to_owned(), word.iter().any(c => c is ('0'..<='9'))))
  .collect()
}
