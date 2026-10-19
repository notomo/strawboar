///|
/// A recurring chore. See `Repeat` for when it is due again.
pub(all) struct Chore {
  id : Int32
  title : String
  /// Free notes such as the steps, possibly multiple lines. Empty if none.
  description : String
  repeat : Repeat
  next_due : Date
  last_done : Date?
  /// Label ids.
  labels : Array[Int32]
} derive(Eq)

///|
pub extend Chore with Eq::{equal, not_equal}

///|
/// How pressing a chore is. Overdue chores are simply `Soon`; they never pile up.
pub(all) enum Urgency {
  Soon
  Later
} derive(Eq)

///|
pub extend Urgency with Eq::{equal, not_equal}

///|
pub fn Chore::days_left(self : Chore, today : Date) -> Int32 {
  today.days_until(self.next_due)
}

///|
/// `Soon` covers the last 20% of the interval (at least one day for long
/// intervals), or the lead days of a monthly chore, and anything overdue.
pub fn Chore::urgency(self : Chore, today : Date) -> Urgency {
  let days_left = self.days_left(today)
  let soon = match self.repeat {
    AfterDone(days) => days_left * 5 <= days
    Monthly({ lead_days, .. }) => days_left <= lead_days
  }
  match soon {
    true => Soon
    false => Later
  }
}

///|
/// Orders by elapsed fraction of the interval, most elapsed first.
fn Chore::compare_progress(self : Chore, other : Chore, today : Date) -> Int32 {
  // (interval - left) / interval, compared without division
  let (self_days, other_days) = (
    self.repeat.approx_days(),
    other.repeat.approx_days(),
  )
  let a = (self_days - self.days_left(today)) * other_days
  let b = (other_days - other.days_left(today)) * self_days
  match b.compare(a) {
    0 => self.title.compare(other.title)
    order => order
  }
}

///|
/// Returns the chore after being done on `today`. A monthly chore moves to its
/// next due date even when done late or early, so that none is skipped.
pub fn Chore::complete(self : Chore, today : Date) -> Chore {
  {
    ..self,
    last_done: Some(today),
    next_due: match self.repeat {
      AfterDone(days) => today.add_days(days)
      Monthly({ months, day, .. }) => self.next_due.add_months(months, day~)
    },
  }
}

///|
/// Returns the chore with the edited fields, so that a new interval applies
/// right away. Once done, it is due `days` after the last completion; a chore
/// never done keeps its due date. A monthly chore is due on its day in the
/// month it is due.
pub fn Chore::edit(self : Chore, input : ChoreInput) -> Chore {
  {
    ..self,
    title: input.title,
    description: input.description,
    repeat: input.repeat,
    labels: input.labels,
    next_due: match (input.repeat, self.last_done) {
      (AfterDone(days), Some(last_done)) => last_done.add_days(days)
      (AfterDone(_), None) => self.next_due
      (Monthly(_), _) => input.repeat.align(self.next_due)
    },
  }
}

///|
pub fn Chore::has_label(self : Chore, id : Int32) -> Bool {
  self.labels.contains(id)
}

///|
/// The labels of the chore, in the order of `labels`.
pub fn Chore::labels_in(self : Chore, labels : Array[Label]) -> Array[Label] {
  labels.filter(label => self.has_label(label.id))
}

///|
pub(all) struct Dashboard {
  soon : Array[Chore]
  later : Array[Chore]
}

///|
/// Monthly chores come first, as they are of a different nature.
fn Chore::compare_kind(self : Chore, other : Chore) -> Int32 {
  let rank = (chore : Chore) => {
    match chore.repeat {
      Monthly(_) => 0
      AfterDone(_) => 1
    }
  }
  rank(self).compare(rank(other))
}

///|
/// Each section puts monthly chores first. Soon chores are then ordered by
/// progress, so overdue ones come first, and later chores by due date.
pub fn Dashboard::new(chores : Array[Chore], today : Date) -> Dashboard {
  let then_by = (a : Chore, b : Chore, compare : (Chore, Chore) -> Int32) => {
    match a.compare_kind(b) {
      0 => compare(a, b)
      order => order
    }
  }
  let by_progress = (a : Chore, b : Chore) => {
    then_by(a, b, (a, b) => a.compare_progress(b, today))
  }
  let pick = (urgency : Urgency) => {
    chores.filter(chore => chore.urgency(today) == urgency)
  }
  let soon = pick(Soon)
  soon.sort_by(by_progress)
  let later = pick(Later)
  later.sort_by((a, b) => {
    then_by(a, b, (a, b) => {
      match a.next_due.compare(b.next_due) {
        0 => a.title.compare(b.title)
        order => order
      }
    })
  })
  { soon, later, }
}

///|
/// The latest due date among the soon chores.
pub fn Dashboard::soon_until(self : Dashboard) -> Date? {
  self.soon.iter().map(chore => chore.next_due).maximum()
}

///|
pub impl ToJson for Chore with fn to_json(self) {
  let (repeat_key, repeat_value) = self.repeat.json_field()
  let json : Map[String, Json] = {
    "id": Json(self.id),
    "title": Json(self.title),
    "description": Json(self.description),
  }
  json[repeat_key] = repeat_value
  json["next_due"] = self.next_due.to_json()
  json["last_done"] = match self.last_done {
    Some(date) => date.to_json()
    None => Json::null()
  }
  json["labels"] = Json(self.labels)
  Json::object(json)
}

///|
pub impl @json.FromJson for Chore with fn from_json(json, path) {
  guard json
    is {
      "id": Number(id, ..),
      "title": String(title),
      "next_due": next_due,
      "last_done": last_done,
      "labels": labels,
      ..
    } else {
    raise @json.JsonDecodeError((path, "invalid chore"))
  }
  {
    id: id.to_int(),
    title,
    description: read_description(json, path),
    repeat: Repeat::read_json(json, path),
    next_due: @json.from_json(next_due, path=path.add_key("next_due")),
    last_done: match last_done {
      Null => None
      date => Some(@json.from_json(date, path=path.add_key("last_done")))
    },
    labels: @json.from_json(labels, path=path.add_key("labels")),
  }
}

///|
pub extend Chore with ToJson::{to_json}

///|
pub extend Chore with @json.FromJson::{from_json}
