///|
fn input(
  title : String,
  interval_days? : Int = 7,
  next_due? : String,
  labels? : Array[String] = [],
) -> @core.ChoreInput {
  { title, interval_days, next_due: next_due.map(date), labels, }
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
  let chores = [
    chore(id=1, title="Clean bath", interval_days=7, labels=["bath"]),
    chore(
      id=2,
      title="Descale kettle",
      interval_days=30,
      last_done="2026-09-20",
    ),
  ]
  let text = @core.export_text(chores)
  inspect(
    text,
    content=(
      #|[
      #|  {
      #|    "title": "Clean bath",
      #|    "interval_days": 7,
      #|    "labels": [
      #|      "bath"
      #|    ],
      #|    "next_due": "2026-09-24"
      #|  },
      #|  {
      #|    "title": "Descale kettle",
      #|    "interval_days": 30,
      #|    "labels": [],
      #|    "next_due": "2026-09-24"
      #|  }
      #|]
    ),
  )
  assert_eq(
    @core.parse_definitions(text).map(i => i.to_json()),
    @core.export_definitions(chores).map(i => i.to_json()),
  )
}

///|
test "parse_definitions errors" {
  inspect(
    import_error(() => ignore(@core.parse_definitions("{"))),
    content="Invalid JSON.",
  )
  inspect(
    import_error(() => ignore(@core.parse_definitions("{}"))),
    content="Chores must be a JSON array.",
  )
  inspect(
    import_error(() => ignore(@core.parse_definitions("[{\"title\":\"a\"}]"))),
    content="Chore #1: title, interval_days and labels are required.",
  )
}

///|
test "import plan matches chores by title" {
  let today = date("2026-09-30")
  let existing = [
    chore(id=1, title="Clean bath", interval_days=7, last_done="2026-09-28"),
    chore(id=2, title="Descale kettle"),
  ]
  let plan = @core.ImportPlan::new(
    existing,
    [
      input(" Clean bath ", interval_days=10, next_due="2027-01-01", labels=[
        "bath",
      ]),
      input("Wash car"),
      input("Water plants", next_due="2026-10-05"),
    ],
    today,
  )
  assert_eq(plan.updates.map(c => c.to_json()), [
    chore(
      id=1,
      title="Clean bath",
      interval_days=10,
      next_due="2026-10-08",
      last_done="2026-09-28",
      labels=["bath"],
    ).to_json(),
  ])
  assert_eq(plan.creates.map(c => (c.0.title, c.1.to_string())), [
    ("Wash car", "2026-09-30"),
    ("Water plants", "2026-10-05"),
  ])
}

///|
test "import plan errors" {
  let today = date("2026-09-30")
  inspect(
    import_error(() => {
      ignore(@core.ImportPlan::new([], [input("a"), input(" a")], today))
    }),
    content="Duplicate title: a",
  )
  inspect(
    import_error(() => {
      ignore(
        @core.ImportPlan::new(
          [],
          [input("a"), input("b", interval_days=0)],
          today,
        ),
      )
    }),
    content="Chore #2: Interval must be between 1 and 3650 days.",
  )
}
