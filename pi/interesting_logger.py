#!/usr/bin/env python3
"""Log "interesting" aircraft from a readsb/tar1090 aircraft.json into a rolling
7-day interesting.json that the Overhead page reads. Python 3 stdlib only.

  interesting_logger.py --src http://127.0.0.1/tar1090/data/aircraft.json \
                        --out /usr/local/share/tar1090/html/ot/interesting.json
  --src may also be a file path (e.g. /run/readsb/aircraft.json). --once = single poll (cron).
"""
import argparse, json, os, re, sys, tempfile, time, urllib.parse, urllib.request

COMMON = set("""C150 C152 C162 C170 C172 C175 C177 C182 C206 C208 C210 P28A P28B P28R P28T PA28 PA32 PA34 PA44 P32R
SR20 SR22 S22T DA40 DA42 DA20 BE35 BE33 BE36 BE55 BE58 BE76 BE9L BE20 BE30 PC12 TBM7 TBM8 TBM9 M20P M20T
C25A C25B C25C C510 C525 C550 C560 C56X C680 C68A C700 C750 E50P E55P LJ35 LJ45 LJ60 LJ75 CL30 CL35 CL60 GLEX
GL5T GL7T G280 GLF4 GLF5 GLF6 FA50 FA7X F2TH F900 H25B PC24 HDJT CRJ2 CRJ7 CRJ9 CRJX E135 E145 E170 E75L E75S
E190 E195 E290 E295 DH8A DH8B DH8C DH8D AT72 AT76 AT45 B712 B733 B734 B735 B736 B737 B738 B739 B37M B38M B39M
B3XM A318 A319 A320 A321 A19N A20N A21N BCS1 BCS3 B752 B753 A332 A333 A339 A359 A35K B762 B763 B764 B772 B77L
B773 B77W B788 B789 B78X""".split())
WIDE = re.compile(r"^(A3[3-5]|A38|B7[4678]|B77|B78|MD11|DC10|IL96|A124|C5M|C17$)")
QUAD = re.compile(r"^(A34|A38|B74|A124|C5M|IL96|B52|K35R|E3)")
HELI = re.compile(r"^(R22|R44|R66|EC|H[0-9]|AS[0-9]|B06|B407|B412|B429|A109|A119|A139|A169|S76|S92|UH|AH|CH|MH|H60|H47|H64|BK17|MD[56]|EN28|EN48|V22)")
# Medevac: generic public signals only (no local lists).
# 1) operator/owner text from the tar1090 db (ownOp) or desc naming an air-ambulance operator/program
MED_OP = re.compile(r"air ?methods|\bphi\b|phi (air|health|medical)|metro aviation|med[- ]?trans|life ?flight|life ?net|"
                    r"life ?star|life ?line|care ?flight|survival flight|med ?flight|air ?evac|mercy|university hospitals|"
                    r"cleveland clinic|hospital|health ?system|medical|medevac|air ambulance|angel ?flight|guardian flight|"
                    r"reach air|stat ?medevac|lifeguard", re.I)
# 2) callsign patterns used by US air-ambulance flights; only trusted on rotorcraft (or with a 'medical' operator).
#    Note RCH### is the military 'Reach' (AMC) callsign and is excluded explicitly.
MED_CS = re.compile(r"^(LN\d|LIFE|LFLT|MERCY|CARE|STAT\d|GUARD|MEDEVAC|MEDIC|EVAC|ANGEL|AMC\d|AIRMETHODS|MDS\d|PHI\d|"
                    r"PHM|AMF|LFL|REACH\d|SVF|MTC\d)", re.I)
MIL_CS = re.compile(r"^(RCH|REACH\d{3})", re.I)

def is_rotor(a):
    t = (a.get("t") or "").upper()
    return a.get("category") == "A7" or bool(t and HELI.match(t) and not t.startswith("V22"))

def is_medevac(a):
    if (a.get("dbFlags") or 0) & 1: return False          # military in db stays Military
    fl = (a.get("flight") or "").strip().replace(" ", "")
    if MIL_CS.match(fl) and not is_rotor(a): return False   # RCH431 C-17 etc.
    if MED_OP.search(" ".join(str(a.get(k) or "") for k in ("ownOp", "desc"))): return True
    return is_rotor(a) and bool(fl and MED_CS.match(fl))
