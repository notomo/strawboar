///|
/// Response of `GET /api/chores`.
pub(all) struct ChoreList {
  today : Date
  chores : Array[Chore]
} derive(Eq, ToJson, FromJson)

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
