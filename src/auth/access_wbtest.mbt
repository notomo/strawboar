///|
let config : AccessConfig = {
  team_domain: "example.cloudflareaccess.com",
  audience: "aud1",
}

///|
fn claims(
  iss? : String = "https://example.cloudflareaccess.com",
  aud? : Json = ["aud1"],
  exp? : Double = 2000,
  email? : String = "me@example.com",
) -> Json {
  {
    "iss": iss.to_json(),
    "aud": aud,
    "exp": exp.to_json(),
    "email": email.to_json(),
  }
}

///|
fn validation_error(claims : Json, config? : AccessConfig = config) -> String {
  try validate_claims(claims, config, 1000) catch {
    AuthError(message) => message
  } noraise {
    _ => "ok"
  }
}

///|
test "validate_claims accepts valid claims" {
  let identity = validate_claims(claims(), config, 1000)
  assert_eq(identity.email, "me@example.com")
}

///|
test "validate_claims accepts string audience" {
  assert_eq(validation_error(claims(aud="aud1")), "ok")
}

///|
test "validate_claims rejects invalid claims" {
  assert_eq(
    validation_error(claims(iss="https://other.example.com")),
    "invalid issuer",
  )
  assert_eq(validation_error(claims(aud=["aud2"])), "invalid audience")
  assert_eq(validation_error(claims(aud="aud2")), "invalid audience")
  assert_eq(validation_error(claims(exp=900)), "token expired")
  assert_eq(validation_error(claims(email="")), "email is missing")
  assert_eq(validation_error({ "email": "me@example.com" }), "invalid issuer")
}

///|
test "validate_claims allows small clock skew" {
  assert_eq(validation_error(claims(exp=950)), "ok")
}

///|
test "validate_claims rejects not yet valid token" {
  let claims = claims()
  guard claims is Object(map) else { fail("claims must be an object") }
  map["nbf"] = 1100.0.to_json()
  assert_eq(validation_error(claims), "token not yet valid")
}

///|
test "validate_claims rejects missing config" {
  assert_eq(
    validation_error(claims(), config={ team_domain: "", audience: "", }),
    "access config is missing",
  )
}

///|
fn parse_error(token : String) -> String {
  try parse_token(token) catch {
    AuthError(message) => message
  } noraise {
    _ => "ok"
  }
}

///|
test "parse_token" {
  let header = "eyJhbGciOiJSUzI1NiIsImtpZCI6ImsxIn0"
  let payload = "eyJlbWFpbCI6Im1lQGV4YW1wbGUuY29tIn0"
  let token = parse_token("\{header}.\{payload}.sig")
  assert_eq(token.kid, "k1")
  assert_eq(token.signing_input, "\{header}.\{payload}")
  assert_eq(token.signature, "sig")
  assert_eq(parse_error(""), "malformed token")
  assert_eq(parse_error("\{header}.\{payload}"), "malformed token")
  assert_eq(parse_error("\{header}.\{payload}."), "malformed token")
  assert_eq(parse_error("!!.\{payload}.sig"), "malformed token part")
  assert_eq(
    parse_error("eyJhbGciOiJIUzI1NiIsImtpZCI6ImsxIn0.\{payload}.sig"),
    "unsupported token header",
  )
}
