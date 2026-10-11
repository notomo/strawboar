///|
/// A chore due on a fixed day of the month, e.g. paying the rent.
pub(all) struct Monthly {
  /// Due every `months` months.
  months : Int
  /// Day of the month. A day the month does not have means its last day.
  day : Int
  /// The chore is `Soon` from this many days before it is due.
  lead_days : Int
} derive(Eq, ToJson, FromJson)

///|
pub extend Monthly with Eq::{equal, not_equal}

///|
pub extend Monthly with ToJson::{to_json}

///|
pub extend Monthly with @json.FromJson::{from_json}

///|
/// How a chore recurs.
pub(all) enum Repeat {
  /// Due this many days after it was done.
  AfterDone(Int)
  /// Due on a fixed day, whenever it was done.
  Monthly(Monthly)
} derive(Eq)

///|
pub extend Repeat with Eq::{equal, not_equal}

///|
pub const MAX_INTERVAL_MONTHS : Int = 120

///|
/// The approximate number of days between due dates.
pub fn Repeat::approx_days(self : Repeat) -> Int {
  match self {
    AfterDone(days) => days
    Monthly({ months, .. }) => months * 30
  }
}

///|
/// The due date in the month of `date` for a monthly chore, otherwise `date`.
pub fn Repeat::align(self : Repeat, date : Date) -> Date {
  match self {
    AfterDone(_) => date
    Monthly({ day, .. }) => date.add_months(0, day~)
  }
}

///|
/// The field of a chore JSON object: `interval_days` or `monthly`.
fn Repeat::json_field(self : Repeat) -> (String, Json) {
  match self {
    AfterDone(days) => ("interval_days", days.to_json())
    Monthly(monthly) => ("monthly", monthly.to_json())
  }
}

///|
/// Reads the repeat of a chore JSON object. `monthly` takes precedence.
fn Repeat::read_json(
  json : Json,
  path : @json.JsonPath,
) -> Repeat raise @json.JsonDecodeError {
  match json {
    { "monthly": Object(_) as monthly, .. } =>
      Monthly(@json.from_json(monthly, path=path.add_key("monthly")))
    { "interval_days": Number(days, ..), .. } => AfterDone(days.to_int())
    _ =>
      raise @json.JsonDecodeError(
        (path, "interval_days or monthly is required"),
      )
  }
}

///|
fn Repeat::validate(self : Repeat) -> Unit raise ValidationError {
  match self {
    AfterDone(days) => validate_interval(days)
    Monthly({ months, day, lead_days, }) => {
      guard months is (1..=MAX_INTERVAL_MONTHS) else {
        raise ValidationError(
          "Months must be between 1 and \{MAX_INTERVAL_MONTHS}.",
        )
      }
      guard day is (1..=31) else {
        raise ValidationError("Day must be between 1 and 31.")
      }
      // Shorter than the shortest interval, so that it is not always soon.
      let max_lead_days = months * 28 - 1
      guard lead_days >= 0 && lead_days <= max_lead_days else {
        raise ValidationError(
          "Lead days must be between 0 and \{max_lead_days}.",
        )
      }
    }
  }
}
