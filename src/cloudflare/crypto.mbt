///|
extern "js" fn fetch_text_ffi(url : String) -> @js_async.Promise[String] =
  #| async (url) => {
  #|   const response = await fetch(url);
  #|   if (!response.ok) {
  #|     throw new Error(`failed to fetch ${url}: ${response.status}`);
  #|   }
  #|   return response.text();
  #| }

///|
pub async fn fetch_text(url : String) -> String {
  fetch_text_ffi(url).wait()
}

///|
extern "js" fn verify_rs256_ffi(
  jwk : String,
  signing_input : String,
  signature : String,
) -> @js_async.Promise[Bool] =
  #| async (jwk, signingInput, signature) => {
  #|   try {
  #|     const key = await crypto.subtle.importKey(
  #|       "jwk",
  #|       JSON.parse(jwk),
  #|       { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
  #|       false,
  #|       ["verify"],
  #|     );
  #|     const base64 = signature.replace(/-/g, "+").replace(/_/g, "/");
  #|     const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
  #|     return await crypto.subtle.verify(
  #|       "RSASSA-PKCS1-v1_5",
  #|       key,
  #|       bytes,
  #|       new TextEncoder().encode(signingInput),
  #|     );
  #|   } catch {
  #|     return false;
  #|   }
  #| }

///|
/// Verifies an RS256 signature (base64url encoded) with a JWK public key.
/// Returns false for any malformed input.
pub async fn verify_rs256(
  jwk : String,
  signing_input : String,
  signature : String,
) -> Bool {
  verify_rs256_ffi(jwk, signing_input, signature).wait()
}

///|
/// Decodes a base64url string as UTF-8.
/// Returns an empty string for malformed input.
pub extern "js" fn base64url_decode(input : String) -> String =
  #| (input) => {
  #|   try {
  #|     const base64 = input.replace(/-/g, "+").replace(/_/g, "/");
  #|     const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
  #|     return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  #|   } catch {
  #|     return "";
  #|   }
  #| }

///|
/// Current UNIX time in seconds.
pub extern "js" fn now_seconds() -> Double =
  #| () => Date.now() / 1000
