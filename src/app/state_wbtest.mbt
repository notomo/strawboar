///|
fn test_chore(id : Int32, labels~ : Array[Int32] = []) -> @core.Chore {
  {
    id,
    title: "chore \{id}",
    description: "",
    repeat: AfterDone(7),
    next_due: test_date("2026-09-30"),
    last_done: None,
    labels,
  }
}

///|
/// A loaded model with labels 1 (red) and 2 (blue) and chores 1 and 2.
fn test_model() -> Model {
  Model::new().loaded({
    today: test_date("2026-09-24"),
    labels: [
      { id: 1, name: "bath", color: Red, },
      { id: 2, name: "kitchen", color: Blue, },
    ],
    chores: [test_chore(1, labels=[1]), test_chore(2, labels=[1, 2])],
    recent: [],
  })
}

///|
test "completing a chore is sent once" {
  let model = test_model().start_completing(1).unwrap()
  assert_eq(model.completing, [1])
  assert_true(model.start_completing(1) is None)
}

///|
test "a completed chore can be undone and is recent" {
  let done_on = test_date("2026-09-24")
  let chore = { ..test_chore(1), last_done: Some(done_on), }
  let model = test_model()
    .start_completing(1)
    .unwrap()
    .completed(1, { completion_id: 10, chore, })
  assert_eq(model.completing, [])
  assert_true(model.chores[0] == chore)
  assert_true(model.undo == Some({ completion_id: 10, title: "chore 1", }))
  assert_true(
    model.recent ==
    [{ completion_id: 10, chore_id: 1, title: "chore 1", done_on, }],
  )

  // Undoing removes it before the response.
  let undone = model.start_undo(10)
  assert_true(undone.undo == None)
  assert_true(undone.recent == [])
}

///|
test "the toast is kept for a newer completion" {
  let model = { ..test_model(), undo: Some({ completion_id: 11, title: "", }), }
  assert_true(model.dismiss_undo(10).undo is Some(_))
  assert_true(model.dismiss_undo(11).undo is None)
}

///|
test "a new chore is due today with the filtered label" {
  let model = { ..test_model(), label_filter: Some(2), }.open_new()
  assert_true(model.panel_open)
  let editor = model.editor().unwrap()
  assert_eq(editor.id, None)
  assert_eq(editor.next_due, "2026-09-24")
  assert_eq(editor.labels, [2])
}

///|
test "opening a monthly chore fills its fields" {
  let chore = {
    ..test_chore(3),
    repeat: Monthly({ months: 2, day: 15, lead_days: 5, }),
  }
  let model = { ..test_model(), chores: [chore], }.open_chore(3)
  let editor = model.editor().unwrap()
  assert_true(editor.repeat == Monthly)
  assert_eq((editor.months, editor.day, editor.lead_days), ("2", "15", "5"))
  // A chore that is not shown is not opened.
  assert_false(test_model().open_chore(3).panel_open)
}

///|
test "submitting an invalid chore shows the error and sends nothing" {
  let model = test_model().open_new()
  let (model, request) = model.submit_chore()
  assert_true(request is None)
  assert_true(model.editor().unwrap().error != "")

  let (model, request) = model
    .edit(editor => { ..editor, title: "new", })
    .submit_chore()
  assert_true(request is Some((None, { title: "new", .. })))
  assert_eq(model.editor().unwrap().error, "")
}

///|
test "saving closes the panel only if it is still for the chore" {
  let model = test_model().open_chore(1)
  assert_false(model.saved(Some(1), test_chore(1)).panel_open)
  assert_true(model.saved(Some(2), test_chore(2)).panel_open)
  assert_false(model.archived(1).panel_open)
  assert_eq(model.archived(1).chores.map(c => c.id), [2])
}

///|
test "a deleted label is removed from the chores and the filter" {
  let model = { ..test_model(), label_filter: Some(1), }
    .open_labels()
    .select_label(1)
    .label_deleted(1)
  assert_eq(model.labels.map(l => l.id), [2])
  assert_eq(model.chores.map(c => c.labels), [[], [2]])
  assert_eq(model.label_filter, None)
  // The form goes back to a new label.
  assert_true(model.panel is Some(Labels({ id: None, .. })))
}

///|
test "a saved label resets the form only if it was for it" {
  let model = test_model().open_labels().select_label(2)
  let label : @core.Label = { id: 1, name: "bathroom", color: Red, }
  assert_true(
    model.label_saved(Some(1), label).panel is Some(Labels({ id: Some(2), .. })),
  )
  let saved = model.label_saved(Some(2), { id: 2, name: "food", color: Blue, })
  assert_true(saved.panel is Some(Labels({ id: None, .. })))
  assert_eq(saved.labels.map(l => l.name), ["bath", "food"])
}

///|
test "invalid definitions are not imported" {
  let model = test_model().open_transfer()
  let (model, text) = model
    .edit_transfer(transfer => { ..transfer, text: "not json", })
    .submit_import()
  assert_true(text is None)
  assert_true(model.panel is Some(Transfer({ error, .. })) && error != "")
  let (_, text) = test_model().open_transfer().submit_import()
  assert_true(text is Some(_))
}
