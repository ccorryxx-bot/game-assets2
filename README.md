# game-assets2

Shared game-thumbnail CDN for Novabett platforms — confirmed consumers:
**iW99** and **iMBET69** (both proxy to this same Worker/domain via their own
`vercel.json` rewrite; check other Novabett sites individually before
assuming they're included).

Serves `.webp` thumbnails via a Cloudflare Worker backed by an R2 bucket, at
custom domain **`assetcloud.online`**.

> This repo was originally a jsDelivr-hosted static file store (`.jpg`,
> "game-assets" / DiamondBett branding). That's fully retired — see History
> below for the real migration path to today's setup.

## Architecture (current, confirmed 2026-09-10)

```
Client → https://assetcloud.online/{provider}/{game_code}.webp
       → Worker "game-assets2"  (src/index.js, this repo's main branch)
       → env.GAME_ASSETS.get("{provider}/{game_code}.webp")   (R2 binding)
       → R2 bucket "game-assets2"  ← serves the object
```

Consuming sites never link to `assetcloud.online` directly in their own
domain — each proxies it same-origin via its own Vercel rewrite
(`/img/thumb/(.*) → https://assetcloud.online/$1`) to avoid ISP/VPN blocking
by third-party domain suffix. See `gameAssets.js`/`.ts` in each consuming
repo for their side of this.

`src/index.js` only serves `GET`/`HEAD`, returns `404` on a missing key, and
sets `Cache-Control: public, max-age=31536000, immutable` — **an existing
key/filename must never be reused for a different image**; ship a new
filename for replacements, or edge caches will keep serving the old file
indefinitely.

## History

- **Until 2026-07-13**: jsDelivr CDN, `.jpg` files, "DiamondBett" branding
  (see git history before this date — fully unrelated to current setup).
- **2026-07-13 → 2026-09-05**: Cloudflare Workers **Static Assets** — files
  bundled directly into this repo's deploy (`wrangler deploy` from a
  `[assets] directory = "./"` config), no R2 involved.
- **2026-09-05 → 2026-09-09**: R2 migration attempted (commits `724d27e` →
  `0827a9c`), including a `game-assets2-r2` rename to avoid touching
  production during testing. **Reverted the same window** (commit `ad6f15a`)
  because the R2 bucket wasn't fully populated yet — deploying it as-is
  would have 404'd every existing thumbnail. `wrangler.toml` on `main` was
  rolled back to the static-assets config at that point.
- **2026-09-10: R2 migration cut over live.** Worker `game-assets2` now has
  an R2 bucket binding (`GAME_ASSETS` → bucket `game-assets2`) and serves
  `src/index.js` (the R2-backed code — already present on `main` since the
  09-05 attempt, just not previously wired up in production). Confirmed via
  Cloudflare dashboard **and** direct Cloudflare MCP check
  (`workers_get_worker_code` on the live Worker returns this file verbatim).

  ⚠️ **`wrangler.toml` on `main` was NOT updated for this cutover** — it
  still has the old static-assets config below, with no R2 binding:
  ```toml
  name = "game-assets2"
  compatibility_date = "2025-01-01"

  [assets]
  directory = "./"
  ```
  Running `wrangler deploy` from this repo's current `main` **would revert
  production back to static-assets and drop the R2 binding**. Fix
  `wrangler.toml` to match the live R2 config before deploying from here
  again (see Known pending items below).

## Folder structure

```
game-assets2/
├── pg/     → PG Soft         {game_code}.webp   (161 files)
├── pp/     → Pragmatic Play  {game_code}.webp   (698 files)
├── jili/   → JILI Gaming     {game_code}.webp   (269 files, incl. 8 Buffalo-series
│                                                   added 2026-09-09, commit c5828c6)
└── jdb/    → JDB Gaming      {game_code}.webp   (138 files)
```

## Adding / updating a thumbnail

Committing a file to this repo does **not** by itself update the live CDN —
R2 is what the Worker actually reads from at runtime. Two separate steps:

1. Add the `.webp` file to the matching provider folder here, commit + push
   (keeps this repo as the source-of-truth / backup copy).
2. Upload the same file into the R2 bucket with a matching key:
   ```sh
   wrangler r2 object put game-assets2/{provider}/{game_code}.webp \
     --file={provider}/{game_code}.webp --content-type=image/webp --remote
   ```
   `scripts/upload-to-r2.sh` automates this for a full-folder batch (requires
   `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` in the shell, and does a
   single diagnostic test-upload before looping the rest — see the script's
   own comments).

Then, in **each consuming site's** Supabase `games` table, add/flag the
matching row: `provider_code`, `game_code`, `has_thumbnail = true`.

## Known pending items

- [ ] Fix `wrangler.toml` on `main` to match the live R2 config (see History)
      — until then, do not `wrangler deploy` from this repo.
- [ ] Confirm the full existing catalog (1266 files across `pg/pp/jili/jdb`)
      is actually present as R2 objects — this repo's git history has the
      files, but git alone doesn't push to R2 (see "Adding / updating"
      above). No MCP tool currently exposes R2 object-listing to verify this
      programmatically; spot-check a handful of known older thumbnails on a
      live site instead.
- [ ] The 8 new JILI Buffalo thumbnails (commit `c5828c6`, 2026-09-09) are in
      this repo but need confirming they were actually `r2 object put` into
      the bucket — being in the repo alone doesn't make them servable.
