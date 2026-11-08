///|
/// Response of `GET /api/chores`.
#derive(Eq, ToJson, FromJson)
pub(all) struct ChoreList {
  today : Date
  /// Sorted by name.
  labels : Array[Label]
  chores : Array[Chore]
  /// Completions of the last `RECENT_DAYS` days, newest first.
  recent : Array[RecentDone]
}

///|
pub const RECENT_DAYS : Int32 = 7

///|
#derive(Eq, ToJson, FromJson)
pub(all) struct RecentDone {
  completion_id : Int32
  chore_id : Int32
  title : String
  done_on : Date
}

///|
/// Only the latest completion of a chore can be undone, because undoing restores
/// the schedule from before it. `recent` must be newest first.
pub fn RecentDone::can_undo(
  self : RecentDone,
  recent : Array[RecentDone],
) -> Bool {
  recent.iter().find_first(r => r.chore_id == self.chore_id)
  is Some({ completion_id, .. }) &&
  completion_id == self.completion_id
}

///|
/// Completions of monthly chores come first, like the dashboard sections.
/// The order is kept otherwise. Archived chores are not in `chores` and count
/// as not monthly.
pub fn recent_monthly_first(
  recent : Array[RecentDone],
  chores : Array[Chore],
) -> Array[RecentDone] {
  let is_monthly = (done : RecentDone) => {
    chores.iter().find_first(chore => chore.id == done.chore_id)
    is Some({ repeat: Monthly(_), .. })
  }
  [..recent.filter(is_monthly), ..recent.filter(done => !is_monthly(done))]
}

///|
pub extend RecentDone with Eq::{equal, not_equal}

///|
pub extend RecentDone with ToJson::{to_json}

///|
pub extend RecentDone with @json.FromJson::{from_json}

///|
pub extend ChoreList with Eq::{equal, not_equal}

///|
pub extend ChoreList with ToJson::{to_json}

///|
pub extend ChoreList with @json.FromJson::{from_json}

///|
/// Response of `POST /api/chores/:id/complete`.
#derive(ToJson, FromJson)
pub(all) struct Completed {
  chore : Chore
  completion_id : Int32
}

///|
pub extend Completed with ToJson::{to_json}

///|
pub extend Completed with @json.FromJson::{from_json}
