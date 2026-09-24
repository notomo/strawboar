# strawboar

A personal dashboard for life TODOs, built with [MoonBit](https://www.moonbitlang.com/),
[Rabbita](https://github.com/moonbit-community/rabbita) and Cloudflare Workers.

## Architecture

- A single Cloudflare Worker serves the SPA (Workers Static Assets) and `/api/*`.
- Both the frontend and the API are written in MoonBit (JS target).
- Data is stored in Cloudflare D1.
- Access is restricted by Cloudflare Access; the Worker also verifies the Access JWT.

## Development

```bash
npm ci
npm run setup                  # enable git hooks
cp .dev.vars.example .dev.vars # local auth bypass for localhost
npm run dev                    # Vite (5173) + Worker with local D1 (8787)
npm run check_all              # format, check, test, build and E2E
```

## Deployment

`deploy.yaml` deploys `main` after CI succeeds. It requires the secrets
`CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` in the `main` GitHub environment.

The Worker requires the secrets `ACCESS_TEAM_DOMAIN` (e.g. `example.cloudflareaccess.com`)
and `ACCESS_AUD` (the Access application audience tag):

```bash
npx wrangler secret put ACCESS_TEAM_DOMAIN
npx wrangler secret put ACCESS_AUD
```
