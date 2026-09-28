///|
/// Fields a user can edit on a chore. `next_due` is the first due date and is
/// only used when creating a chore; afterwards it follows the completions.
pub(all) struct ChoreInput {
  title : String
  interval_days : Int
  next_due : Date?
  labels : Array[String]
}

///|
pub impl ToJson for ChoreInput with fn to_json(self) {
  let json : Map[String, Json] = {
    "title": self.title.to_json(),
    "interval_days": self.interval_days.to_json(),
    "labels": self.labels.to_json(),
  }
  if self.next_due is Some(next_due) {
    json["next_due"] = next_due.to_json()
  }
  Json::object(json)
}

///|
pub impl @json.FromJson for ChoreInput with fn from_json(json, path) {
  guard json
    is {
      "title": String(title),
      "interval_days": Number(interval_days, ..),
      "labels": labels,
      ..
    } else {
    raise @json.JsonDecodeError((path, "invalid chore input"))
  }
  {
    title,
    interval_days: interval_days.to_int(),
    next_due: match json {
      { "next_due": Null, .. } => None
      { "next_due": next_due, .. } =>
        Some(@json.from_json(next_due, path=path.add_key("next_due")))
      _ => None
    },
    labels: @json.from_json(labels, path=path.add_key("labels")),
  }
}

///|
pub extend ChoreInput with ToJson::{to_json}

///|
pub extend ChoreInput with @json.FromJson::{from_json}

///|
pub const MAX_TITLE_LENGTH : Int = 100

///|
pub const MAX_INTERVAL_DAYS : Int = 3650

///|
pub const MAX_LABEL_LENGTH : Int = 30

///|
pub const MAX_LABELS : Int = 10

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
  let labels = normalize_labels(self.labels)
  guard labels.iter().all(label => label.length() <= MAX_LABEL_LENGTH) else {
    raise ValidationError(
      "Each label must be at most \{MAX_LABEL_LENGTH} characters.",
    )
  }
  guard labels.length() <= MAX_LABELS else {
    raise ValidationError("A chore can have at most \{MAX_LABELS} labels.")
  }
  { ..self, title, labels, }
}

///|
/// Trims labels and drops empty and duplicate ones, keeping the first order.
fn normalize_labels(labels : Array[String]) -> Array[String] {
  labels
  .map(label => label.trim().to_owned())
  .filter(label => label != "")
  .fold(init=[], (acc, label) => {
    if acc.contains(label) {
      acc
    } else {
      [..acc, label]
    }
  })
}

///|
/// Parses comma-separated labels typed by a user.
pub fn parse_labels(input : String) -> Array[String] {
  normalize_labels(input.split(",").map(label => label.to_owned()).collect())
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
