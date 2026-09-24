///|
/// Response of `GET /api/summary`.
pub(all) struct Summary {
  email : String
  chore_count : Int
} derive(Eq, ToJson, FromJson)

///|
pub extend Summary with Eq::{equal, not_equal}

///|
pub extend Summary with ToJson::{to_json}

///|
pub extend Summary with @json.FromJson::{from_json}
