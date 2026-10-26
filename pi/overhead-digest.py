#!/usr/bin/env python3
"""Weekly "Overhead" digest: summarises ot/stats.json + ot/interesting.json and posts it to ntfy.

Reads the topic/server from /etc/default/interesting-logger (NTFY_TOPIC / NTFY_SERVER) or the environment.
Does nothing when no topic is set.   --dry-run prints the summary instead of posting.
"""
import argparse, collections, json, os, sys, time, urllib.parse, urllib.request

OT = "/usr/local/share/tar1090/html/ot"
RARE = ("Hijack", "Emergency", "Radio", "Medevac", "Military", "PIA", "LADD", "Four", "Rare", "Very")

def env_file(path):
    d = {}
    try:
        for line in open(path):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1); d[k.strip()] = v.strip().strip('"').strip("'")
    except OSError: pass
    return d

def load(path, default):
    try:
        with open(path) as fh: return json.load(fh)
    except (OSError, ValueError): return default

def summary(stats, interesting, now=None):
    now = now or time.time()
    days = dict(sorted((stats.get("days") or {}).items())[-7:])
    lines = ["Overhead · week ending " + time.strftime("%a %b %-d", time.localtime(now))]
    if days:
        uniq = (stats.get("week") or {}).get("unique") or sum(d.get("unique", 0) for d in days.values())
        busy = max(days.items(), key=lambda kv: kv[1].get("unique", 0))
        lines.append(f"{uniq:,} unique aircraft · busiest day {time.strftime('%A', time.strptime(busy[0], '%Y-%m-%d'))} ({busy[1].get('unique', 0)})")
        far = max((d["far"] for d in days.values() if d.get("far")), key=lambda f: f["km"], default=None)
        if far: lines.append(f"Farthest: {far['id']} {far.get('t') or ''} at {far['km'] / 1.852:.0f} nm".replace("  ", " "))
        ty = collections.Counter()
        for d in days.values(): ty.update(d.get("types") or {})
        if ty: lines.append("Top types: " + ", ".join(f"{t} {n}" for t, n in ty.most_common(5)))
    else:
        lines.append("No logger stats yet.")
    log = [e for e in (interesting.get("aircraft") or []) if e.get("last", 0) > now - 7 * 86400]
    rare = [e for e in log if any(w.startswith(RARE) for w in e.get("why", []))]
    if rare:
        by = collections.Counter(w.split(" ")[0] for e in rare for w in e.get("why", [])[:1])
        lines.append("Interesting: " + ", ".join(f"{n} {k}" for k, n in by.most_common()))
        for e in sorted(rare, key=lambda e: e.get("last", 0), reverse=True)[:6]:
            lines.append(f" · {e.get('flight') or e.get('r') or e['hex']} {e.get('t') or ''} — {(e.get('why') or [''])[0]}")
    h = stats.get("health") or {}
    if h.get("state") == "quiet": lines.append("⚠ receiver currently quiet")
    return "\n".join(lines)

def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--dir", default=OT, help="logger output folder (default: %(default)s)")
    p.add_argument("--env", default="/etc/default/interesting-logger")
    p.add_argument("--dry-run", action="store_true", help="print the summary, don't post")
    o = p.parse_args()
    cfg = env_file(o.env)
    topic = (os.environ.get("NTFY_TOPIC") or cfg.get("NTFY_TOPIC") or "").strip()
    server = (os.environ.get("NTFY_SERVER") or cfg.get("NTFY_SERVER") or "https://ntfy.sh").rstrip("/")
    text = summary(load(os.path.join(o.dir, "stats.json"), {}), load(os.path.join(o.dir, "interesting.json"), {}))
    if o.dry_run: print(text); return 0
    if not topic: print("no NTFY_TOPIC set; nothing to do", file=sys.stderr); return 0
    req = urllib.request.Request(f"{server}/{urllib.parse.quote(topic)}", data=text.encode(), method="POST",
                                 headers={"Title": "Overhead weekly", "Tags": "airplane", "Priority": "low"})
    try: urllib.request.urlopen(req, timeout=15).close(); return 0
    except Exception as ex: print(f"ntfy failed: {ex}", file=sys.stderr); return 1

if __name__ == "__main__":
    sys.exit(main())
