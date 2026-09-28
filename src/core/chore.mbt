///|
/// A recurring chore. It is due again `interval_days` after it was done.
pub(all) struct Chore {
  id : Int
  title : String
  interval_days : Int
  next_due : Date
  last_done : Date?
  labels : Array[String]
} derive(Eq)

///|
pub extend Chore with Eq::{equal, not_equal}

///|
/// How pressing a chore is. Overdue chores are simply `Due`; they never pile up.
pub(all) enum Urgency {
  Due
  Soon
  Later
} derive(Eq)

///|
pub extend Urgency with Eq::{equal, not_equal}

///|
pub fn Chore::days_left(self : Chore, today : Date) -> Int {
  today.days_until(self.next_due)
}

///|
/// `Soon` covers the last 20% of the interval (at least one day for long intervals).
pub fn Chore::urgency(self : Chore, today : Date) -> Urgency {
  let days_left = self.days_left(today)
  if days_left <= 0 {
    Due
  } else if days_left * 5 <= self.interval_days {
    Soon
  } else {
    Later
  }
}

///|
/// Orders by elapsed fraction of the interval, most elapsed first.
fn Chore::compare_progress(self : Chore, other : Chore, today : Date) -> Int {
  // (interval - left) / interval, compared without division
  let a = (self.interval_days - self.days_left(today)) * other.interval_days
  let b = (other.interval_days - other.days_left(today)) * self.interval_days
  match b.compare(a) {
    0 => self.title.compare(other.title)
    order => order
  }
}

///|
/// Returns the chore after being done on `today`.
pub fn Chore::complete(self : Chore, today : Date) -> Chore {
  {
    ..self,
    last_done: Some(today),
    next_due: today.add_days(self.interval_days),
  }
}

///|
/// Returns the chore with the edited fields. Once done, it is due `interval_days`
/// after the last completion, so a new interval applies right away.
/// A chore never done keeps its due date.
pub fn Chore::edit(self : Chore, input : ChoreInput) -> Chore {
  {
    ..self,
    title: input.title,
    interval_days: input.interval_days,
    labels: input.labels,
    next_due: match self.last_done {
      Some(last_done) => last_done.add_days(input.interval_days)
      None => self.next_due
    },
  }
}

///|
pub fn Chore::has_label(self : Chore, label : String) -> Bool {
  self.labels.contains(label)
}

///|
/// Returns the labels used by any of the chores, sorted and without duplicates.
pub fn all_labels(chores : Array[Chore]) -> Array[String] {
  let labels = chores
    .iter()
    .flat_map(chore => chore.labels.iter())
    .fold(init=[], (acc, label) => {
      if acc.contains(label) {
        acc
      } else {
        [..acc, label]
      }
    })
  labels.sort_by(String::lexical_compare)
  labels
}

///|
pub(all) struct Dashboard {
  due : Array[Chore]
  soon : Array[Chore]
  later : Array[Chore]
}

///|
pub fn Dashboard::new(chores : Array[Chore], today : Date) -> Dashboard {
  let by_progress = (a : Chore, b : Chore) => a.compare_progress(b, today)
  let pick = (urgency : Urgency) => {
    chores.filter(chore => chore.urgency(today) == urgency)
  }
  let due = pick(Due)
  due.sort_by(by_progress)
  let soon = pick(Soon)
  soon.sort_by(by_progress)
  let later = pick(Later)
  later.sort_by((a, b) => {
    match a.next_due.compare(b.next_due) {
      0 => a.title.compare(b.title)
      order => order
    }
  })
  { due, soon, later, }
}

///|
pub impl ToJson for Chore with fn to_json(self) {
  {
    "id": self.id.to_json(),
    "title": self.title.to_json(),
    "interval_days": self.interval_days.to_json(),
    "next_due": self.next_due.to_json(),
    "last_done": match self.last_done {
      Some(date) => date.to_json()
      None => Json::null()
    },
    "labels": self.labels.to_json(),
  }
}

///|
pub impl @json.FromJson for Chore with fn from_json(json, path) {
  guard json
    is {
      "id": Number(id, ..),
      "title": String(title),
      "interval_days": Number(interval_days, ..),
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
    interval_days: interval_days.to_int(),
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
