# Quote Book — frontend

SvelteKit frontend for the Quote Book app. Talks to the Rust backend (`quotes-v2`)
over its JSON HTTP API using JWT bearer tokens.

## Setup

```bash
pnpm install
cp .env.example .env   # optional; defaults to http://localhost:8080
pnpm dev               # dev server on http://localhost:5173
```

Set `VITE_API_BASE` in `.env` to point at the backend. It defaults to the
hosted backend at `https://quote-db.qinnovate.nz`; for local backend work use
`http://localhost:8080`.

## How it works

- **Auth** is token-based. Login/signup return an access + refresh token pair
  (see `src/lib/api.ts`); they're persisted in `localStorage` and the access
  token is sent as `Authorization: Bearer …`. On a 401 the client transparently
  refreshes once before retrying. Rendering is client-side (`ssr = false`)
  because the session lives in the browser.
- **`src/lib/api.ts`** is the single typed client for every backend endpoint.
- **Routes**
  - `/` — your books + books shared with you
  - `/create` — new book
  - `/book/[id]` — quotes (add/search/delete, with file attachments)
  - `/book/[id]/options` — rename, members, email invites, share links, delete
  - `/login`, `/reset-password`, `/verify-email` — auth flows
  - `/invite?token=…` — accept an email invite
  - `/share?token=…` — accept a share link

## Commands

```bash
pnpm dev        # dev server
pnpm build      # production build (adapter-cloudflare)
pnpm preview    # preview the build
pnpm check      # svelte-check
pnpm lint       # prettier + eslint
```
