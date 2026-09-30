///|
/// Maximum number of chores in one import.
pub const MAX_IMPORT_CHORES : Int = 200

///|
/// Chore definitions to export, as edited by a user and accepted by the import.
pub fn export_definitions(chores : Array[Chore]) -> Array[ChoreInput] {
  chores.map(chore => {
    title: chore.title,
    interval_days: chore.interval_days,
    next_due: Some(chore.next_due),
    labels: chore.labels,
  })
}

///|
pub fn export_text(chores : Array[Chore]) -> String {
  export_definitions(chores).to_json().stringify(indent=2)
}

///|
/// Parses exported text, e.g. typed into a text area.
pub fn parse_definitions(
  text : String,
) -> Array[ChoreInput] raise ValidationError {
  let json = @json.parse(text) catch {
    _ => raise ValidationError("Invalid JSON.")
  }
  guard json is Array(items) else {
    raise ValidationError("Chores must be a JSON array.")
  }
  items.mapi((i, item) => {
    let input : ChoreInput = @json.from_json(item) catch {
      _ =>
        raise ValidationError(
          "Chore #\{i + 1}: title, interval_days and labels are required.",
        )
    }
    input
  })
}

///|
/// What an import does. Chores are matched by title: an existing chore is
/// edited, and others are added. Chores not in the import are kept.
pub(all) struct ImportPlan {
  updates : Array[Chore]
  /// New chores with their first due date.
  creates : Array[(ChoreInput, Date)]
}

///|
/// A new chore without `next_due` is due `today`. Existing chores keep their
/// schedule like when edited, so their `next_due` is ignored.
pub fn ImportPlan::new(
  existing : Array[Chore],
  inputs : Array[ChoreInput],
  today : Date,
) -> ImportPlan raise ValidationError {
  guard inputs.length() <= MAX_IMPORT_CHORES else {
    raise ValidationError(
      "At most \{MAX_IMPORT_CHORES} chores can be imported at once.",
    )
  }
  let inputs = inputs.mapi((i, input) => {
    input.validate() catch {
      ValidationError(message) =>
        raise ValidationError("Chore #\{i + 1}: \{message}")
    }
  })
  inputs.eachi((i, input) => {
    if inputs[:i].iter().any(other => other.title == input.title) {
      raise ValidationError("Duplicate title: \{input.title}")
    }
  })
  let updates = []
  let creates = []
  inputs.each(input => {
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
