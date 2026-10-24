# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## Project Overview

A personal life-TODO dashboard. A single Cloudflare Worker serves a Rabbita SPA and a JSON API, both written in MoonBit (JS target), backed by Cloudflare D1 and protected by Cloudflare Access.

**This is a public repository.** Never commit secrets, account IDs, personal data or Access settings (team domain, AUD). All content in the repository must be in English.

## Development Commands

```bash
npm run dev        # Vite (5173, proxies /api) + wrangler dev (8787, local D1)
npm run db:seed:local  # Replace the local D1 data with test data (db/seed.sql, dates relative to today)
npm run db:seed:check  # Apply the seed to a fresh local D1 to check it still works (in check_all and CI)
npm run build      # moon build + vite build
npm run check      # Type check and format check
npm run format     # Format MoonBit code
npm run test       # MoonBit tests (js target)
npm run test:e2e   # Playwright (desktop, mobile, tablet/WebKit) against a Worker on 8788 with a fresh local D1 (requires .dev.vars)
```

## Quality Checks

**IMPORTANT**: Before completing any task, run `npm run check_all` to ensure all checks pass.

## Package Structure

```
src/
├── core/            # Shared domain logic and API types (pure, used by app and server)
├── app/             # Rabbita frontend (rui components)
├── server/          # Worker fetch handler and API routes (exports `fetch`)
├── lib/             # Generic packages with no knowledge of this app
│   ├── web/         # JS FFI for Web standard APIs (Fetch API, WebCrypto, base64, time)
│   └── cloudflare/  # Cloudflare specific: Worker env bindings, D1, Cloudflare Access JWT verification
└── rules/           # Tests of the rules below that can be checked from the files (dependencies, FFI, ...)
db/                  # D1 migrations and the seed for the local D1
e2e/                 # Playwright tests
```

## Package Rules

- Domain logic and types shared between frontend and API → `src/core/` (no JS FFI).
- All raw JS FFI → `src/lib/` (`web` for Web standard APIs, `cloudflare` for Cloudflare specific ones).
- `src/lib/` holds no app specific policy (e.g. cache headers are set by `server`).
- Files other than MoonBit live in the directory of the package they belong to: `src/app` is also the Vite root (`index.html` loads it as `/main.js`, `public/` with icons generated from `icon/`), and `src/server/worker.js` is the Worker entry.
- Add a new file under `db/migrations/` for schema changes; never edit applied migrations.

## Important Notes

