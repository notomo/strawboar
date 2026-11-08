// Renders `Html` to the DOM, and updates the DOM by the differences from the
// previous `Html`. A node is reused for the child with the same key (or the same
// position and tag if it has no key), and stays where it is unless its order
// changes, so that open dialogs, popovers and focus are kept.

///|
/// A child rendered to the DOM.
priv enum Rendered {
  RenderedText(@dom.Node)
  RenderedElement(@dom.Node, Element, Array[(String, Rendered)])
}

///|
fn Rendered::node(self : Rendered) -> @dom.Node {
  match self {
    RenderedText(node) | RenderedElement(node, _, _) => node
  }
}

///|
/// The children with the fragments replaced by their contents, each with the
/// key that identifies it among its siblings: its own key if it has one, or
/// its position as written and its tag. A position counts children that render
/// nothing (`nothing` and empty fragments) too, so that a child that comes and
/// goes does not shift the ones after it.
fn keyed_children(
  children : Array[Html],
  prefix : String,
) -> Array[(String, Html)] {
  children
  .mapi((i, child) => {
    let position = "\{prefix}\{i}"
    match child {
      Fragment(children) => keyed_children(children, "\{position}.")
      Element({ key: Some(key), .. }) => [("k:\{key}", child)]
      Element({ tag, .. }) => [("i:\{position}:\{tag}", child)]
      Text(_) => [("i:\{position}:#text", child)]
    }
  })
  .fold(init=[], (all, more) => all + more)
}

///|
fn create(html : Html) -> Rendered {
  match html {
    Text(text) => RenderedText(@dom.create_text(text))
    Element(element) => {
      let node = @dom.create_element(element.tag)
      element.attrs.each(attr => node.set_attribute(attr.0, attr.1))
      element.handlers.each(handler => node.set_handler(handler.0, handler.1))
      let children = keyed_children(element.children, "").map(child => {
        (child.0, create(child.1))
      })
      children.each(child => node.append_child(child.1.node()))
      if element.value is Some(value) {
        node.set_value(value)
      }
      RenderedElement(node, element, children)
    }
    // `keyed_children` replaces the fragments by their contents.
    Fragment(_) => abort("a fragment is not rendered by itself")
  }
}

///|
/// Updates `old` to `html` if it can be reused for it.
fn update(old : Rendered, html : Html) -> Rendered? {
  match (old, html) {
    (RenderedText(node), Text(text)) => {
      node.set_text(text)
      Some(RenderedText(node))
    }
    (RenderedElement(node, old, children), Element(new)) if old.tag == new.tag => {
      update_attrs(node, old.attrs, new.attrs)
      let names = new.handlers.map(handler => handler.0)
      old.handlers
      .filter(handler => !names.contains(handler.0))
      .each(handler => node.remove_handler(handler.0))
      new.handlers.each(handler => node.set_handler(handler.0, handler.1))
      let children = update_children(
        node,
        children,
        keyed_children(new.children, ""),
      )
      if new.value is Some(value) {
        node.set_value(value)
      }
      Some(RenderedElement(node, new, children))
    }
    _ => None
  }
}

///|
fn update_attrs(
  node : @dom.Node,
  old : Array[(String, String)],
  new : Array[(String, String)],
) -> Unit {
  let old = Map::from_array(old)
  let new = Map::from_array(new)
  old.each((name, _) => if !new.contains(name) { node.remove_attribute(name) })
  new.each((name, value) => {
    if old.get(name) != Some(value) {
      node.set_attribute(name, value)
    }
  })
}

///|
/// Updates the children of `parent` from `old` to `new`, both keyed by
/// `keyed_children`.
fn update_children(
  parent : @dom.Node,
  old : Array[(String, Rendered)],
  new : Array[(String, Html)],
) -> Array[(String, Rendered)] {
  // Old children that are not reused yet.
  let unused = Map::from_array(old)
  let rendered = new.map(child => {
    let (key, html) = child
    let reused = unused.get(key).bind(old => update(old, html))
    match reused {
      Some(rendered) => {
        unused.remove(key)
        (key, rendered)
      }
      None => (key, create(html))
    }
  })
  // Removed first, so that the children kept in order are not moved.
  unused.each((_, child) => child.node().remove())
  rendered.eachi((i, child) => {
    let node = child.1.node()
    match parent.child_at(i) {
      Some(current) if current.same(node) => ()
      Some(current) => parent.insert_before(node, current)
      None => parent.append_child(node)
    }
  })
  rendered
}

///|
/// The model of a view, rendered into an element after each change.
pub struct App[M] {
  priv root : @dom.Node
  priv mut model : M
  priv mut view : ((M) -> Html)?
  priv mut rendered : Array[(String, Rendered)]
  priv mut scheduled : Bool
  priv effects : Array[() -> Unit]
}

///|
/// An app of `model` in the element `id`, rendered once `mount` gives it a view.
pub fn[M] App::new(id : String, model : M) -> App[M] {
  guard @dom.element_by_id(id) is Some(root) else {
    abort("no element to mount the app: #\{id}")
  }
  root.remove_children()
  { root, model, view: None, rendered: [], scheduled: false, effects: [], }
}

///|
/// Renders the model with `view`, now and after each change.
pub fn[M] App::mount(self : App[M], view : (M) -> Html) -> Unit {
  self.view = Some(view)
  self.render()
}

///|
pub fn[M] App::model(self : App[M]) -> M {
  self.model
}

///|
/// Changes the model. The view is rendered once for the changes made before
/// the next frame.
pub fn[M] App::update(self : App[M], f : (M) -> M) -> Unit {
  self.model = f(self.model)
  self.schedule()
}

///|
/// Runs `f` after the next render, e.g. to open a dialog that it renders.
pub fn[M] App::after_render(self : App[M], f : () -> Unit) -> Unit {
  self.effects.push(f)
  self.schedule()
}

///|
fn[M] App::schedule(self : App[M]) -> Unit {
  if !self.scheduled {
    self.scheduled = true
    // Not in a microtask: rendering in the middle of an event could remove the
    // element whose default action is still to come, e.g. a submit button.
    @dom.request_animation_frame(() => self.render())
  }
}

///|
fn[M] App::render(self : App[M]) -> Unit {
  self.scheduled = false
  guard self.view is Some(view) else { return }
  self.rendered = update_children(
    self.root,
    self.rendered,
    keyed_children([view(self.model)], ""),
  )
  let effects = self.effects.copy()
  self.effects.clear()
  effects.each(f => f())
}
