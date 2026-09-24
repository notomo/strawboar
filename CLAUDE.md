# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A personal life-TODO dashboard. A single Cloudflare Worker serves a Rabbita SPA and a JSON API, both written in MoonBit (JS target), backed by Cloudflare D1 and protected by Cloudflare Access.

**This is a public repository.** Never commit secrets, account IDs, personal data or Access settings (team domain, AUD). All content in the repository must be in English.

## Development Commands

```bash
npm run dev        # Vite (5173, proxies /api) + wrangler dev (8787, local D1)
npm run build      # moon build + vite build
npm run check      # Type check and format check
npm run format     # Format MoonBit code
npm run test       # MoonBit tests (js target)
npm run test:e2e   # Playwright against a Worker on 8788 with a fresh local D1 (requires .dev.vars)
```

## Quality Checks

**IMPORTANT**: Before completing any task, run `npm run check_all` to ensure all checks pass.

## Package Structure

```
src/
├── core/        # Shared domain logic and API types (pure, used by app and worker)
├── cloudflare/  # JS FFI for Workers runtime, D1 and WebCrypto
├── auth/        # Cloudflare Access JWT verification
├── worker/      # Worker fetch handler and API routes (exports `fetch`)
└── app/         # Rabbita frontend (rui components)
worker/index.js  # Thin Worker entry that lazily imports src/worker output
migrations/      # D1 SQL migrations
assets/icon.svg  # App icon source; run `node scripts/generate-icons.mjs` to update public/*.png
e2e/             # Playwright tests
```

## Package Rules

- Domain logic and types shared between frontend and API → `src/core/` (no JS FFI).
- All raw JS FFI for the Workers runtime → `src/cloudflare/`.
- `src/app/` must not depend on `cloudflare`, `auth` or `worker`.
- Add a new file under `migrations/` for schema changes; never edit applied migrations.

## Important Notes

- **Global scope in Workers**: MoonBit JS output generates a random hash seed at module load, which Workers disallow in global scope. `worker/index.js` therefore imports the MoonBit module lazily inside the handler. Keep it that way.
- **Authentication**: every `/api/*` request must pass `authenticate` in `src/worker`. The local bypass (`DEV_AUTH_BYPASS_EMAIL` in `.dev.vars`) only applies to localhost.
- **Dates**: chores use local dates (`YYYY-MM-DD`, Asia/Tokyo), not timestamps. "Today" is decided by the Worker and returned from `GET /api/chores`.
- **Chore scheduling**: urgency, ordering, done and postpone rules live in `src/core/chore.mbt`. Overdue chores are just "Due"; never show how late they are.
- **API**: routes are in `src/worker/api.mbt`, D1 queries in `src/worker/repository.mbt`.
- **UI**: use `rui` components (dark theme) and inline `style` for layout. One chore per row; clickable areas must look clickable. Editing happens in a non-modal panel (`rui.sheet`) overlaid on the right, not a modal. Dates are shown as `MM/dd`. The dashboard must fit in the first view without scrolling on both desktop and mobile (checked in E2E). All UI text is in English.
- **Rabbita**: follow `.mooncakes/moonbit-community/rabbita` conventions (`create_state`, `create_resource`, `@http`); avoid escape hatches such as `@cmd.effect` or `@dom`.

## Coding Style

**Prefer iterator methods over for loops**: Use `map`, `fold`, `filter`, `Array::makei` etc. for collection processing. Use `for` loops only for complex control flow (`continue`/`break`) or while-style loops.

**Prefer match over if-else chains**: Use `match` expressions for pattern matching — enables exhaustiveness checking, clearer intent, and better destructuring support.
