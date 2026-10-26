#!/bin/sh
# Regenerate the .md5 files the Pi updater verifies against. Run from the repo root before committing.
set -eu
cd "$(dirname "$0")/.."
python3 pi/interesting_logger.py --selftest >/dev/null || { echo "logger selftest failed" >&2; exit 1; }
for f in overhead.html pi/interesting_logger.py pi/interesting-logger.service; do
  md5sum "$f" | sed "s|  .*|  $(basename "$f")|" > "$f.md5"; echo "$(cat "$f.md5")"
done
