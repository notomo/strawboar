///|
fn definition(
  title : String,
  interval_days~ : Int32 = 7,
  repeat? : @core.Repeat,
  next_due? : String,
  description~ : String = "",
  labels~ : Array[String] = [],
) -> @core.ChoreDefinition {
  {
    title,
    description,
    repeat: repeat.unwrap_or(AfterDone(interval_days)),
    next_due: next_due.map(date),
    labels,
  }
}

///|
fn definitions(
  labels~ : Array[@core.LabelInput] = [],
  chores : Array[@core.ChoreDefinition],
) -> @core.Definitions {
  { labels, chores, }
}

///|
fn import_error(f : () -> Unit raise @core.ValidationError) -> String {
  try f() catch {
    ValidationError(message) => message
  } noraise {
    _ => "no error"
  }
}

///|
test "export and parse definitions" {
  let labels = [label(1, "bath", color=Blue), label(2, "weekly")]
  let chores = [
    chore(id=1, title="Clean bath", interval_days=7, labels=[2, 1]),
    chore(
      id=2,
      title="Descale kettle",
      description="Use citric acid.\nRinse twice.",
      interval_days=30,
      last_done="2026-09-20",
    ),
  ]
  let text = @core.export_text(labels, chores)
  inspect(
    text,
    content=(
      #|{
      #|  "labels": [
      #|    {
      #|      "name": "bath",
      #|      "color": "blue"
      #|    },
      #|    {
      #|      "name": "weekly",
      #|      "color": "blue"
      #|    }
      #|  ],
      #|  "chores": [
      #|    {
      #|      "title": "Clean bath",
      #|      "interval_days": 7,
      #|      "labels": [
      #|        "bath",
      #|        "weekly"
      #|      ],
      #|      "next_due": "2026-09-24"
      #|    },
      #|    {
      #|      "title": "Descale kettle",
      #|      "description": "Use citric acid.\nRinse twice.",
      #|      "interval_days": 30,
      #|      "labels": [],
      #|      "next_due": "2026-09-24"
      #|    }
      #|  ]
      #|}
    ),
  )
  assert_eq(
    @core.parse_definitions(text).to_json(),
    @core.export_definitions(labels, chores).to_json(),
  )
}

///|
test "parse_definitions errors" {
  inspect(
    import_error(() => ignore(@core.parse_definitions("{"))),
    content="Invalid JSON.",
  )
  inspect(
    import_error(() => ignore(@core.parse_definitions("[]"))),
    content="Definitions must be a JSON object with labels and chores arrays.",
  )
  inspect(
    import_error(() => {
      ignore(
        @core.parse_definitions(
          (
            #|{"labels":[{"name":"a","color":"black"}],"chores":[]}
          ),
        ),
      )
    }),
    content="Label #1: name and a color (red, orange, yellow, green, teal, blue, purple, pink) are required.",
  )
  inspect(
    import_error(() => {
      ignore(
        @core.parse_definitions(
          (
            #|{"labels":[],"chores":[{"title":"a"}]}
          ),
        ),
      )
    }),
    content="Chore #1: title, interval_days or monthly, and labels are required.",
  )
}