SQ = {"7500": "Hijack 7500", "7600": "Radio failure 7600", "7700": "Emergency 7700"}

def alt(a):
    for k in ("alt_baro", "alt_geom"):
        if isinstance(a.get(k), (int, float)): return a[k]
    return 0

def why(a):
    w, f, t = [], a.get("dbFlags") or 0, (a.get("t") or "").upper()
    sq = str(a.get("squawk") or "")
    if sq in SQ: w.append(SQ[sq])
    elif a.get("emergency") not in (None, "none"): w.append("Emergency")
    if f & 1: w.append("Military")
    if f & 2: w.append("Flagged interesting")
    if f & 4: w.append("PIA")
    if f & 8: w.append("LADD")
    if a.get("category") == "A7" or (t and HELI.match(t)): w.append("Helicopter")
    if QUAD.match(t): w.append("Four-engine")
    elif WIDE.match(t): w.append("Widebody")
    if alt(a) > 45000: w.append("Very high")
    if (a.get("gs") or 0) > 550: w.append("Very fast")
    if t and t not in COMMON and "Helicopter" not in w and "Military" not in w: w.append("Rare type")
    if is_medevac(a): w.insert(0 if not (w and w[0] in SQ.values() or w[:1] == ["Emergency"]) else 1, "Medevac")
    return w

def sort_why(w):
    """Medevac first (after any squawk emergency), de-duplicated."""
    w = list(dict.fromkeys(w))
    if "Medevac" in w:
        w.remove("Medevac"); w.insert(1 if w and (w[0] in SQ.values() or w[0] == "Emergency") else 0, "Medevac")
    return w

def selftest():
    cases = [
        ({"hex": "ae0001", "flight": "RCH431 ", "t": "C17", "category": "A5", "dbFlags": 1, "ownOp": "United States Air Force"}, "Military", "Medevac"),
        ({"hex": "a00001", "flight": "RCH431", "t": "C17", "category": "A5"}, None, "Medevac"),
        ({"hex": "a00002", "flight": "LN2", "t": "EC35", "category": "A7"}, "Medevac", None),
        ({"hex": "a00003", "flight": "N123AB", "t": "A109", "category": "A7", "ownOp": "Air Methods Corp"}, "Medevac", None),
        ({"hex": "a00004", "flight": "N12345", "t": "C172", "category": "A1"}, None, "ANY"),
        ({"hex": "a00005", "flight": "LN2", "t": "C172", "category": "A1"}, None, "Medevac"),
        ({"hex": "a00006", "flight": "N1", "t": "EC35", "category": "A7", "squawk": "7700", "ownOp": "PHI Inc"}, "Medevac", None),
    ]
    ok = True
    for a, want, notwant in cases:
        w = sort_why(why(a))
        good = (want is None or want in w) and (notwant != "ANY" or not w) and (notwant in (None, "ANY") or notwant not in w)
        if a["hex"] in ("a00002", "a00003"): good = good and w[0] == "Medevac"
        if a["hex"] == "a00006": good = good and w[:2] == ["Emergency 7700", "Medevac"]
        ok &= good
        print(("PASS" if good else "FAIL"), (a.get("flight") or "").strip(), a.get("t"), a.get("ownOp", ""), "->", w)
    calls = []
    real = urllib.request.urlopen
    urllib.request.urlopen = lambda req, timeout=0: calls.append(req) or type("R", (), {"close": lambda s: None})()
    try:
        heli = {"hex": "a00002", "flight": "LN2", "t": "EC35", "category": "A7"}
        w = sort_why(why(heli))
        r1 = ntfy("https://ntfy.example", "t", heli, w, 1000, ALERT_DEFAULT.split(","))
        r2 = ntfy("https://ntfy.example", "t", heli, w, 1000 + 3600, ALERT_DEFAULT.split(","))
        r3 = ntfy("https://ntfy.example", "t", heli, w, 1000 + 6 * 3600 + 1, ALERT_DEFAULT.split(","))
        r4 = ntfy("https://ntfy.example", "t", {"hex": "a00009", "t": "DHC2"}, ["Rare type"], 1000, ALERT_DEFAULT.split(","))
        good = (r1, r2, r3, r4) == (True, False, True, False) and len(calls) == 2
    finally:
        urllib.request.urlopen = real; _sent.clear()
    ok &= good
    print("PASS" if good else "FAIL", "ntfy: 1 alert per aircraft per 6h, Rare type not alerted")
    ok &= selftest_tracker()
    print("selftest", "OK" if ok else "FAILED")
    return ok

