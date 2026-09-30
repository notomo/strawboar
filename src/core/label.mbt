///|
/// Colors a label can have. The palette is fixed so that every label stays
/// readable on the dark theme.
pub(all) enum LabelColor {
  Gray
  Red
  Orange
  Yellow
  Green
  Teal
  Blue
  Purple
  Pink
} derive(Eq)

///|
pub extend LabelColor with Eq::{equal, not_equal}

///|
pub let label_colors : Array[LabelColor] = [
  Gray,
  Red,
  Orange,
  Yellow,
  Green,
  Teal,
  Blue,
  Purple,
  Pink,
]

///|
pub fn LabelColor::name(self : LabelColor) -> String {
  match self {
    Gray => "gray"
    Red => "red"
    Orange => "orange"
    Yellow => "yellow"
    Green => "green"
    Teal => "teal"
    Blue => "blue"
    Purple => "purple"
    Pink => "pink"
  }
}

///|
pub fn LabelColor::parse(name : String) -> LabelColor? {
  label_colors.iter().find_first(color => color.name() == name)
}

///|
pub impl ToJson for LabelColor with fn to_json(self) {
  self.name().to_json()
}

///|
pub impl @json.FromJson for LabelColor with fn from_json(json, path) {
  guard json is String(name) && LabelColor::parse(name) is Some(color) else {
    raise @json.JsonDecodeError((path, "invalid label color"))
  }
  color
}

///|
pub extend LabelColor with ToJson::{to_json}

///|
pub extend LabelColor with @json.FromJson::{from_json}

///|
/// A label created beforehand and shared by chores.
pub(all) struct Label {
  id : Int
  name : String
  color : LabelColor
} derive(Eq, ToJson, FromJson)

///|
pub extend Label with Eq::{equal, not_equal}

///|
pub extend Label with ToJson::{to_json}

///|
pub extend Label with @json.FromJson::{from_json}

///|
/// Fields a user can edit on a label.
pub(all) struct LabelInput {
  name : String
  color : LabelColor
} derive(Eq, ToJson, FromJson)

///|
pub extend LabelInput with Eq::{equal, not_equal}

///|
pub extend LabelInput with ToJson::{to_json}

///|
pub extend LabelInput with @json.FromJson::{from_json}

///|
pub const MAX_LABEL_LENGTH : Int = 30

///|
/// Returns the input with a trimmed name, or raises a user-facing message.
/// The name must differ from the other `labels`; `id` is the label being edited.
pub fn LabelInput::validate(
  self : LabelInput,
  labels : Array[Label],
  id? : Int,
) -> LabelInput raise ValidationError {
  let name = self.name.trim().to_owned()
  guard name != "" else { raise ValidationError("Name is required.") }
  guard name.length() <= MAX_LABEL_LENGTH else {
    raise ValidationError(
      "Name must be at most \{MAX_LABEL_LENGTH} characters.",
    )
  }
  guard !labels.iter().any(label => label.name == name && Some(label.id) != id) else {
    raise ValidationError("A label named \{name} already exists.")
  }
  { ..self, name, }
}

///|
/// Returns the labels with the label added or replaced, sorted by name.
pub fn upsert_label(labels : Array[Label], label : Label) -> Array[Label] {
  let labels = [..labels.filter(l => l.id != label.id), label]
  labels.sort_by((a, b) => a.name.lexical_compare(b.name))
  labels
}
