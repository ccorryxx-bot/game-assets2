#!/usr/bin/env bash
# One-time migration: uploads every thumbnail in pg/ pp/ jili/ jdb/ into the
# game-assets2 R2 bucket, preserving the {provider}/{game_code}.webp key structure.
#
# Requirements: `wrangler` CLI installed and logged in (`wrangler login`),
# run from the root of the game-assets2 repo.
#
# Usage: bash scripts/upload-to-r2.sh

set -euo pipefail

BUCKET="game-assets2"
PROVIDERS=(pg pp jili jdb)
count=0
failed=0

for provider in "${PROVIDERS[@]}"; do
  for file in "$provider"/*.webp; do
    [ -e "$file" ] || continue
    key="$file"  # already in "{provider}/{code}.webp" form
    if wrangler r2 object put "${BUCKET}/${key}" --file="$file" --content-type="image/webp" --remote >/dev/null 2>&1; then
      count=$((count+1))
    else
      echo "FAILED: $key"
      failed=$((failed+1))
    fi
    if (( count % 100 == 0 )); then
      echo "...${count} uploaded"
    fi
  done
done

echo "Done. Uploaded: ${count}, Failed: ${failed}"
