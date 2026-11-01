# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## Project Overview

A personal life-TODO dashboard. A single Cloudflare Worker serves a Rabbita SPA and a JSON API, both written in MoonBit (JS target), backed by Cloudflare D1 and protected by Cloudflare Access. It is built and run with the `cf` CLI and `@cloudflare/vite-plugin` (configured in `cloudflare.config.ts`), not Wrangler.

**This is a public repository.** Never commit secrets, account IDs, personal data or Access settings (team domain, AUD).

## Development Commands

```bash
node --run dev            # Vite with the Worker and a local D1 (5173)
node --run db:seed:local  # Replace the local D1 data with test data (db/seed.sql, dates relative to today)
node --run db:seed:check  # Apply the seed to a fresh local D1 to check it still works (in check_all and CI)
node --run build          # cf build (vite build, which runs moon build for the Worker)
node --run check          # Type check and format check
node --run format         # Format MoonBit code
node --run test           # MoonBit tests (js target)
node --run test:e2e       # Playwright (desktop, mobile, tablet/WebKit) in parallel, each against its own vite preview (8788-8790) with a fresh local D1 (requires .dev.vars)
```

## Quality Checks

**IMPORTANT**: Before completing any task, run `node --run check_all` to ensure all checks pass.

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
db/                  # D1 migrations, the seed for the local D1 and `d1.ts` (runs `cf d1` for the DB binding)
e2e/                 # Playwright tests
```

## Package Rules

- `src/lib/` holds no app specific policy (e.g. cache headers are set by `server`).
- Files other than MoonBit live in the directory of the package they belong to: `src/app` has `public/` (icons generated from `icon/`), and `src/server/worker.js` is the Worker entry. The exception is `index.html`, which loads the app as `/main.js`: it is in the Vite root, the repository root, as `@cloudflare/vite-plugin` reads `cloudflare.config.ts` and writes the build output there.
- Add a new file under `db/migrations/` for schema changes; never edit applied migrations.

## Important Notes

- **Authentication**: every `/api/*` request must pass `authenticate` in `src/server`. The local bypass only applies to localhost.
- **Dates**: chores use local dates (`YYYY-MM-DD`), not timestamps. "Today" is decided by the Worker and returned from `GET /api/chores`.
- **Domain rules** (scheduling, undo, labels, import) live in `src/core` with their unit tests; the app and the server use them instead of having their own.
- **UI**: use `rui` components (dark theme) and inline `style` for layout. One chore per row; clickable areas must look clickable. Editing happens in a non-modal panel (`rui.sheet`) overlaid on the right, not a modal. Less frequent actions go to a ⋮ menu instead of buttons. Actions that are hard to undo (archiving a chore, undoing a completion, deleting a label) ask for confirmation in a `rui.alert_dialog` first, which a click outside of it cancels. The dashboard must fit in the first view without scrolling on both desktop and mobile (checked in E2E).
- **E2E**:
  - E2E covers what needs the browser, the Worker and D1 together: the main user flows (each through the UI and kept after reload), layout and scrolling, differences between devices, how panels and dialogs open and close, and what the Worker serves.
  - Rules that live in `src/core` (dates, urgency, ordering, validation, import matching) are covered by its unit tests. E2E checks one representative case of each, e.g. one error message per form.
  - One test per user goal. Extend an existing test with a related check instead of adding a near-duplicate one.

## Accepted Trade-offs

Known limitations kept on purpose for a personal app; do not report them as issues unless the situation changes.

- **Today across midnight**: "today" is only refreshed by reloading, so a page left open (e.g. a PWA resumed from the background) keeps the previous day. A reload on `@sub.on_visibility_change` would fix it if needed.
- **Deploy**: `deploy.yaml` applies migrations before deploying, so the old Worker briefly runs on the new schema; this is fine as long as migrations are additive. Dependabot patch and minor updates (cf, `@cloudflare/vite-plugin` and vite included) are auto-merged and deployed once CI passes.

## Coding Style

**Prefer iterator methods over for loops**: Use `map`, `fold`, `filter`, `Array::makei` etc. for collection processing. Use `for` loops only for complex control flow (`continue`/`break`) or while-style loops.

**Prefer match over if-else chains**: Use `match` expressions for pattern matching — enables exhaustiveness checking, clearer intent, and better destructuring support.
