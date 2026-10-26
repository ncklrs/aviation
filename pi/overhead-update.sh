#!/bin/sh
# Nightly self-update for Overhead. Downloads overhead.html (+ the logger) from the repo's raw branch,
# verifies each against its published .md5, keeps a .bak, and swaps atomically only when changed.
# Config (optional) in /etc/default/overhead-update:
#   REPO_RAW=https://raw.githubusercontent.com/ncklrs/aviation/main
#   PAGE_DIR=/usr/local/share/tar1090/html
#   LOGGER=/usr/local/bin/interesting_logger.py
set -eu
[ -r /etc/default/overhead-update ] && . /etc/default/overhead-update
REPO_RAW=${REPO_RAW:-https://raw.githubusercontent.com/ncklrs/aviation/main}
PAGE_DIR=${PAGE_DIR:-/usr/local/share/tar1090/html}
LOGGER=${LOGGER:-/usr/local/bin/interesting_logger.py}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
log(){ echo "overhead-update: $*"; }

# update <remote path> <local file>; returns 0 if the file was replaced
update(){
  src=$1; dst=$2; name=$(basename "$src")
  curl -fsSL --max-time 60 "$REPO_RAW/$src" -o "$TMP/$name" || { log "download failed: $src"; return 1; }
  curl -fsSL --max-time 30 "$REPO_RAW/$src.md5" -o "$TMP/$name.md5" || { log "no md5 for $src, skipping"; return 1; }
  want=$(cut -d' ' -f1 < "$TMP/$name.md5"); got=$(md5sum "$TMP/$name" | cut -d' ' -f1)
  [ -n "$want" ] && [ "$want" = "$got" ] || { log "md5 mismatch for $src ($got != $want), keeping current"; return 1; }
  if [ -f "$dst" ] && [ "$(md5sum "$dst" | cut -d' ' -f1)" = "$got" ]; then log "$src unchanged"; return 1; fi
  [ -f "$dst" ] && cp -p "$dst" "$dst.bak"
  install -m 0644 "$TMP/$name" "$dst.new" && mv -f "$dst.new" "$dst"   # same-dir rename = atomic
  log "updated $dst -> $got"; return 0
}

update overhead.html "$PAGE_DIR/overhead.html" || true

# keep the logger layout intact: html/ot/ (www-data) + html/interesting.json -> ot/interesting.json
install -d -o www-data -m 0755 "$PAGE_DIR/ot"
[ -e "$PAGE_DIR/interesting.json" ] || [ -L "$PAGE_DIR/interesting.json" ] || ln -s ot/interesting.json "$PAGE_DIR/interesting.json"

RESTART=
if update pi/interesting-logger.service /etc/systemd/system/interesting-logger.service; then
  [ "$PAGE_DIR" = /usr/local/share/tar1090/html ] || sed -i "s|/usr/local/share/tar1090/html/ot/|$PAGE_DIR/ot/|" /etc/systemd/system/interesting-logger.service
  systemctl daemon-reload; RESTART=1
fi
if update pi/interesting_logger.py "$LOGGER"; then
  chmod 0755 "$LOGGER"
  if python3 "$LOGGER" --selftest >/dev/null; then RESTART=1
  else log "new logger failed selftest, restoring backup"; mv -f "$LOGGER.bak" "$LOGGER"; fi
fi
[ -n "$RESTART" ] && { systemctl try-restart interesting-logger.service && log "logger restarted" || log "logger restart failed"; }
exit 0
