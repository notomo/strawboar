// A small set of dark-themed components on top of the HTML of Rabbita.
// Each component renders native elements with a class of this stylesheet, so
// that hover, focus and open states live in CSS. Inline `style` passed to a
// component is applied last and overrides its class.

///|
/// Colors and radius of the dark theme, used through `var(--ui-*)`.
const Tokens : String = "color-scheme:dark;--ui-radius:0.625rem;--ui-background:oklch(0.145 0 0);--ui-foreground:oklch(0.985 0 0);--ui-card:oklch(0.205 0 0);--ui-popover:oklch(0.205 0 0);--ui-primary:oklch(0.922 0 0);--ui-primary-foreground:oklch(0.205 0 0);--ui-secondary:oklch(0.269 0 0);--ui-muted:oklch(0.269 0 0);--ui-muted-foreground:oklch(0.708 0 0);--ui-accent:oklch(0.269 0 0);--ui-destructive:oklch(0.704 0.191 22.216);--ui-destructive-subtle:oklch(0.704 0.191 22.216 / 0.2);--ui-border:oklch(1 0 0 / 0.1);--ui-input:oklch(1 0 0 / 0.15);--ui-input-background:oklch(1 0 0 / 0.045);--ui-outline-background:oklch(1 0 0 / 0.045);--ui-ring:oklch(0.556 0 0)"

///|
const Font : String = "font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,\"Segoe UI\",sans-serif;-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility"

