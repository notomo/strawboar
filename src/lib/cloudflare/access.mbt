///|
/// Cloudflare Access application settings used to verify its JWT.
pub(all) struct AccessConfig {
  /// e.g. `example.cloudflareaccess.com`
  team_domain : String
  /// Application Audience (AUD) tag
  audience : String
}

///|
pub(all) struct AccessIdentity {
  email : String
}

///|
pub(all) suberror AccessError {
  AccessError(String)
}

///|
priv struct Token {
  kid : String
  claims : Json
  signing_input : String
  signature : String
}

///|
/// Allowed clock skew in seconds.
let leeway : Double = 60

///|
fn parse_token(token : String) -> Token raise AccessError {
  let parts = token.split(".").map(part => part.to_owned()).collect()
  guard parts is [header, payload, signature] &&
    header != "" &&
    payload != "" &&
    signature != "" else {
    raise AccessError("malformed token")
  }
  let header_json = decode_json(header)
  guard header_json is { "alg": String("RS256"), "kid": String(kid), .. } else {
    raise AccessError("unsupported token header")
  }
  {
    kid,
    claims: decode_json(payload),
    signing_input: "\{header}.\{payload}",
    signature,
  }
}

///|
fn decode_json(part : String) -> Json raise AccessError {
  @json.parse(@web.base64url_decode(part)) catch {
    _ => raise AccessError("malformed token part")
  }
}

///|
fn validate_claims(
  claims : Json,
  config : AccessConfig,
  now : Double,
) -> AccessIdentity raise AccessError {
  guard config.team_domain != "" && config.audience != "" else {
    raise AccessError("access config is missing")
  }
  guard claims is { "iss": String(iss), .. } &&
    iss == "https://\{config.team_domain}" else {
    raise AccessError("invalid issuer")
  }
  let audience_matched = match claims {
    { "aud": String(aud), .. } => aud == config.audience
    { "aud": Array(auds), .. } =>
      auds.iter().any(aud => aud is String(aud) && aud == config.audience)
    _ => false
  }
  guard audience_matched else { raise AccessError("invalid audience") }
  guard claims is { "exp": Number(exp, ..), .. } && now < exp + leeway else {
    raise AccessError("token expired")
  }
  match claims {
    { "nbf": Number(nbf, ..), .. } if now + leeway < nbf =>
      raise AccessError("token not yet valid")
    _ => ()
  }
  guard claims is { "email": String(email), .. } && email != "" else {
    raise AccessError("email is missing")
  }
  { email, }
}

///|
priv struct KeySet {
  fetched_at : Double
  keys : Array[Json]
}

///|
let key_set_cache : Ref[KeySet?] = { val: None, }

///|
let key_set_ttl : Double = 3600

///|
async fn fetch_key_set(config : AccessConfig, now : Double) -> KeySet {
  let body = @web.fetch_text(
    "https://\{config.team_domain}/cdn-cgi/access/certs",
  )
  let keys = match @json.parse(body) {
    { "keys": Array(keys), .. } => keys
    _ => []
  }
  let key_set = { fetched_at: now, keys, }
  key_set_cache.val = Some(key_set)
  key_set
}

///|
fn KeySet::find(self : KeySet, kid : String) -> Json? {
  self.keys
  .iter()
  .find_first(key => key is { "kid": String(k), .. } && k == kid)
}

///|
async fn find_key(config : AccessConfig, kid : String, now : Double) -> Json? {
  let cached = match key_set_cache.val {
    Some(key_set) if now - key_set.fetched_at < key_set_ttl => key_set.find(kid)
    _ => None
  }
  match cached {
    Some(_) => cached
    // The key may have been rotated, so refetch once.
    None => fetch_key_set(config, now).find(kid)
  }
}

///|
/// Verifies the Cloudflare Access JWT sent with the request
/// (`Cf-Access-Jwt-Assertion` header).
pub async fn verify_access(
  request : @web.Request,
  config : AccessConfig,
  now : Double,
) -> AccessIdentity raise AccessError {
  let token = request.header("cf-access-jwt-assertion")
  guard token != "" else { raise AccessError("token is missing") }
  let parsed = parse_token(token)
  let identity = validate_claims(parsed.claims, config, now)
  let key = find_key(config, parsed.kid, now) catch {
    _ => raise AccessError("failed to fetch signing keys")
  }
  guard key is Some(key) else { raise AccessError("unknown signing key") }
  let verified = @web.verify_rs256(
    key.stringify(),
    parsed.signing_input,
    parsed.signature,
  ) catch {
    _ => false
  }
  guard verified else { raise AccessError("invalid signature") }
  identity
}
