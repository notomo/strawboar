///|
fn decode(row : String) -> String {
  try decode_chore(@json.parse(row)) catch {
    InternalError(message) => "error: \{message}"
    error => "error: \{error}"
  } noraise {
    chore => chore.to_json().stringify()
  }
}

///|
test "decode_chore" {
  inspect(
    decode(
      (
        #|{"id":1,"title":"Bath","description":"","interval_days":7,"monthly_months":null,"monthly_day":null,"monthly_lead_days":null,"next_due":"2026-10-01","last_done":null,"labels":"[2,1]"}
      ),
    ),
    content=(
      #|{"id":1,"title":"Bath","description":"","interval_days":7,"next_due":"2026-10-01","last_done":null,"labels":[2,1]}
    ),
  )
  // A monthly chore has the `monthly_*` columns, and `interval_days` is approximate.
  inspect(
    decode(
      (
        #|{"id":2,"title":"Rent","description":"Transfer.","interval_days":30,"monthly_months":1,"monthly_day":27,"monthly_lead_days":21,"next_due":"2026-10-27","last_done":"2026-09-27","labels":"[]"}
      ),
    ),
    content=(
      #|{"id":2,"title":"Rent","description":"Transfer.","monthly":{"months":1,"day":27,"lead_days":21},"next_due":"2026-10-27","last_done":"2026-09-27","labels":[]}
    ),
  )
}

///|
test "decode_chore errors" {
  inspect(
    decode(
      (
        #|{"id":1,"title":"Bath","interval_days":7,"next_due":"2026-10-01","last_done":null}
      ),
    ),
    content="error: invalid chore row: labels",
  )
  inspect(
    decode(
      (
        #|{"id":1,"title":"Bath","interval_days":7,"next_due":"2026-10-01","last_done":null,"labels":"[1,"}
      ),
    ),
    content=(
      #|error: invalid chore labels: Unexpected end of file
    ),
  )
}

///|
test "repeat_params" {
  let show = (repeat : @core.Repeat) => {
    repeat_params(repeat).map(param => {
      match param {
        Text(value) => value
        Integer(value) => value.to_string()
        Null => "null"
      }
    })
  }
  assert_eq(show(AfterDone(7)), ["7", "null", "null", "null"])
  let monthly : @core.Repeat = Monthly({ months: 2, day: 27, lead_days: 21, })
  assert_eq(show(monthly), [monthly.approx_days().to_string(), "2", "27", "21"])
}
