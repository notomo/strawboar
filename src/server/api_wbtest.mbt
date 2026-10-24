///|
test "parse_id" {
  let parse = (segment : String) => {
    try parse_id(segment) catch {
      NotFound => "not found"
      _ => "other error"
    } noraise {
      id => id.to_string()
    }
  }
  inspect(parse("1"), content="1")
  inspect(parse("042"), content="42")
  inspect(parse("999999999"), content="999999999")
  // Ids beyond 9 digits could overflow Int32, so they are not found.
  inspect(parse("1000000000"), content="not found")
  inspect(parse(""), content="not found")
  inspect(parse("-1"), content="not found")
  inspect(parse("1a"), content="not found")
  // A full-width digit.
  inspect(parse("\u{FF11}"), content="not found")
}
