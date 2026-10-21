///|
test "is_same_origin" {
  let origin = "https://example.com"
  let allows = (http_method, fetch_site, request_origin) => {
    is_same_origin(http_method~, fetch_site~, origin~, request_origin~)
  }
  assert_true(allows("GET", "cross-site", "https://other.example"))
  assert_true(allows("POST", "same-origin", origin))
  assert_false(allows("POST", "cross-site", origin))
  assert_false(allows("DELETE", "same-site", origin))
  // Without `Sec-Fetch-Site`, `Origin` decides.
  assert_true(allows("PUT", "", origin))
  assert_false(allows("POST", "", "https://other.example"))
  assert_false(
    is_same_origin(
      http_method="POST",
      fetch_site="",
      origin="",
      request_origin=origin,
    ),
  )
}

///|
test "is_allowed_email" {
  assert_true(is_allowed_email("me@example.com", "me@example.com"))
  assert_true(
    is_allowed_email("Me@Example.com", "other@example.com, me@example.com"),
  )
  assert_false(is_allowed_email("me@example.com", "other@example.com"))
  assert_false(is_allowed_email("me@example.com", ""))
  assert_false(is_allowed_email("", ""))
  assert_false(is_allowed_email("", "me@example.com,"))
}
