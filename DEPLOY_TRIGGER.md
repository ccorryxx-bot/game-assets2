# Deploy notes

**2026-09-05 — Migrated to R2.**

Thumbnails now live in the `game-assets2` R2 bucket, served by `src/index.js`
via the `GAME_ASSETS` binding. Adding or updating a game thumbnail no longer
requires a Worker redeploy — just upload the new object directly:

```
wrangler r2 object put game-assets2/{provider}/{game_code}.webp --file=./path/to/image.webp --content-type=image/webp --remote
```

The `pg/ pp/ jili/ jdb/` folders in this repo remain as the source-of-truth
backup copy (git history) but are no longer bundled into the Worker deploy.

`wrangler deploy` is now only needed when `src/index.js` itself changes.
