#!/bin/sh
# Install Overhead onto a stock tar1090 Pi (readsb + tar1090 already working).
#   curl -fsSL https://raw.githubusercontent.com/ncklrs/aviation/main/install.sh | sudo sh
#   or from a checkout: sudo ./install.sh        Options (env): NO_TIMER=1 NO_LOGGER=1 REPO_RAW=...
set -eu
[ "$(id -u)" = 0 ] || { echo "run as root (sudo)" >&2; exit 1; }
REPO_RAW=${REPO_RAW:-https://raw.githubusercontent.com/ncklrs/aviation/main}
PAGE_DIR=${PAGE_DIR:-/usr/local/share/tar1090/html}
[ -d "$PAGE_DIR" ] || { echo "tar1090 html dir not found: $PAGE_DIR (set PAGE_DIR=...)" >&2; exit 1; }
SRC=$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo /nonexistent)
get(){ if [ -f "$SRC/$1" ]; then cp "$SRC/$1" "$2"; else curl -fsSL "$REPO_RAW/$1" -o "$2"; fi; }

echo "== page"; get overhead.html "$PAGE_DIR/overhead.html"; chmod 0644 "$PAGE_DIR/overhead.html"

if [ -z "${NO_LOGGER:-}" ]; then
  echo "== logger"
  get pi/interesting_logger.py /usr/local/bin/interesting_logger.py; chmod 0755 /usr/local/bin/interesting_logger.py
  python3 /usr/local/bin/interesting_logger.py --selftest >/dev/null
  get pi/interesting-logger.service /etc/systemd/system/interesting-logger.service
  [ "$PAGE_DIR" = /usr/local/share/tar1090/html ] || sed -i "s|/usr/local/share/tar1090/html/ot/|$PAGE_DIR/ot/|" /etc/systemd/system/interesting-logger.service
  [ -f /etc/default/interesting-logger ] || get pi/interesting-logger.default /etc/default/interesting-logger
  # the logger only writes inside html/ot/ (owned by www-data); html/interesting.json is a symlink to it.
  install -d -o www-data -m 0755 "$PAGE_DIR/ot"
  [ -e "$PAGE_DIR/ot/interesting.json" ] || install -o www-data -m 0644 /dev/null "$PAGE_DIR/ot/interesting.json"
  [ -L "$PAGE_DIR/interesting.json" ] || { rm -f "$PAGE_DIR/interesting.json"; ln -s ot/interesting.json "$PAGE_DIR/interesting.json"; }
fi
if [ -z "${NO_TIMER:-}" ]; then
  echo "== nightly updater"
  get pi/overhead-update.sh /usr/local/bin/overhead-update.sh; chmod 0755 /usr/local/bin/overhead-update.sh
  get pi/overhead-update.service /etc/systemd/system/overhead-update.service
  get pi/overhead-update.timer /etc/systemd/system/overhead-update.timer
  [ -f /etc/default/overhead-update ] || printf 'REPO_RAW=%s\nPAGE_DIR=%s\n' "$REPO_RAW" "$PAGE_DIR" > /etc/default/overhead-update
fi
systemctl daemon-reload
[ -z "${NO_LOGGER:-}" ] && systemctl enable --now interesting-logger.service
[ -z "${NO_TIMER:-}" ] && systemctl enable --now overhead-update.timer
IP=$(hostname -I 2>/dev/null | cut -d' ' -f1)
echo "done: open http://${IP:-<pi>}/tar1090/overhead.html"