///|
const Css : String =
  #|@keyframes ui-spin { to { transform:rotate(360deg); } }
  #|.ui-theme [hidden] { display:none !important; }
  #|
  #|.ui-button {
  #|  box-sizing:border-box; display:inline-flex; flex-shrink:0; align-items:center; justify-content:center; gap:0.375rem;
  #|  height:2rem; margin:0; padding:0 0.625rem; border:1px solid transparent; border-radius:var(--ui-radius);
  #|  background:transparent; background-clip:padding-box; color:var(--ui-foreground);
  #|  font:inherit; font-size:0.875rem; line-height:1.25rem; font-weight:500; white-space:nowrap; vertical-align:middle;
  #|  cursor:pointer; user-select:none; appearance:none; -webkit-appearance:none;
  #|  transition:color 150ms ease,background-color 150ms ease,border-color 150ms ease,box-shadow 150ms ease,opacity 150ms ease,transform 150ms ease;
  #|}
  #|.ui-button[data-variant="default"] { background:var(--ui-primary); color:var(--ui-primary-foreground); }
  #|.ui-button[data-variant="outline"] { background:var(--ui-outline-background); border-color:var(--ui-input); }
  #|.ui-button[data-variant="destructive"] { background:var(--ui-destructive-subtle); color:var(--ui-destructive); }
  #|.ui-button[data-size="sm"] { height:1.75rem; border-radius:min(calc(var(--ui-radius) - 0.125rem),12px); gap:0.25rem; font-size:0.8rem; }
  #|.ui-button[data-size="lg"] { height:2.25rem; }
  #|.ui-button[data-size="icon"] { width:2rem; padding:0; }
  #|.ui-button[data-size="icon-sm"] { width:1.75rem; height:1.75rem; padding:0; border-radius:min(calc(var(--ui-radius) - 0.125rem),12px); }
  #|.ui-button[data-size="icon-lg"] { width:2.25rem; height:2.25rem; padding:0; }
  #|.ui-button:disabled { opacity:0.5; cursor:not-allowed; pointer-events:none; }
  #|.ui-button:not(:disabled,[aria-haspopup]):active { transform:translateY(1px); }
  #|@media (hover:hover) {
  #|  .ui-button[data-variant="default"]:hover { background:color-mix(in oklab,var(--ui-primary) 80%,transparent); }
  #|  .ui-button[data-variant="outline"]:hover { background:color-mix(in oklab,var(--ui-input) 50%,transparent); }
  #|  .ui-button[data-variant="ghost"]:hover { background:color-mix(in oklab,var(--ui-accent) 50%,transparent); }
  #|  .ui-button[data-variant="destructive"]:hover { background:color-mix(in oklab,var(--ui-destructive) 30%,transparent); }
  #|  .ui-tab[aria-selected="false"]:hover { color:var(--ui-foreground); }
  #|  .ui-menu-item:hover { background:var(--ui-accent); }
  #|}
  #|
  #|:is(.ui-button,.ui-tab,.ui-input):focus-visible {
  #|  outline:3px solid color-mix(in oklab,var(--ui-ring) 50%,transparent); outline-offset:0; border-color:var(--ui-ring);
  #|}
  #|
  #|.ui-badge {
  #|  box-sizing:border-box; display:inline-flex; width:fit-content; height:1.25rem; flex-shrink:0; align-items:center; justify-content:center;
  #|  overflow:hidden; border:1px solid transparent; border-radius:9999px; padding:0.125rem 0.5rem;
  #|  font-size:0.75rem; line-height:1rem; font-weight:500; white-space:nowrap; vertical-align:middle;
  #|}
  #|.ui-badge[data-variant="secondary"] { background:var(--ui-secondary); color:var(--ui-foreground); }
  #|.ui-badge[data-variant="outline"] { border-color:var(--ui-border); color:var(--ui-foreground); }
  #|
  #|.ui-spinner {
  #|  box-sizing:border-box; display:inline-block; width:1rem; height:1rem; border:2px solid currentColor; border-right-color:transparent;
  #|  border-radius:50%; animation:ui-spin 1s linear infinite;
  #|}
  #|
  #|.ui-field { display:flex; flex-direction:column; gap:0.5rem; width:100%; }
  #|.ui-label { width:fit-content; font-size:0.875rem; line-height:1.375; font-weight:500; }
  #|.ui-field-error { color:var(--ui-destructive); font-size:0.875rem; line-height:1.25rem; }
  #|.ui-input {
  #|  box-sizing:border-box; display:flex; width:100%; min-width:0; height:2rem; margin:0; padding:0.25rem 0.625rem;
  #|  border:1px solid var(--ui-input); border-radius:var(--ui-radius); background:var(--ui-input-background); color:var(--ui-foreground);
  #|  font:inherit; font-size:1rem; line-height:1.5rem;
  #|  transition:border-color 150ms ease,outline-color 150ms ease;
  #|}
  #|textarea.ui-input { height:auto; min-height:4rem; padding:0.5rem 0.625rem; field-sizing:content; resize:vertical; }
  #|.ui-input::placeholder { color:var(--ui-muted-foreground); opacity:1; }
  #|@media (min-width:768px) {
  #|  .ui-input { font-size:0.875rem; line-height:1.25rem; }
  #|}
  #|
  #|.ui-tabs-list {
  #|  box-sizing:border-box; display:inline-flex; width:fit-content; max-width:100%; min-height:2rem; align-items:center; padding:0.1875rem;
  #|  border-radius:var(--ui-radius); background:var(--ui-muted); color:var(--ui-muted-foreground); overflow-x:auto;
  #|}
  #|.ui-tab {
  #|  box-sizing:border-box; display:inline-flex; flex:1; min-width:0; min-height:1.625rem; align-items:center; justify-content:center; gap:0.375rem;
  #|  margin:0; padding:0.125rem 0.375rem; border:1px solid var(--ui-tab-border,transparent); border-radius:calc(var(--ui-radius) - 0.125rem);
  #|  background:var(--ui-tab-bg,transparent); color:inherit; font:inherit; font-size:0.875rem; line-height:1.25rem; font-weight:500;
  #|  white-space:nowrap; cursor:pointer; user-select:none; appearance:none; -webkit-appearance:none;
  #|  transition:color 150ms ease,background-color 150ms ease,border-color 150ms ease,box-shadow 150ms ease;
  #|}
  #|.ui-tab[aria-selected="true"] {
  #|  border-color:var(--ui-tab-active-border,var(--ui-input)); background:var(--ui-tab-active-bg,var(--ui-outline-background));
  #|  color:var(--ui-foreground); box-shadow:var(--ui-tab-active-shadow,0 1px 2px rgb(0 0 0 / 0.05));
  #|}
  #|.ui-tab-panel { min-width:0; font-size:0.875rem; line-height:1.5; }
  #|
  #|.ui-dialog, .ui-sheet {
  #|  box-sizing:border-box; position:fixed; max-width:none; overflow-y:auto; padding:1rem; border:0;
  #|  background:var(--ui-popover); color:var(--ui-foreground);
  #|  opacity:0; transform:var(--ui-closed-transform);
  #|  transition:opacity 200ms ease,transform 200ms ease,display 200ms allow-discrete,overlay 200ms allow-discrete;
  #|}
  #|.ui-dialog[open], .ui-sheet[open] { opacity:1; transform:none; }
  #|@starting-style {
  #|  .ui-dialog[open], .ui-sheet[open] { opacity:0; transform:var(--ui-closed-transform); }
  #|}
  #|.ui-dialog {
  #|  --ui-closed-transform:translateY(-0.5rem) scale(0.95);
  #|  inset:0; width:min(calc(100% - 2rem),24rem); max-height:calc(100vh - 2rem); margin:auto;
  #|  border-radius:calc(var(--ui-radius) + 0.25rem); box-shadow:0 0 0 1px color-mix(in oklab,var(--ui-foreground) 10%,transparent);
  #|}
  #|.ui-dialog::backdrop { background:rgb(0 0 0 / 0.5); }
  #|.ui-sheet {
  #|  --ui-closed-transform:translate3d(2.5rem,0,0);
  #|  inset:0 0 0 auto; width:min(85vw,24rem); height:100dvh; max-height:100dvh; margin:0;
  #|  border-left:1px solid var(--ui-border); box-shadow:0 16px 48px rgb(0 0 0 / 0.2);
  #|}
  #|.ui-dialog-header { display:flex; min-width:0; flex-direction:column; gap:0.375rem; margin-bottom:1rem; }
  #|.ui-sheet .ui-dialog-header { gap:0.125rem; }
  #|.ui-dialog-title { margin:0; font-size:1rem; line-height:1.5rem; font-weight:500; letter-spacing:-0.01em; text-wrap:balance; }
  #|.ui-dialog-description { margin:0; color:var(--ui-muted-foreground); font-size:0.875rem; line-height:1.5; text-wrap:pretty; }
  #|.ui-dialog-footer {
  #|  display:flex; flex-wrap:wrap; align-items:center; justify-content:flex-end; gap:0.5rem;
  #|  margin:1rem -1rem -1rem; padding:1rem; border-top:1px solid var(--ui-border);
  #|  border-radius:0 0 calc(var(--ui-radius) + 0.25rem) calc(var(--ui-radius) + 0.25rem);
  #|  background:color-mix(in oklab,var(--ui-muted) 50%,transparent);
  #|}
  #|.ui-sheet-close { position:absolute; top:0.75rem; right:0.75rem; margin:0; }
  #|.ui-sheet-close .ui-button { opacity:0.7; }
  #|.ui-sheet-close .ui-button:is(:hover,:focus-visible) { opacity:1; }
  #|
  #|.ui-menu {
  #|  box-sizing:border-box; inset:auto; margin:4px 0; position-area:var(--ui-menu-area); position-try-fallbacks:flip-block;
  #|  width:max-content; max-width:calc(100vw - 1rem); padding:0.25rem;
  #|  border:1px solid color-mix(in oklab,var(--ui-foreground) 10%,transparent); border-radius:var(--ui-radius);
  #|  background:var(--ui-popover); color:var(--ui-foreground); font-size:0.875rem; line-height:1.25rem;
  #|  box-shadow:0 10px 15px -3px rgb(0 0 0 / 0.1),0 4px 6px -4px rgb(0 0 0 / 0.1);
  #|}
  #|.ui-menu:popover-open { display:flex; flex-direction:column; }
  #|.ui-menu-item {
  #|  display:flex; width:100%; align-items:center; gap:0.375rem; margin:0; padding:0.5rem 0.75rem; border:0;
  #|  border-radius:calc(var(--ui-radius) - 0.125rem); background:transparent; color:inherit;
  #|  font:inherit; text-align:start; white-space:nowrap; cursor:pointer; user-select:none; outline:none;
  #|}
  #|.ui-menu-item:focus-visible { background:var(--ui-accent); }
  #|
  #|.ui-toast {
  #|  box-sizing:border-box; display:flex; align-items:center; gap:0.75rem; width:100%; padding:0.875rem 1rem;
  #|  border:1px solid var(--ui-border); border-radius:1rem; background:var(--ui-background); color:var(--ui-foreground);
  #|  box-shadow:0 4px 12px rgb(0 0 0 / 0.1);
  #|}
  #|.ui-toast-title { flex:1; min-width:0; font-size:0.875rem; line-height:1.25rem; font-weight:500; }
  #|
  #|@media (prefers-reduced-motion:reduce) {
  #|  .ui-theme *, .ui-dialog, .ui-sheet { transition-duration:0s !important; }
  #|}

///|
fn styles(base : String, extra : Array[String]) -> Array[String] {
  [base, ..extra].filter(s => s != "")
}

///|
fn attrs_or_new(attrs : @html.Attrs?) -> @html.Attrs {
  match attrs {
    Some(attrs) => attrs.copy()
    None => @html.Attrs::build()
  }
}

///|
#warnings("-alert_xss_vulnerable")
fn stylesheet() -> @html.Html {
  // A constant of this package, so no input reaches `inner_html`.
  @html.style_tag(
    attrs=@html.Attrs::build().inner_html(Css),
    ([] : Array[@html.Html]),
  )
}

///|
/// The root of the components: it holds the stylesheet and the colors of the theme.
pub fn[C : @html.IsChildren] theme(
  style~ : Array[String] = [],
  children : C,
) -> @html.Html {
  @html.fragment([
    stylesheet(),
    @html.div(
      class="ui-theme",
      style=styles(
        "\{Tokens};\{Font};background:var(--ui-background);color:var(--ui-foreground)",
        style,
      ),
      children,
    ),
  ])
}
