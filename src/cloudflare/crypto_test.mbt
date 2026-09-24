///|
/// Test-only RSA public key (the private key was discarded after signing).
let test_jwk = "{\"kty\":\"RSA\",\"n\":\"4GBbDRZjxkGcwY3FDYUt8WcsvmYug4guN4OAKelIGP0VPgrrhlP25wOHslII0CdkqkHObg7b6QQewOpWVyDkgD3Ex2HzBpRAtOi1N78Cy5V6wFtdeIJpYFW6tPDpciNz6VvrU9AijLoYDOlwebQ68UAi7hDpYFSdyGhS2mCJ4uMPKqEn4saAtetJeJ16YT4j8Dt1wkRkCVcgb4Gy_ijAak18hqZ8Fm9Kx6Wy83yWSqhmR8hAWMUlRfEdpqOrPXOLDp73kRgmTWAyptT8jhm9RnU-ZgHSjgnV5wnLIK1zjDIBfFPPhlOzQuV5ki5sJbrIXOy89Iwiyb2CqCQYxofSdw\",\"e\":\"AQAB\",\"kid\":\"k1\",\"alg\":\"RS256\"}"

///|
let test_signing_input = "eyJhbGciOiJSUzI1NiIsImtpZCI6ImsxIn0.eyJlbWFpbCI6Im1lQGV4YW1wbGUuY29tIn0"

///|
let test_signature = "V05nICFh_-Itqw3egsGmyevhZAQ_H9vOVMeaV1EUh8xCZcRNxUcF_cU4yzWQs5jj2MKEw9aLHGhU6HxgFckW473G7aNgMjilKryiTqwkCf7ZUrkNOoXjH7nN2xtwTu5WV27iIQ7ulSDAbo_f7UUQJqBsScM0Hzng_Vzy3ALUU4hjDKKrHVerJLMUpUJywYyYQPz0txAW_ag_ns0OnpVuCgKQ5ctGxVMDn0YWi_iQ7rhYe0Xg7f9Kid_uEJ6R0Zbj9aDXexpDJcJnQNMBfmceUfPSfgUUj8PPcdCxPMhZHV0X_FnA8oUkbHoxGcHbL1qNkf0hXB4HH9r-eSSb6jQdaQ"

///|
async test "verify_rs256 accepts a valid signature" {
  assert_true(
    @cloudflare.verify_rs256(test_jwk, test_signing_input, test_signature),
  )
}

///|
async test "verify_rs256 rejects a tampered input" {
  assert_false(
    @cloudflare.verify_rs256(test_jwk, test_signing_input + "x", test_signature),
  )
}

///|
async test "verify_rs256 rejects malformed input" {
  assert_false(
    @cloudflare.verify_rs256("{}", test_signing_input, test_signature),
  )
  assert_false(@cloudflare.verify_rs256(test_jwk, test_signing_input, "!!"))
}

///|
test "base64url_decode" {
  assert_eq(
    @cloudflare.base64url_decode("eyJlbWFpbCI6Im1lQGV4YW1wbGUuY29tIn0"),
    "{\"email\":\"me@example.com\"}",
  )
  assert_eq(@cloudflare.base64url_decode("!!"), "")
}
