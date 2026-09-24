///|
using @rabbita {type Html, type Val}

///|
using @html {div, p}

///|
fn app() -> Val[Html] {
  let summary : @rabbita.Resource[@core.Summary] = @rabbita.create_resource(inject => {
    @http.get("/api/summary").expect_json(inject)
  })
  summary.view(summary => {
    @rui.theme(
      mode=Light,
      div(
        style=["min-height:100dvh;padding:1rem;box-sizing:border-box"],
        div(style=["max-width:40rem;margin:0 auto"], summary_card(summary)),
      ),
    )
  })
}

///|
fn summary_card(summary : @rabbita.Status[@core.Summary]) -> Html {
  @rui.card([
    @rui.card_header([
      @rui.card_title("strawboar"),
      @rui.card_description(
        match summary {
          Loaded(summary) => "Signed in as \{summary.email}"
          Pending => "Loading..."
          Failed(_) => "Failed to load"
        },
      ),
    ]),
    @rui.card_content(
      match summary {
        Loaded(summary) => p(id="chore-count", "\{summary.chore_count} chores")
        Pending => @rui.spinner(label="Loading")
        Failed(_) => p("Please reload the page.")
      },
    ),
  ])
}

///|
fn main {
  @rabbita.new(app).mount("app")
}
