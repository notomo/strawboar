///|
#external
pub type D1Database

///|
#external
pub type D1PreparedStatement

///|
pub(all) enum D1Param {
  Text(String)
  Integer(Int)
  Null
}

///|
#external
priv type JsValue

///|
fn JsValue::text(value : String) -> JsValue = "%identity"

///|
fn JsValue::integer(value : Int) -> JsValue = "%identity"

///|
extern "js" fn JsValue::null() -> JsValue =
  #| () => null

///|
fn D1Param::to_js(self : D1Param) -> JsValue {
  match self {
    Text(value) => JsValue::text(value)
    Integer(value) => JsValue::integer(value)
    Null => JsValue::null()
  }
}

///|
#external
priv type JsArray

///|
extern "js" fn JsArray::new() -> JsArray =
  #| () => []

///|
extern "js" fn JsArray::push(self : JsArray, value : JsValue) -> Unit =
  #| (array, value) => { array.push(value) }

///|
pub extern "js" fn D1Database::prepare(
  self : D1Database,
  sql : String,
) -> D1PreparedStatement =
  #| (db, sql) => db.prepare(sql)

///|
extern "js" fn D1PreparedStatement::bind_ffi(
  self : D1PreparedStatement,
  params : JsArray,
) -> D1PreparedStatement =
  #| (stmt, params) => stmt.bind(...params)

///|
pub fn D1PreparedStatement::bind(
  self : D1PreparedStatement,
  params : Array[D1Param],
) -> D1PreparedStatement {
  let array = JsArray::new()
  params.each(param => array.push(param.to_js()))
  self.bind_ffi(array)
}

///|
extern "js" fn D1PreparedStatement::all_ffi(
  self : D1PreparedStatement,
) -> @js_async.Promise[String] =
  #| (stmt) => stmt.all().then((r) => JSON.stringify(r.results))

///|
/// Runs the statement and returns the result rows as a JSON array.
pub async fn D1PreparedStatement::all(self : D1PreparedStatement) -> Json {
  @json.parse(self.all_ffi().wait())
}

///|
extern "js" fn D1PreparedStatement::run_ffi(
  self : D1PreparedStatement,
) -> @js_async.Promise[Int] =
  #| (stmt) => stmt.run().then((r) => r.meta.changes)

///|
/// Runs the statement and returns the number of changed rows.
pub async fn D1PreparedStatement::run(self : D1PreparedStatement) -> Int {
  self.run_ffi().wait()
}

///|
extern "js" fn D1Database::batch_ffi(
  self : D1Database,
  statements : JsArray,
) -> @js_async.Promise[String] =
  #| (db, statements) => db.batch(statements).then((results) =>
  #|   JSON.stringify(results.map((r) => r.results ?? []))
  #| )

///|
fn JsValue::statement(value : D1PreparedStatement) -> JsValue = "%identity"

///|
/// Runs the statements in a single transaction and returns the result rows of each.
pub async fn D1Database::batch(
  self : D1Database,
  statements : Array[D1PreparedStatement],
) -> Array[Json] {
  let array = JsArray::new()
  statements.each(statement => array.push(JsValue::statement(statement)))
  match @json.parse(self.batch_ffi(array).wait()) {
    Array(results) => results
    _ => []
  }
}
