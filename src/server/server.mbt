///|
/// Worker `fetch` handler, called from `worker/index.js`.
pub fn fetch(
  request : @web.Request,
  env : @cloudflare.Env,
) -> @js_async.Promise[@web.Response] {
  @js_async.Promise::from_async(() => handle(request, env))
}

///|
async fn handle(request : @web.Request, env : @cloudflare.Env) -> @web.Response {
  let _identity = authenticate(request, env) catch {
    @cloudflare.AccessError(message) => {
      println("unauthorized: \{message}")
      return error_response("unauthorized", 401)
    }
  }
  route(request, env.d1("DB")) catch {
    BadRequest(message) => error_response(message, 400)
    NotFound => error_response("not found", 404)
    Forbidden => error_response("forbidden", 403)
    Conflict => error_response("conflict", 409)
    error => {
      println("internal error: \{error}")
      error_response("internal error", 500)
    }
  }
}

///|
async fn authenticate(
  request : @web.Request,
  env : @cloudflare.Env,
) -> @cloudflare.AccessIdentity raise @cloudflare.AccessError {
  // Only for `wrangler dev`: `.dev.vars` is never deployed.
  let bypass_email = env.string_var("DEV_AUTH_BYPASS_EMAIL")
  if bypass_email != "" && is_local(request.hostname()) {
    return { email: bypass_email, }
  }
  let config : @cloudflare.AccessConfig = {
    team_domain: env.string_var("ACCESS_TEAM_DOMAIN"),
    audience: env.string_var("ACCESS_AUD"),
  }
  let identity = @cloudflare.verify_access(request, config, @web.now_seconds())
  // Checked besides the Access policy, in case it lets in more people.
  guard is_allowed_email(identity.email, env.string_var("ALLOWED_EMAILS")) else {
    raise @cloudflare.AccessError("email not allowed: \{identity.email}")
  }
  identity
}

///|
/// Whether `email` is one of `allowed`, comma separated emails, ignoring case.
/// Nobody is allowed when `allowed` is empty, e.g. the secret is not set.
fn is_allowed_email(email : String, allowed : String) -> Bool {
  let email = email.trim().to_lower()
  email != "" &&
  allowed.split(",").any(entry => entry.trim().to_lower() == email)
}

///|
/// Whether a request may change data, against cross-site request forgery: a
/// form of another site can send a simple request, e.g. `text/plain` without
/// a preflight. `Sec-Fetch-Site` is required, or `Origin` if it is missing
/// (`fetch_site` and `origin` are empty when the header is absent).
fn is_same_origin(
  http_method~ : String,
  fetch_site~ : String,
  origin~ : String,
  request_origin~ : String,
) -> Bool {
  match (http_method, fetch_site) {
    ("GET" | "HEAD", _) => true
    (_, "") => origin == request_origin
    (_, site) => site == "same-origin"
  }
}

///|
fn is_local(hostname : String) -> Bool {
  hostname is ("localhost" | "127.0.0.1")
}

///|
/// API responses depend on the user's data, so they are never cached.
fn no_store() -> Map[String, String] {
  { "cache-control": "no-store" }
}

///|
fn json_response(body : Json, status : Int32) -> @web.Response {
  @web.Response::json(body.stringify(), status, headers=no_store())
}

///|
fn empty_response(status : Int32) -> @web.Response {
  @web.Response::empty(status, headers=no_store())
}

///|
fn error_response(message : String, status : Int32) -> @web.Response {
  json_response({ "error": Json(message) }, status)
}
