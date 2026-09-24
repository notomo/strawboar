///|
/// A calendar date without time or time zone.
pub struct Date {
  priv days : Int // days since 1970-01-01
} derive(Eq, Compare)

///|
pub extend Date with Eq::{equal, not_equal}

///|
pub extend Date with Compare::{compare, op_lt, op_le, op_ge, op_gt}

///|
pub(all) suberror DateError {
  InvalidDate(String)
}

///|
/// Converts a civil date to days since 1970-01-01.
/// See http://howardhinnant.github.io/date_algorithms.html
fn days_from_civil(year : Int, month : Int, day : Int) -> Int {
  let y = if month <= 2 { year - 1 } else { year }
  let era = (if y >= 0 { y } else { y - 399 }) / 400
  let yoe = y - era * 400
  let mp = (month + 9) % 12
  let doy = (153 * mp + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468
}

///|
fn civil_from_days(days : Int) -> (Int, Int, Int) {
  let z = days + 719468
  let era = (if z >= 0 { z } else { z - 146096 }) / 146097
  let doe = z - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let day = doy - (153 * mp + 2) / 5 + 1
  let month = if mp < 10 { mp + 3 } else { mp - 9 }
  (if month <= 2 { y + 1 } else { y }, month, day)
}

///|
pub fn Date::from_ymd(
  year : Int,
  month : Int,
  day : Int,
) -> Date raise DateError {
  let date : Date = { days: days_from_civil(year, month, day), }
  guard month is (1..=12) && day >= 1 && date.ymd() == (year, month, day) else {
    raise InvalidDate("\{year}-\{month}-\{day}")
  }
  date
}

///|
/// Parses `YYYY-MM-DD`.
pub fn Date::parse(input : String) -> Date raise DateError {
  let chars = input.to_array()
  let well_formed = chars.length() == 10 &&
    chars
    .mapi((i, c) => if i == 4 || i == 7 { c == '-' } else { c is ('0'..='9') })
    .all(ok => ok)
  guard well_formed else { raise InvalidDate(input) }
  let digits = fn(start : Int, end : Int) raise DateError {
    @string.parse_int(input[start:end]) catch {
      _ => raise InvalidDate(input)
    }
  }
  Date::from_ymd(digits(0, 4), digits(5, 7), digits(8, 10))
}

///|
/// Returns the local date of a UNIX time with a fixed UTC offset.
pub fn Date::from_unix_seconds(seconds : Double, offset_minutes~ : Int) -> Date {
  let local_minutes = (seconds / 60).floor() + offset_minutes.to_double()
  { days: (local_minutes / 1440).floor().to_int(), }
}

///|
pub fn Date::ymd(self : Date) -> (Int, Int, Int) {
  civil_from_days(self.days)
}

///|
pub fn Date::add_days(self : Date, days : Int) -> Date {
  { days: self.days + days, }
}

///|
/// Number of days from `self` to `other` (negative if `other` is earlier).
pub fn Date::days_until(self : Date, other : Date) -> Int {
  other.days - self.days
}

///|
pub(all) enum Weekday {
  Sun
  Mon
  Tue
  Wed
  Thu
  Fri
  Sat
}

///|
pub fn Weekday::label(self : Weekday) -> String {
  match self {
    Sun => "Sun"
    Mon => "Mon"
    Tue => "Tue"
    Wed => "Wed"
    Thu => "Thu"
    Fri => "Fri"
    Sat => "Sat"
  }
}

///|
pub fn Date::weekday(self : Date) -> Weekday {
  // 1970-01-01 was a Thursday.
  match (self.days % 7 + 11) % 7 {
    0 => Sun
    1 => Mon
    2 => Tue
    3 => Wed
    4 => Thu
    5 => Fri
    _ => Sat
  }
}

///|
pub impl Show for Date with fn output(self, logger) {
  let (year, month, day) = self.ymd()
  let pad = fn(n : Int, width : Int) {
    let s = n.to_string()
    "0".repeat(width - s.length()) + s
  }
  logger.write_string("\{pad(year, 4)}-\{pad(month, 2)}-\{pad(day, 2)}")
}

///|
pub impl ToJson for Date with fn to_json(self) {
  self.to_string().to_json()
}

///|
pub impl @json.FromJson for Date with fn from_json(json, path) {
  guard json is String(s) else {
    raise @json.JsonDecodeError((path, "expected a date string"))
  }
  Date::parse(s) catch {
    _ => raise @json.JsonDecodeError((path, "invalid date: \{s}"))
  }
}

///|
pub extend Date with Show::{to_string, output}

///|
pub extend Date with ToJson::{to_json}

///|
pub extend Date with @json.FromJson::{from_json}
