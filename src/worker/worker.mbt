///|
/// Worker `fetch` handler, called from `worker/index.js`.
pub fn fetch(
  request : @cloudflare.Request,
  env : @cloudflare.Env,
) -> @js_async.Promise[@cloudflare.Response] {
  @js_async.Promise::from_async(() => handle(request, env))
}

///|
async fn handle(
  request : @cloudflare.Request,
  env : @cloudflare.Env,
) -> @cloudflare.Response {
  // Only the owner can pass Access, so the identity itself is not used yet.
  let _identity = authenticate(request, env) catch {
    @auth.AuthError(message) => {
      println("unauthorized: \{message}")
      return error_response("unauthorized", 401)
    }
  }
  route(request, env.d1("DB")) catch {
    BadRequest(message) => error_response(message, 400)
    NotFound => error_response("not found", 404)
    error => {
      println("internal error: \{error}")
      error_response("internal error", 500)
    }
  }
}

///|
async fn authenticate(
  request : @cloudflare.Request,
  env : @cloudflare.Env,
) -> @auth.Identity raise @auth.AuthError {
  // Only for `wrangler dev`: `.dev.vars` is never deployed.
  let bypass_email = env.string_var("DEV_AUTH_BYPASS_EMAIL")
  if bypass_email != "" && is_local(request.hostname()) {
    return { email: bypass_email, }
  }
  let token = request.header("cf-access-jwt-assertion")
  guard token != "" else { raise @auth.AuthError("token is missing") }
  let config : @auth.AccessConfig = {
    team_domain: env.string_var("ACCESS_TEAM_DOMAIN"),
    audience: env.string_var("ACCESS_AUD"),
  }
  @auth.verify(token, config, @cloudflare.now_seconds())
}

///|
fn is_local(hostname : String) -> Bool {
  hostname is ("localhost" | "127.0.0.1")
}

///|
fn json_response(body : Json, status : Int) -> @cloudflare.Response {
  @cloudflare.Response::json(body.stringify(), status)
}

///|
fn error_response(message : String, status : Int) -> @cloudflare.Response {
  json_response({ "error": message.to_json() }, status)
}
