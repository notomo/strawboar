///|
test "parse and format" {
  inspect(@core.Date::parse("2026-09-24"), content="2026-09-24")
  inspect(@core.Date::parse("2024-02-29"), content="2024-02-29")
  inspect(@core.Date::parse("0999-01-01"), content="0999-01-01")
}

///|
test "parse rejects invalid dates" {
  let invalid = [
    "", "2026-9-24", "2026/09/24", "2026-13-01", "2026-00-01", "2026-02-29", "2026-09-31",
    "2026-09-2x", "+026-09-24", "2026-09-24T00:00",
  ]
  for input in invalid {
    let parsed = try @core.Date::parse(input) catch {
      _ => None
    } noraise {
      date => Some(date)
    }
    assert_true(parsed is None, msg="\{input} should be invalid")
  }
}

///|
test "add_days and days_until across month and year boundaries" {
  let date = @core.Date::parse("2026-12-30")
  inspect(date.add_days(3), content="2027-01-02")
  inspect(date.add_days(-365), content="2025-12-30")
  inspect(@core.Date::parse("2024-02-28").add_days(1), content="2024-02-29")
  assert_eq(date.days_until(@core.Date::parse("2027-01-02")), 3)
  assert_eq(date.days_until(@core.Date::parse("2026-12-01")), -29)
}

///|
test "from_unix_seconds uses the given offset" {
  // 2026-09-23T15:00:00Z is 2026-09-24T00:00:00+09:00
  let seconds = 1790175600.0
  inspect(
    @core.Date::from_unix_seconds(seconds, offset_minutes=540),
    content="2026-09-24",
  )
  inspect(
    @core.Date::from_unix_seconds(seconds - 1, offset_minutes=540),
    content="2026-09-23",
  )
  inspect(
    @core.Date::from_unix_seconds(seconds, offset_minutes=0),
    content="2026-09-23",
  )
}

///|
test "weekday" {
  inspect(@core.Date::parse("2026-09-24").weekday().label(), content="Thu")
  inspect(@core.Date::parse("1970-01-01").weekday().label(), content="Thu")
  inspect(@core.Date::parse("1969-12-28").weekday().label(), content="Sun")
}

///|
test "json" {
  let date = @core.Date::parse("2026-09-24")
  inspect(date.to_json().stringify(), content="\"2026-09-24\"")
  let decoded : @core.Date = @json.from_json("2026-09-24".to_json())
  assert_true(decoded == date)
}
