# Deploy notes

**2026-09-09 — Reverted to static-assets. R2 migration is ON HOLD, not live.**

`wrangler.toml` now points back at the live production Worker (`name = "game-assets2"`,
`[assets] directory = "./"` — no R2 binding). This matches what's actually deployed
today; confirmed via Cloudflare Dashboard → Workers & Pages → game-assets2 → Bindings
= "No connected bindings" (checked 2026-09-09).

To publish new/updated thumbnails right now: drop the `.webp` into the matching
`pg/ pp/ jili/ jdb/` folder, commit, then run from a machine with Cloudflare
credentials:

```
wrangler deploy
```

(No CI is connected to this repo — pushing to GitHub alone does NOT deploy anything.
Someone must run `wrangler deploy` manually.)

---

### About the abandoned R2 attempt (2026-09-05 → 09-07)

An earlier attempt to migrate thumbnail serving to R2 (`src/index.js`, bucket
`game-assets2`) is still in this repo's git history but was **never actually
deployed** — the commits deliberately renamed the worker to `game-assets2-r2`
specifically to avoid touching production, and that worker was never created.
The R2 bucket itself still exists in the Cloudflare account but is empty/unused.

Do not deploy `src/index.js` or the R2 `wrangler.toml` config as `game-assets2` —
the R2 bucket has none of the existing 1350+ thumbnails uploaded to it, so doing
so would break every game card currently live. If this migration is picked back
up later, the R2 bucket needs to be fully populated first, then cut over in one
deploy — not attempted with a half-empty bucket.
