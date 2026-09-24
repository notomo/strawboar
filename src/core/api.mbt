///|
/// Response of `GET /api/chores`.
pub(all) struct ChoreList {
  today : Date
  chores : Array[Chore]
  /// Completions of the last `RECENT_DAYS` days, newest first.
  recent : Array[RecentDone]
} derive(Eq, ToJson, FromJson)

///|
pub const RECENT_DAYS : Int = 7

///|
pub(all) struct RecentDone {
  completion_id : Int
  title : String
  done_on : Date
} derive(Eq, ToJson, FromJson)

///|
pub extend RecentDone with Eq::{equal, not_equal}

///|
pub extend RecentDone with ToJson::{to_json}

///|
pub extend RecentDone with @json.FromJson::{from_json}

///|
/// Response of `GET /api/chores/:id/completions`, newest first.
pub(all) struct History {
  dates : Array[Date]
} derive(Eq, ToJson, FromJson)

///|
pub extend History with Eq::{equal, not_equal}

///|
pub extend History with ToJson::{to_json}

///|
pub extend History with @json.FromJson::{from_json}

///|
pub extend ChoreList with Eq::{equal, not_equal}

///|
pub extend ChoreList with ToJson::{to_json}

///|
pub extend ChoreList with @json.FromJson::{from_json}

///|
/// Response of `POST /api/chores/:id/complete`.
pub(all) struct Completed {
  chore : Chore
  completion_id : Int
} derive(ToJson, FromJson)

///|
pub extend Completed with ToJson::{to_json}

///|
pub extend Completed with @json.FromJson::{from_json}

///|
/// Request body of `POST /api/chores/:id/postpone`.
pub(all) struct Postpone {
  days : Int
} derive(ToJson, FromJson)

///|
pub extend Postpone with ToJson::{to_json}

///|
pub extend Postpone with @json.FromJson::{from_json}
