///|
fn keys(children : Array[Html]) -> Array[String] {
  keyed_children(children, "").map(child => child.0)
}

///|
test "a child keeps its key when a sibling before it renders nothing" {
  let shown = keys([div("a"), div("backdrop"), dialog("panel")])
  let hidden = keys([div("a"), nothing, dialog("panel")])
  assert_eq(shown, ["i:0:div", "i:1:div", "i:2:dialog"])
  assert_eq(hidden, ["i:0:div", "i:2:dialog"])
}

///|
test "the children of a fragment are keyed by their nested position" {
  assert_eq(keys([fragment([text("a"), span("b")]), p("c")]), [
    "i:0.0:#text", "i:0.1:span", "i:1:p",
  ])
}

///|
test "children of a map are keyed by its keys" {
  let children : Map[String, Html] = { "chore-2": li("b"), "chore-1": li("a") }
  assert_eq(keys(IsChildren::to_children(children)), ["k:chore-2", "k:chore-1"])
}