ALERT_DEFAULT = "Emergency,Hijack,Radio,Medevac,Military,Helicopter"
_sent = {}   # hex -> last alert epoch (in memory; restarts may re-alert once)

def alert_tags(w, wanted):
    return [x for x in w if any(x.startswith(k) for k in wanted)]

def ntfy(server, topic, a, w, now, wanted, every=6 * 3600):
    """POST one plain-text notification per aircraft per `every` seconds. Never raises."""
    hx = a.get("hex")
    hits = alert_tags(w, wanted)
    if not (topic and hx and hits) or (hx in _sent and now - _sent[hx] < every): return False
    _sent[hx] = now
    ident = (a.get("flight") or "").strip() or a.get("r") or ("#" + hx.upper())
    body = f"{ident} {a.get('t') or ''} {a.get('desc') or ''}".strip() + f"\n{' · '.join(w)}"
    if isinstance(alt(a), (int, float)) and alt(a): body += f"\n{int(alt(a))} ft"
    prio = "high" if any(h.startswith(("Emergency", "Hijack", "Radio")) for h in hits) else "default"
    req = urllib.request.Request(server.rstrip("/") + "/" + urllib.parse.quote(topic), data=body.encode(), method="POST",
                                 headers={"Title": f"Overhead: {hits[0]}", "Priority": prio, "Tags": "airplane"})
    try:
        urllib.request.urlopen(req, timeout=10).close(); return True
    except Exception as ex:
        print(f"ntfy failed: {ex}", file=sys.stderr); return False

def fetch(src):
    if re.match(r"https?://", src):
        with urllib.request.urlopen(src, timeout=10) as r: return json.load(r)
    with open(src) as fh: return json.load(fh)

def load(out):
    try:
        with open(out) as fh: return json.load(fh).get("aircraft", [])
    except (OSError, ValueError): return []

def save(out, log, now):
    d = os.path.dirname(os.path.abspath(out))
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".interesting.")
    with os.fdopen(fd, "w") as fh: json.dump({"now": now, "days": 7, "aircraft": log}, fh, separators=(",", ":"))
    os.chmod(tmp, 0o644); os.replace(tmp, out)

# ---------------- stats / health / heat (all aircraft) ----------------
import math
DAYS_KEPT, HEX_CAP, HEAT_CAP, HEAT_RADIUS_KM, HEAT_HALF_LIFE_D = 8, 20000, 30000, 400, 7.0

