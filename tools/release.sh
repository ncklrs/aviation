#!/bin/sh
# Regenerate the .md5 files the Pi updater verifies against. Run from the repo root before committing.
set -eu
cd "$(dirname "$0")/.."
python3 pi/interesting_logger.py --selftest >/dev/null || { echo "logger selftest failed" >&2; exit 1; }
python3 pi/overhead-digest.py --dry-run --dir /nonexistent --env /dev/null >/dev/null || { echo "digest dry-run failed" >&2; exit 1; }
sh -n pi/overhead-update.sh && sh -n install.sh
for f in overhead.html pi/interesting_logger.py pi/interesting-logger.service pi/overhead-digest.py \
         pi/overhead-digest.service pi/overhead-digest.timer pi/overhead-update.sh pi/overhead-update.service pi/overhead-update.timer; do
  md5sum "$f" | sed "s|  .*|  $(basename "$f")|" > "$f.md5"; echo "$(cat "$f.md5")"
done