///|
test "import plan matches labels by name and chores by title" {
  let today = date("2026-09-30")
  let existing_labels = [label(1, "bath"), label(2, "weekly", color=Red)]
  let plan = @core.ImportPlan::new(
    existing_labels,
    definitions(
      labels=[
        { name: " bath ", color: Blue, },
        { name: "kitchen", color: Green, },
      ],
      [
        definition(" Clean bath ", interval_days=10, next_due="2027-01-01", labels=[
          "bath", "weekly", "bath",
        ]),
        definition("Wash car"),
        definition("Water plants", next_due="2026-10-05", labels=["kitchen"]),
      ],
    ),
  )
  assert_eq(Json(plan.label_updates), Json([label(1, "bath", color=Blue)]))
  assert_true(plan.label_creates == [{ name: "kitchen", color: Green, }])

  // After the labels are saved.
  let labels = [
    label(1, "bath", color=Blue),
    label(3, "kitchen", color=Green),
    label(2, "weekly", color=Red),
  ]
  let changes = plan.chore_changes(
    [
      chore(id=1, title="Clean bath", interval_days=7, last_done="2026-09-28"),
      chore(id=2, title="Descale kettle"),
    ],
    labels,
    today,
  )
  assert_eq(changes.updates.map(c => c.to_json()), [
    chore(
      id=1,
      title="Clean bath",
      interval_days=10,
      next_due="2026-10-08",
      last_done="2026-09-28",
      labels=[1, 2],
    ).to_json(),
  ])
  assert_eq(
    changes.creates.map(c => (c.0.title, c.0.labels, c.1.to_string())),
    [("Wash car", [], "2026-09-30"), ("Water plants", [3], "2026-10-05")],
  )
}

///|
test "import plan errors" {
  let plan_error = (defs : @core.Definitions) => {
    import_error(() => ignore(@core.ImportPlan::new([label(1, "bath")], defs)))
  }
  inspect(
    plan_error(definitions([definition("a"), definition(" a")])),
    content="Duplicate title: a",
  )
  inspect(
    plan_error(definitions([definition("a"), definition("b", interval_days=0)])),
    content="Chore #2: Interval must be between 1 and 3650 days.",
  )
  inspect(
    plan_error(definitions([definition("a", labels=["kitchen"])])),
    content="Chore #1: Unknown label: kitchen",
  )
  inspect(
    plan_error(
      definitions(
        labels=[{ name: "a", color: Red, }, { name: " a", color: Blue, }],
        [],
      ),
    ),
    content="Duplicate label: a",
  )
  inspect(
    plan_error(definitions(labels=[{ name: "", color: Red, }], [])),
    content="Label #1: Name is required.",
  )
}

///|
test "import trims label names of chores" {
  let plan = @core.ImportPlan::new(
    [label(1, "bath")],
    definitions(labels=[{ name: " kitchen ", color: Red, }], [
      definition("a", labels=[" kitchen", "bath ", "kitchen"]),
    ]),
  )
  assert_eq(plan.chores.map(c => c.labels), [["kitchen", "bath"]])
  let changes = plan.chore_changes(
    [],
    [label(1, "bath"), label(2, "kitchen")],
    date("2026-09-30"),
  )
  assert_eq(changes.creates.map(c => c.0.labels), [[2, 1]])
}

///|
test "monthly definitions" {
  let text =
    #|{"labels":[],"chores":[
    #|  {"title":"Rent","monthly":{"months":1,"day":27,"lead_days":21},"next_due":"2026-10-01","labels":[]},
    #|  {"title":"Bath","interval_days":7,"labels":[]}
    #|]}
  let defs = @core.parse_definitions(text)
  assert_true(
    defs.chores.map(c => c.repeat) ==
    [Monthly({ months: 1, day: 27, lead_days: 21, }), AfterDone(7)],
  )
  let changes = @core.ImportPlan::new([], defs).chore_changes(
    [],
    [],
    date("2026-09-30"),
  )
  assert_eq(changes.creates.map(c => c.1.to_string()), [
    "2026-10-27", "2026-09-30",
  ])
  inspect(
    defs.chores[0].to_json().stringify(),
    content=(
      #|{"title":"Rent","monthly":{"months":1,"day":27,"lead_days":21},"labels":[],"next_due":"2026-10-01"}
    ),
  )
  let invalid =
    #|{"labels":[],"chores":[{"title":"Rent","monthly":{"months":1},"labels":[]}]}
  inspect(
    import_error(() => ignore(@core.parse_definitions(invalid))),
    content="Chore #1: title, interval_days or monthly, and labels are required.",
  )
}
