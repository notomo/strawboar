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
