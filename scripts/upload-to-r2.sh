#!/usr/bin/env bash
# One-time migration: uploads every thumbnail in pg/ pp/ jili/ jdb/ into the
# game-assets2 R2 bucket, preserving the {provider}/{game_code}.webp key structure.
#
# v2: diagnostic-first. Verifies wrangler auth + does one real test upload with
# FULL error output before touching the other 1,257 files. Stops immediately on
# any failure instead of silently looping through everything (v1's bug: it
# redirected wrangler's stderr to /dev/null, so a 100%-fail run gave zero
# diagnostic info).
#
# Requirements: `wrangler` CLI installed, CLOUDFLARE_API_TOKEN and
# CLOUDFLARE_ACCOUNT_ID exported in this shell.
#
# Usage: bash scripts/upload-to-r2.sh

set -uo pipefail

BUCKET="game-assets2"
PROVIDERS=(pg pp jili jdb)

echo "=== wrangler version ==="
wrangler --version

echo
echo "=== auth check (wrangler whoami) ==="
wrangler whoami
if [ $? -ne 0 ]; then
  echo "STOP: wrangler whoami failed. CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID"
  echo "are likely missing, wrong, or the token lacks permission. Report this"
  echo "output verbatim and stop here — do not proceed."
  exit 1
fi

echo
echo "=== single test upload (full output, not suppressed) ==="
TEST_FILE="pg/9f2c89ae5b7c0894c9ee9e223e3fd9d8.webp"
if [ ! -f "$TEST_FILE" ]; then
  echo "STOP: test file $TEST_FILE not found in this checkout. Report this and stop."
  exit 1
fi

wrangler r2 object put "${BUCKET}/${TEST_FILE}" --file="$TEST_FILE" --content-type="image/webp" --remote
TEST_EXIT=$?

if [ $TEST_EXIT -ne 0 ]; then
  echo
  echo "STOP: the single test upload failed (exit code $TEST_EXIT). Do NOT loop"
  echo "over the remaining files. Report the full command output above to me"
  echo "verbatim, including any error message, and stop here."
  exit 1
fi

echo
echo "Test upload succeeded. Proceeding to full upload of all files."
echo

count=0
failed=0
> upload-errors.log

for provider in "${PROVIDERS[@]}"; do
  for file in "$provider"/*.webp; do
    [ -e "$file" ] || continue
    key="$file"  # already in "{provider}/{code}.webp" form
    if [ "$file" == "$TEST_FILE" ]; then
      count=$((count+1))
      continue  # already uploaded above
    fi
    output=$(wrangler r2 object put "${BUCKET}/${key}" --file="$file" --content-type="image/webp" --remote 2>&1)
    if [ $? -eq 0 ]; then
      count=$((count+1))
    else
      echo "FAILED: $key" | tee -a upload-errors.log
      echo "$output" >> upload-errors.log
      failed=$((failed+1))
      # stop after 3 consecutive-looking failures so we don't repeat a
      # systemic error 1258 times again
      if [ "$failed" -ge 3 ]; then
        echo
        echo "STOP: 3 failures hit. Not continuing blindly. See upload-errors.log"
        echo "and report its contents verbatim."
        exit 1
      fi
    fi
    if (( count % 100 == 0 )); then
      echo "...${count} uploaded"
    fi
  done
done

echo "Done. Uploaded: ${count}, Failed: ${failed}"
