// JS FFI for the DOM: the operations that the renderer of lib/html and the
// components of lib/ui need, on plain nodes and events.

///|
/// A DOM node: an element or a text.
#external
pub type Node

///|
/// A DOM event.
#external
pub type Event

///|
extern "js" fn is_null(node : Node) -> Bool =
  #| (node) => node == null

///|
fn optional(node : Node) -> Node? {
  if is_null(node) {
    None
  } else {
    Some(node)
  }
}

///|
extern "js" fn element_by_id_ffi(id : String) -> Node =
  #| (id) => document.getElementById(id)

///|
pub fn element_by_id(id : String) -> Node? {
  optional(element_by_id_ffi(id))
}

///|
pub extern "js" fn create_element(tag : String) -> Node =
  #| (tag) => document.createElement(tag)

///|
pub extern "js" fn create_text(text : String) -> Node =
  #| (text) => document.createTextNode(text)

///|
/// Sets the text of a text node.
pub extern "js" fn Node::set_text(self : Node, text : String) -> Unit =
  #| (node, text) => { if (node.data !== text) node.data = text; }

///|
pub extern "js" fn Node::set_attribute(
  self : Node,
  name : String,
  value : String,
) -> Unit =
  #| (node, name, value) => node.setAttribute(name, value)

///|
pub extern "js" fn Node::remove_attribute(self : Node, name : String) -> Unit =
  #| (node, name) => node.removeAttribute(name)

///|
extern "js" fn Node::attribute_ffi(self : Node, name : String) -> String =
  #| (node, name) => node.getAttribute(name) ?? "\u0000"

///|
pub fn Node::attribute(self : Node, name : String) -> String? {
  match self.attribute_ffi(name) {
    "\u0000" => None
    value => Some(value)
  }
}

///|
/// The `value` of an input or a text area.
pub extern "js" fn Node::value(self : Node) -> String =
  #| (node) => node.value

///|
/// Sets the `value` only if it differs, so that the caret and the IME
/// composition are kept while typing.
pub extern "js" fn Node::set_value(self : Node, value : String) -> Unit =
  #| (node, value) => { if (node.value !== value) node.value = value; }

///|
pub extern "js" fn Node::append_child(self : Node, child : Node) -> Unit =
  #| (node, child) => node.appendChild(child)

///|
/// Inserts `child` before `reference`, a child of this node.
pub extern "js" fn Node::insert_before(
  self : Node,
  child : Node,
  reference : Node,
) -> Unit =
  #| (node, child, reference) => node.insertBefore(child, reference)

///|
extern "js" fn Node::child_at_ffi(self : Node, index : Int32) -> Node =
  #| (node, index) => node.childNodes[index] ?? null

///|
pub fn Node::child_at(self : Node, index : Int32) -> Node? {
  optional(self.child_at_ffi(index))
}

///|
pub extern "js" fn Node::remove(self : Node) -> Unit =
  #| (node) => node.remove()

///|
pub extern "js" fn Node::remove_children(self : Node) -> Unit =
  #| (node) => node.replaceChildren()

///|
pub extern "js" fn Node::same(self : Node, other : Node) -> Bool =
  #| (node, other) => node === other

///|
/// Sets the handler of the event `name`, replacing the previous one. The node
/// listens to the event once, and calls the handler set last.
pub extern "js" fn Node::set_handler(
  self : Node,
  name : String,
  handler : (Event) -> Unit,
) -> Unit =
  #| (node, name, handler) => {
  #|   const handlers = (node.__handlers ??= {});
  #|   if (!(name in handlers)) {
  #|     node.addEventListener(name, (event) => handlers[name]?.(event));
  #|   }
  #|   handlers[name] = handler;
  #| }

///|
pub extern "js" fn Node::remove_handler(self : Node, name : String) -> Unit =
  #| (node, name) => { if (node.__handlers) node.__handlers[name] = undefined; }

///|
pub extern "js" fn Node::focus(self : Node) -> Unit =
  #| (node) => node.focus()

///|
pub extern "js" fn Node::click(self : Node) -> Unit =
  #| (node) => node.click()

///|
pub extern "js" fn Node::matches(self : Node, selector : String) -> Bool =
  #| (node, selector) => node.matches(selector)

///|
extern "js" fn Node::closest_ffi(self : Node, selector : String) -> Node =
  #| (node, selector) => node.closest?.(selector) ?? null

///|
/// The closest inclusive ancestor that matches `selector`.
pub fn Node::closest(self : Node, selector : String) -> Node? {
  optional(self.closest_ffi(selector))
}

///|
extern "js" fn Node::query_all_ffi(
  self : Node,
  selector : String,
) -> FixedArray[Node] =
  #| (node, selector) => Array.from(node.querySelectorAll(selector))

///|
/// The descendants that match `selector`, in document order.
pub fn Node::query_all(self : Node, selector : String) -> Array[Node] {
  Array::from_fixed_array(self.query_all_ffi(selector))
}

///|
pub extern "js" fn Node::show_popover(self : Node) -> Unit =
  #| (node) => node.showPopover()

///|
pub extern "js" fn Node::hide_popover(self : Node) -> Unit =
  #| (node) => node.hidePopover()

///|
/// Opens a `<dialog>`, as a modal one or not.
pub extern "js" fn Node::show_dialog(self : Node, modal : Bool) -> Unit =
  #| (node, modal) => modal ? node.showModal() : node.show()

///|
pub extern "js" fn Node::close_dialog(self : Node) -> Unit =
  #| (node) => node.close()

///|
/// Whether a `<dialog>` is open.
pub extern "js" fn Node::is_open(self : Node) -> Bool =
  #| (node) => node.open

///|
/// The key of a keyboard event, e.g. `ArrowDown`.
pub extern "js" fn Event::key(self : Event) -> String =
  #| (event) => event.key

///|
pub extern "js" fn Event::target(self : Event) -> Node =
  #| (event) => event.target

///|
pub extern "js" fn Event::prevent_default(self : Event) -> Unit =
  #| (event) => event.preventDefault()

///|
/// Runs `f` before the browser paints the next frame, after the current event
/// and its default action (e.g. a click submitting a form).
pub extern "js" fn request_animation_frame(f : () -> Unit) -> Unit =
  #| (f) => requestAnimationFrame(() => f())
