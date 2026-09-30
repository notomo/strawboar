///|
/// Maximum number of chores in one import.
pub const MAX_IMPORT_CHORES : Int = 200

///|
/// Maximum number of labels in one import.
pub const MAX_IMPORT_LABELS : Int = 100

///|
/// A chore as exported and imported. Unlike `ChoreInput`, labels are referred
/// to by name so that the text can be edited by hand.
pub(all) struct ChoreDefinition {
  title : String
  interval_days : Int
  next_due : Date?
  /// Label names.
  labels : Array[String]
}

///|
pub impl ToJson for ChoreDefinition with fn to_json(self) {
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
pub impl @json.FromJson for ChoreDefinition with fn from_json(json, path) {
  guard json
    is {
      "title": String(title),
      "interval_days": Number(interval_days, ..),
      "labels": labels,
      ..
    } else {
    raise @json.JsonDecodeError((path, "invalid chore definition"))
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
pub extend ChoreDefinition with ToJson::{to_json}

///|
pub extend ChoreDefinition with @json.FromJson::{from_json}

///|
/// Returns the definition with a trimmed title and without duplicate labels,
/// or raises a user-facing message. Every label must be one of `label_names`.
fn ChoreDefinition::validate(
  self : ChoreDefinition,
  label_names : Array[String],
) -> ChoreDefinition raise ValidationError {
  let title = validate_title(self.title)
  validate_interval(self.interval_days)
  let labels = validate_labels(self.labels)
  labels.each(name => {
    guard label_names.contains(name) else {
      raise ValidationError("Unknown label: \{name}")
    }
  })
  { ..self, title, labels, }
}

///|
/// Labels and chores exchanged as JSON text.
pub(all) struct Definitions {
  labels : Array[LabelInput]
  chores : Array[ChoreDefinition]
} derive(ToJson)

///|
pub extend Definitions with ToJson::{to_json}

///|
/// Definitions to export, as edited by a user and accepted by the import.
pub fn export_definitions(
  labels : Array[Label],
  chores : Array[Chore],
) -> Definitions {
  {
    labels: labels.map(label => { name: label.name, color: label.color, }),
    chores: chores.map(chore => {
      title: chore.title,
      interval_days: chore.interval_days,
      next_due: Some(chore.next_due),
      labels: chore.labels_in(labels).map(label => label.name),
    }),
  }
}

///|
pub fn export_text(labels : Array[Label], chores : Array[Chore]) -> String {
  export_definitions(labels, chores).to_json().stringify(indent=2)
}

///|
/// Parses exported text, e.g. typed into a text area.
pub fn parse_definitions(text : String) -> Definitions raise ValidationError {
  let json = @json.parse(text) catch {
    _ => raise ValidationError("Invalid JSON.")
  }
  guard json is { "labels": Array(labels), "chores": Array(chores), .. } else {
    raise ValidationError(
      "Definitions must be a JSON object with labels and chores arrays.",
    )
  }
  {
    labels: labels.mapi((i, item) => {
      let input : LabelInput = @json.from_json(item) catch {
        _ =>
          raise ValidationError(
            "Label #\{i + 1}: name and a color (\{color_names()}) are required.",
          )
      }
      input
    }),
    chores: chores.mapi((i, item) => {
      let definition : ChoreDefinition = @json.from_json(item) catch {
        _ =>
          raise ValidationError(
            "Chore #\{i + 1}: title, interval_days and labels are required.",
          )
      }
      definition
    }),
  }
}

///|
fn color_names() -> String {
  label_colors.map(color => color.name()).join(", ")
}

///|
/// What an import does. Labels are matched by name and chores by title:
/// existing ones are edited, and others are added. Nothing is removed.
/// Labels are saved first, because chores refer to their ids
/// (see `ImportPlan::chore_changes`).
pub(all) struct ImportPlan {
  label_updates : Array[Label]
  label_creates : Array[LabelInput]
  /// Validated chores whose labels are all existing or imported.
  chores : Array[ChoreDefinition]
}

///|
pub fn ImportPlan::new(
  existing : Array[Label],
  definitions : Definitions,
) -> ImportPlan raise ValidationError {
  guard definitions.chores.length() <= MAX_IMPORT_CHORES else {
    raise ValidationError(
      "At most \{MAX_IMPORT_CHORES} chores can be imported at once.",
    )
  }
  guard definitions.labels.length() <= MAX_IMPORT_LABELS else {
    raise ValidationError(
      "At most \{MAX_IMPORT_LABELS} labels can be imported at once.",
    )
  }
  let labels = definitions.labels.mapi((i, input) => {
    // Duplicates within the import are checked below, so only the format is checked here.
    input.validate([]) catch {
      ValidationError(message) =>
        raise ValidationError("Label #\{i + 1}: \{message}")
    }
  })
  labels.eachi((i, input) => {
    if labels[:i].iter().any(other => other.name == input.name) {
      raise ValidationError("Duplicate label: \{input.name}")
    }
  })
  let label_names = [
    ..existing.map(label => label.name),
    ..labels.map(label => label.name),
  ]
  let chores = definitions.chores.mapi((i, definition) => {
    definition.validate(label_names) catch {
      ValidationError(message) =>
        raise ValidationError("Chore #\{i + 1}: \{message}")
    }
  })
  chores.eachi((i, definition) => {
    if chores[:i].iter().any(other => other.title == definition.title) {
      raise ValidationError("Duplicate title: \{definition.title}")
    }
  })
  let label_updates = []
  let label_creates = []
  labels.each(input => {
    match existing.iter().find_first(label => label.name == input.name) {
      Some(label) => label_updates.push({ ..label, color: input.color, })
      None => label_creates.push(input)
    }
  })
  { label_updates, label_creates, chores, }
}

///|
/// Changes to chores by an import.
pub(all) struct ChoreChanges {
  updates : Array[Chore]
  /// New chores with their first due date.
  creates : Array[(ChoreInput, Date)]
}

///|
/// Resolves the chores of the plan once its labels are saved. A new chore
/// without `next_due` is due `today`. Existing chores keep their schedule like
/// when edited, so their `next_due` is ignored.
pub fn ImportPlan::chore_changes(
  self : ImportPlan,
  existing : Array[Chore],
  labels : Array[Label],
  today : Date,
) -> ChoreChanges raise ValidationError {
  let updates = []
  let creates = []
  self.chores.each(definition => {
    let input : ChoreInput = {
      title: definition.title,
      interval_days: definition.interval_days,
      next_due: definition.next_due,
      labels: definition.labels.map(name => {
        match labels.iter().find_first(label => label.name == name) {
          Some(label) => label.id
          None => raise ValidationError("Unknown label: \{name}")
        }
      }),
    }
    match existing.iter().find_first(chore => chore.title == input.title) {
      Some(chore) => updates.push(chore.edit(input))
      None => creates.push((input, input.next_due.unwrap_or(today)))
    }
  })
  { updates, creates, }
}

///|
/// Response of `POST /api/chores/import`.
pub(all) struct ImportResult {
  created : Int
  updated : Int
} derive(Eq, ToJson, FromJson)

///|
pub extend ImportResult with Eq::{equal, not_equal}

///|
pub extend ImportResult with ToJson::{to_json}

///|
pub extend ImportResult with @json.FromJson::{from_json}