def dist_km(home, a):
    if not home or a.get("lat") is None or a.get("lon") is None: return None
    la1, lo1, la2, lo2 = map(math.radians, (home[0], home[1], a["lat"], a["lon"]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * 6371.0 * math.asin(min(1, math.sqrt(h)))

def offset_km(home, a):
    """east/north offset from home in km (flat approximation; only offsets are ever stored)."""
    if not home or a.get("lat") is None or a.get("lon") is None: return None
    dy = (a["lat"] - home[0]) * 111.195
    dx = (a["lon"] - home[1]) * 111.195 * math.cos(math.radians(home[0]))
    return dx, dy

def load_json(path, default):
    try:
        with open(path) as fh: return json.load(fh)
    except (OSError, ValueError): return default

def save_json(path, obj):
    d = os.path.dirname(os.path.abspath(path))
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".ot.")
    with os.fdopen(fd, "w") as fh: json.dump(obj, fh, separators=(",", ":"))
    os.chmod(tmp, 0o644); os.replace(tmp, path)

class Tracker:
    """Rolling per-day stats for every aircraft, receiver health, and a decaying relative heat grid."""
    def __init__(self, outdir, home=None, quiet_min=15, min_rate=1.0, cell_km=1.0, notify=None, persist=True):
        self.outdir, self.home, self.quiet_s, self.min_rate, self.cell = outdir, home, quiet_min * 60, min_rate, cell_km
        self.notify, self.persist = notify, persist
        self.state_p = os.path.join(outdir, ".stats-state.json")
        st = load_json(self.state_p, {}) if persist else {}
        self.days = st.get("days", {})                       # day -> {hex:[...], hours, types, far, msgs}
        self.samples = st.get("samples", [])                 # [t, msgs/s, aircraft] last 24h
        self.health = st.get("health", {"state": "ok", "since": None, "alerted": False})
        self.heat = st.get("heat", {})                       # "dx,dy" -> weight (km cells, offsets from home)
        self.heat_t = st.get("heat_t", 0)
        self.last_msgs = None

    def update(self, data, now):
        ac = data.get("aircraft", [])
        live = [a for a in ac if (a.get("seen") or 0) <= 60]
        k = time.strftime("%Y-%m-%d", time.localtime(now)); hr = time.localtime(now).tm_hour
        D = self.days.setdefault(k, {"hex": [], "hours": [0] * 24, "types": {}, "far": None})
        seen = set(D["hex"])
        for a in live:
            hx = a.get("hex")
            if not hx: continue
            if hx not in seen and len(D["hex"]) < HEX_CAP:
                seen.add(hx); D["hex"].append(hx); D["hours"][hr] += 1
                t = (a.get("t") or "").upper()
                if t: D["types"][t] = D["types"].get(t, 0) + 1
            if (a.get("seen_pos") or 0) <= 60:
                d = dist_km(self.home, a)
                if d is not None and d < 700 and (not D["far"] or d > D["far"]["km"]):
                    D["far"] = {"km": round(d, 1), "id": (a.get("flight") or "").strip() or a.get("r") or hx, "t": a.get("t") or ""}
                o = offset_km(self.home, a)
                if o and math.hypot(*o) <= HEAT_RADIUS_KM:
                    c = f"{int(math.floor(o[0] / self.cell))},{int(math.floor(o[1] / self.cell))}"
                    self.heat[c] = self.heat.get(c, 0) + 1
        for old in sorted(self.days)[:-DAYS_KEPT]: del self.days[old]
        # message rate from readsb's cumulative counter
        msgs, rate = data.get("messages"), None
        if isinstance(msgs, (int, float)):
            if self.last_msgs and now > self.last_msgs[0] and msgs >= self.last_msgs[1]:
                rate = (msgs - self.last_msgs[1]) / (now - self.last_msgs[0])
            self.last_msgs = (now, msgs)
        if rate is not None and (not self.samples or now - self.samples[-1][0] >= 290):
            self.samples.append([int(now), round(rate, 1), len(live)])
        self.samples = [s for s in self.samples if s[0] > now - 86400][-300:]
        self._health(now, rate, len(live))
        self._decay(now)

    def _health(self, now, rate, n):
        h = self.health
        quiet = n == 0 or (rate is not None and rate < self.min_rate)
        h.update({"rate": None if rate is None else round(rate, 1), "aircraft": n, "updated": int(now)})
        if quiet:
            h.setdefault("quiet_from", now)
            if now - h["quiet_from"] >= self.quiet_s and h.get("state") != "quiet":
                h["state"], h["since"] = "quiet", int(h["quiet_from"])
                if self.notify: self.notify("Receiver quiet", f"{n} aircraft, {h['rate']} msg/s for {int((now - h['quiet_from']) // 60)} min")
        else:
            h.pop("quiet_from", None)
            if h.get("state") == "quiet":
                h["state"], h["since"] = "ok", int(now)
                if self.notify: self.notify("Receiver recovered", f"{n} aircraft, {h['rate']} msg/s")
            if h.get("since") is None: h["since"] = int(now)

    def _decay(self, now):
        if not self.heat_t: self.heat_t = now
        dt = now - self.heat_t
        if dt < 3600: return
        f = 0.5 ** (dt / 86400 / HEAT_HALF_LIFE_D)
        self.heat = {c: round(w * f, 2) for c, w in self.heat.items() if w * f >= 0.05}
        if len(self.heat) > HEAT_CAP:
            self.heat = dict(sorted(self.heat.items(), key=lambda kv: -kv[1])[:HEAT_CAP])
        self.heat_t = now

    def stats_doc(self, now):
        days = {}
        for k, D in sorted(self.days.items()):
            days[k] = {"unique": len(D["hex"]), "hours": D["hours"], "far": D["far"],
                       "types": dict(sorted(D["types"].items(), key=lambda kv: -kv[1])[:40])}
        week = set()
        for k in sorted(self.days)[-7:]: week.update(self.days[k]["hex"])
        return {"now": int(now), "version": 1, "dist_unit": "km", "days": days, "week": {"unique": len(week)},
                "samples": self.samples, "health": {k: v for k, v in self.health.items() if k != "alerted"}}

    def heat_doc(self, now):
        return {"now": int(now), "cell_km": self.cell, "half_life_days": HEAT_HALF_LIFE_D,
                "note": "east,north cell offsets from the receiver; no absolute coordinates",
                "cells": [[int(c.split(",")[0]), int(c.split(",")[1]), w] for c, w in self.heat.items()]}

    def save(self, now):
        if not self.persist: return
        save_json(os.path.join(self.outdir, "stats.json"), self.stats_doc(now))
        save_json(os.path.join(self.outdir, "heat.json"), self.heat_doc(now))
        save_json(self.state_p, {"days": self.days, "samples": self.samples, "health": self.health,
                                 "heat": self.heat, "heat_t": self.heat_t})

def receiver_home(src):
    """lat/lon from receiver.json next to aircraft.json (never written anywhere by this script)."""
    try:
        r = fetch(re.sub(r"aircraft\.json(\?.*)?$", "receiver.json", src))
        if r.get("lat") is not None and r.get("lon") is not None: return (float(r["lat"]), float(r["lon"]))
    except Exception: pass
    return None

def ntfy_text(server, topic, title, body, prio="default"):
    if not topic: return False
    req = urllib.request.Request(server.rstrip("/") + "/" + urllib.parse.quote(topic), data=body.encode(), method="POST",
                                 headers={"Title": title, "Priority": prio, "Tags": "satellite"})
    try: urllib.request.urlopen(req, timeout=10).close(); return True
    except Exception as ex: print(f"ntfy failed: {ex}", file=sys.stderr); return False

def selftest_tracker():
    ok = True; sent = []
    home = (40.0, -100.0)                                 # arbitrary test point
    T = Tracker("/nonexistent", home=home, quiet_min=15, min_rate=1.0, notify=lambda t, b: sent.append(t), persist=False)
    t0 = 1_800_000_000
    mk = lambda hx, dlat, t="B738", fl="TST1": {"hex": hx, "lat": 40.0 + dlat, "lon": -100.0, "t": t, "flight": fl, "seen": 1, "seen_pos": 1}
    T.update({"messages": 0, "aircraft": [mk("a1", 0.5), mk("a2", 1.0, "C172", "N1")]}, t0)
    T.update({"messages": 6000, "aircraft": [mk("a1", 0.5), mk("a2", 1.0, "C172", "N1"), mk("a3", 2.0, "B738", "FAR9")]}, t0 + 30)
    s = T.stats_doc(t0 + 30); d = list(s["days"].values())[-1]
    g = d["unique"] == 3 and sum(d["hours"]) == 3 and d["types"].get("B738") == 2 and d["far"]["id"] == "FAR9" \
        and abs(d["far"]["km"] - 222.4) < 1 and s["week"]["unique"] == 3 and s["samples"][-1][1] == 200.0
    print("PASS" if g else "FAIL", "stats: unique/hourly/types/farthest/msg-rate", d["unique"], d["far"], s["samples"][-1:]); ok &= g
    # health: 16 min with zero aircraft -> one 'quiet', then one 'recovered'
    m = 6000
    for i in range(1, 40):
        m += 0; T.update({"messages": m, "aircraft": []}, t0 + 30 + i * 30)
    q = T.health["state"] == "quiet" and sent == ["Receiver quiet"]
    for i in range(3):
        m += 3000; T.update({"messages": m, "aircraft": [mk("a1", 0.5)]}, t0 + 1300 + i * 30)
    g = q and T.health["state"] == "ok" and sent == ["Receiver quiet", "Receiver recovered"]
    print("PASS" if g else "FAIL", "health: one quiet alert after 15 min, one recovered", sent); ok &= g
    # heat: only relative integer cells, decays
    h = T.heat_doc(t0); cells = {(c[0], c[1]) for c in h["cells"]}
    g1 = (0, 55) in cells and all(isinstance(c[0], int) and abs(c[0]) <= HEAT_RADIUS_KM for c in h["cells"]) \
        and "lat" not in json.dumps(h)
    w0 = sum(c[2] for c in h["cells"]); T._decay(T.heat_t + 7 * 86400); w1 = sum(T.heat.values())
    g = g1 and abs(w1 - w0 / 2) < 0.6
    print("PASS" if g else "FAIL", "heat: relative 1 km cells, no coordinates, 7-day half-life", sorted(cells)[:3], w0, w1); ok &= g
    return ok

def poll(src, out, max_seen, alerts=None, tracker=None):
    data = fetch(src); now = data.get("now") or time.time()
    day = time.strftime("%Y-%m-%d", time.gmtime(now))
    log = [e for e in load(out) if e.get("last", 0) > now - 7 * 86400]
    idx = {(e["hex"], e["day"]): e for e in log}
    for a in data.get("aircraft", []):
        if not a.get("hex") or (a.get("seen") or 0) > max_seen: continue
        w = why(a)
        if not w: continue
        e = idx.get((a["hex"], day))
        if e is None:
            e = idx[(a["hex"], day)] = {"hex": a["hex"], "day": day, "first": now, "why": []}
            log.append(e)
        for k in ("r", "t", "desc", "ownOp", "category", "track"):
            if a.get(k) is not None: e[k] = a[k]
        fl = (a.get("flight") or "").strip()
        if fl: e["flight"] = fl
        e["last"] = now
        e["maxAlt"] = max(e.get("maxAlt", 0), alt(a))
        e["maxGs"] = max(e.get("maxGs", 0), a.get("gs") or 0)
        e["why"] = sort_why(e["why"] + w)
        if alerts: ntfy(alerts["server"], alerts["topic"], a, e["why"], now, alerts["tags"])
    save(out, log, now)
    if tracker:
        try: tracker.update(data, now); tracker.save(now)
        except Exception as ex: print(f"stats failed: {ex}", file=sys.stderr)
    return len(log)

def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--src", default="http://127.0.0.1/tar1090/data/aircraft.json")
    p.add_argument("--out", default="/usr/local/share/tar1090/html/ot/interesting.json")
    p.add_argument("--interval", type=float, default=30)
    p.add_argument("--max-seen", type=float, default=60, help="ignore aircraft not heard for this many seconds")
    p.add_argument("--once", action="store_true")
    p.add_argument("--ntfy-topic", default=os.environ.get("NTFY_TOPIC", ""),
                   help="ntfy topic for push alerts (default: $NTFY_TOPIC; off when empty)")
    p.add_argument("--ntfy-server", default=os.environ.get("NTFY_SERVER") or "https://ntfy.sh")
    p.add_argument("--ntfy-tags", default=os.environ.get("NTFY_TAGS") or ALERT_DEFAULT,
                   help="comma list of 'why' prefixes that alert (default: %(default)s)")
    p.add_argument("--no-stats", action="store_true", help="don't write stats.json / heat.json")
    p.add_argument("--quiet-minutes", type=float, default=float(os.environ.get("QUIET_MINUTES") or 15),
                   help="alert 'receiver quiet' after this long with 0 aircraft or a low message rate")
    p.add_argument("--min-rate", type=float, default=float(os.environ.get("MIN_MSG_RATE") or 1.0),
                   help="messages/s below which the receiver counts as quiet")
    p.add_argument("--heat-cell-km", type=float, default=1.0)
    p.add_argument("--selftest", action="store_true", help="run built-in checks and exit")
    o = p.parse_args()
    if o.selftest: sys.exit(0 if selftest() else 1)
    alerts = {"topic": o.ntfy_topic.strip(), "server": o.ntfy_server,
              "tags": [t.strip() for t in o.ntfy_tags.split(",") if t.strip()]} if o.ntfy_topic.strip() else None
    tracker = None
    if not o.no_stats:
        topic = o.ntfy_topic.strip()
        notify = (lambda t, b: ntfy_text(o.ntfy_server, topic, "Overhead: " + t, b)) if topic else None
        tracker = Tracker(os.path.dirname(os.path.abspath(o.out)), home=receiver_home(o.src), quiet_min=o.quiet_minutes,
                          min_rate=o.min_rate, cell_km=o.heat_cell_km, notify=notify)
    while True:
        if tracker and tracker.home is None: tracker.home = receiver_home(o.src)
        try: n = poll(o.src, o.out, o.max_seen, alerts, tracker)
        except Exception as ex: print(f"poll failed: {ex}", file=sys.stderr); n = None
        if o.once: sys.exit(0 if n is not None else 1)
        time.sleep(o.interval)

if __name__ == "__main__":
    main()