- **Global scope in Workers**: MoonBit JS output generates a random hash seed at module load, which Workers disallow in global scope. `src/server/worker.js` therefore imports the MoonBit module lazily inside the handler. Keep it that way.
- **Authentication**: every `/api/*` request must pass `authenticate` in `src/server`: the Access JWT, and its email must be in the `ALLOWED_EMAILS` secret (comma separated; nobody is allowed when it is unset). The local bypass (`DEV_AUTH_BYPASS_EMAIL` in `.dev.vars`) only applies to localhost.
- **Dates**: chores use local dates (`YYYY-MM-DD`, Asia/Tokyo), not timestamps. "Today" is decided by the Worker and returned from `GET /api/chores`.
- **Chore scheduling**: urgency, ordering, done and edit rules live in `src/core/chore.mbt`, and the two kinds of `Repeat` in `src/core/repeat.mbt`. An `AfterDone` chore is due `interval_days` after its last completion (also recalculated when the interval is edited) and is "Soon" in the last 20% of the interval. A `Monthly` chore (e.g. rent) is due on a fixed day of the month: done late or early, it moves to the next occurrence after its current due date, editing moves it to the new day within the month it is due (an `AfterDone` chore that becomes monthly moves to the next occurrence instead if that day is earlier than it was due), and it is "Soon" from `lead_days` before. `next_due` is only chosen by the user when creating a chore (a monthly chore takes its day from it). There is no postpone. Overdue chores are just in "Soon"; never show how late they are. In each section (Soon, Later) monthly chores come first, and Soon is then ordered by elapsed fraction of the interval so overdue chores come first; the Soon title shows the latest due date it covers. Every section is shown even when empty, can be collapsed and shows its count; Soon is expanded by default and Later is collapsed. "Done" lists all completions of the last 7 days (its title shows the date range, and the label filter applies to it too), monthly chores first, and is collapsed by default too.
- **Description**: a chore has optional free notes (`description`, multiple lines, e.g. the steps), edited in the chore panel and included in import/export. It is not shown on the dashboard rows.
- **Undo**: undoing a completion restores the schedule saved with it, so only the latest completion of a chore can be undone (`RecentDone::can_undo`, enforced in `undo_completion`). Besides the toast, it is undone with "Undo last done" in the ⋮ menu of the chore panel (opened by clicking a row in "Done"), which shows the date in its confirmation. The panel does not show the history of completions.
- **Labels**: created beforehand in the labels panel (`labels` table: unique name and a color from the fixed palette `LabelColor` in `src/core/label.mbt`). `chores.labels` is a JSON text column of label ids; deleting a label removes it from every chore. CSS colors of the palette live in `src/app/label_view.mbt`.
- **Import / Export**: labels and chore definitions are exchanged as JSON text (`Definitions`: labels and chores, chores refer to labels by name) in a text area. Import matches labels by name and chores by title (titles of active chores are unique, also by an index), updates or adds them and never deletes or archives; labels are saved before chores. Rules live in `src/core/transfer.mbt`.
- **API**: routes are in `src/server/api.mbt`, D1 queries in `src/server/repository.mbt`.
- **UI**: use `rui` components (dark theme) and inline `style` for layout. One chore per row; clickable areas must look clickable. Editing happens in a non-modal panel (`rui.sheet`) overlaid on the right, not a modal. Less frequent actions (Import / Export, Labels) live in the ⋮ menu (`rui.dropdown_menu`, created once in `app` because it is stateful) next to the add button. The chore panel has its own ⋮ menu (Undo last done, Archive) right of Save; created once too, its items do not depend on the chore. Actions that are hard to undo (archiving a chore, undoing a completion, deleting a label) ask for confirmation in a `rui.alert_dialog` first, which a click outside of it cancels. The header and the label filter stay at the top, and the dashboard below them scrolls by itself (`#dashboard`) so that each section title sticks at its top. Dates are shown as `MM/dd`, except today at the top (`yyyy-MM-dd (ddd)`). The dashboard must fit in the first view without scrolling on both desktop and mobile (checked in E2E). All UI text is in English.
- **E2E**: keep all locators and UI actions in the page object returned by `openPage` in `e2e/page.ts`.
  - E2E covers what needs the browser, the Worker and D1 together: the main user flows (each through the UI and kept after reload), layout and scrolling, differences between devices, how panels and dialogs open and close, and what the Worker serves.
  - Rules that live in `src/core` (dates, urgency, ordering, validation, import matching) are covered by its unit tests. E2E checks one representative case of each, e.g. one error message per form.
  - One test per user goal. Extend an existing test with a related check instead of adding a near-duplicate one.
- **Rabbita**: follow `.mooncakes/moonbit-community/rabbita` conventions (`create_state`, `create_resource`, `@http`); avoid escape hatches such as `@cmd.effect` or `@dom`.

## Accepted Trade-offs

Known limitations kept on purpose for a personal app; do not report them as issues unless the situation changes.

- **Today across midnight**: "today" is only refreshed by reloading, so a page left open (e.g. a PWA resumed from the background) keeps the previous day. A reload on `@sub.on_visibility_change` would fix it if needed.
- **Deploy**: `deploy.yaml` applies migrations before deploying, so the old Worker briefly runs on the new schema; this is fine as long as migrations are additive. Dependabot patch and minor updates (wrangler and vite included) are auto-merged and deployed once CI passes.

## Coding Style

**Prefer iterator methods over for loops**: Use `map`, `fold`, `filter`, `Array::makei` etc. for collection processing. Use `for` loops only for complex control flow (`continue`/`break`) or while-style loops.

**Prefer match over if-else chains**: Use `match` expressions for pattern matching — enables exhaustiveness checking, clearer intent, and better destructuring support.
