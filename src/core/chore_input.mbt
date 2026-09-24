///|
/// Fields a user can edit on a chore.
pub(all) struct ChoreInput {
  title : String
  interval_days : Int
  next_due : Date
} derive(ToJson, FromJson)

///|
pub extend ChoreInput with ToJson::{to_json}

///|
pub extend ChoreInput with @json.FromJson::{from_json}

///|
pub const MAX_TITLE_LENGTH : Int = 100

///|
pub const MAX_INTERVAL_DAYS : Int = 3650

///|
pub(all) suberror ValidationError {
  ValidationError(String)
}

///|
/// Returns the input with a trimmed title, or raises a user-facing message.
pub fn ChoreInput::validate(
  self : ChoreInput,
) -> ChoreInput raise ValidationError {
  let title = self.title.trim().to_owned()
  guard title != "" else { raise ValidationError("Title is required.") }
  guard title.length() <= MAX_TITLE_LENGTH else {
    raise ValidationError(
      "Title must be at most \{MAX_TITLE_LENGTH} characters.",
    )
  }
  guard self.interval_days is (1..=MAX_INTERVAL_DAYS) else {
    raise ValidationError(
      "Interval must be between 1 and \{MAX_INTERVAL_DAYS} days.",
    )
  }
  { ..self, title, }
}

///|
/// Parses a positive day count typed by a user.
pub fn parse_days(input : String) -> Int? {
  let input = input.trim()
  guard input != "" &&
    input.iter().all(c => c is ('0'..='9')) &&
    input.length() <= 5 else {
    return None
  }
  try @string.parse_int(input) catch {
    _ => None
  } noraise {
    days => Some(days)
  }
}
