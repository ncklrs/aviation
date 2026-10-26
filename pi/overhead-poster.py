#!/usr/bin/env python3
"""Daily sky poster for Overhead. Python 3 stdlib only.

Reads the day's relative tracks the logger keeps in ot/.tracks/YYYY-MM-DD.json (east/north km offsets from
the receiver, never coordinates) and renders ot/posters/YYYY-MM-DD.svg: every flight path as thin line art on
cream, heavier for rarer types, small drawings of the day's best sightings, a date title and one stats line.
No map, no place names, no receiver marker; the drawing is fitted to the tracks' own extent.
Keeps 365 posters and an index.json for the page's archive grid (?view=posters).

  overhead-poster.py [--dir /usr/local/share/tar1090/html/ot] [--date YYYY-MM-DD] [--page overhead.html]
  overhead-poster.py --demo --out sample-poster.svg     # synthetic day, nothing read
  overhead-poster.py --selftest
"""
import argparse, json, math, os, random, re, sys, tempfile, time

CREAM, INK = "#f4efe4", "#111"
W, H = 1200, 1600
KEEP = 365
RANK = {"Common": 0, "Uncommon": 1, "Rare": 2, "Epic": 3, "Legendary": 4}
STROKE = {"Common": .55, "Uncommon": .9, "Rare": 1.5, "Epic": 2.2, "Legendary": 3.0}
OPAC = {"Common": .45, "Uncommon": .6, "Rare": .85, "Epic": 1, "Legendary": 1}
LEGENDARY = re.compile(r"^(V22|H47|CH47|B52|U2|E4|E4B|E6|VC25|A124|AN124|A225|AN22|B1|B1B|B2|E3TF|E3CF|R135|E8|C5M|SR71|BLCF|A3ST|A337|B742|CONI|B17|B29|DC3|C47|SPIT|P51|CORS|ZEP)$")

def load_json(p, d):
    try:
        with open(p) as fh: return json.load(fh)
    except (OSError, ValueError): return d

def write_atomic(path, text):
    d = os.path.dirname(os.path.abspath(path)); os.makedirs(d, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".poster.")
    with os.fdopen(fd, "w") as fh: fh.write(text)
    os.chmod(tmp, 0o644); os.replace(tmp, path)

def esc(s): return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")

def page_shapes(page):
    """Reuse the page's own line drawings + type->class table so there is one source of truth."""
    try: s = open(page).read()
    except OSError: return {}, []
    m = re.search(r"const SHAPES = \{\n(.*?)\n\};", s, re.S)
    shapes = {k: v.strip().strip("'").replace("'+'", "") for k, v in re.findall(r"^\s{2}'?([\w-]+)'?:\n\s{4}(.*?),?$", m.group(1), re.M)} if m else {}
    t = re.search(r"const TYPES = \[\n(.*?)\n\];", s, re.S)
    types = []
    for rx, cls in re.findall(r"\[/(.+?)/,'([\w-]+)'\]", t.group(1) if t else ""):
        try: types.append((re.compile(rx), cls))
        except re.error: pass
    return shapes, types

WIDE = re.compile(r"^(A3[3-5]|A38|B7[4678]|B77|B78|MD11|DC10|IL96|A124|C5M|C17$)")
def shape_for(t, rotor, types):
    t = (t or "").upper()
    if t and not re.match(r"^(C17|C5M)$", t) and WIDE.match(t): return "widebody"
    for rx, cls in types:
        if t and rx.match(t): return cls
    return "heli" if rotor else "airliner"

def rarity_of(e, coll):
    t = (e.get("t") or "").upper()
    c = (coll.get("types") or {}).get(t)
    if c and c.get("rarity") in RANK: return c["rarity"]
    if t and LEGENDARY.match(t): return "Legendary"
    if e.get("mil") or e.get("rotor"): return "Epic"
    return "Common"

def render(day, tracks, coll=None, shapes=None, types=None):
    coll, shapes, types = coll or {}, shapes or {}, types or []
    T = [dict(e, hx=h, rar=rarity_of(e, coll)) for h, e in tracks.items() if len(e.get("p") or []) >= 2]
    dt = time.strptime(day, "%Y-%m-%d")
    title = time.strftime("%A ", dt) + str(dt.tm_mday) + time.strftime(" %B %Y", dt)
    n = len(tracks)
    pts = [p for e in T for p in e["p"]]
    far = max((math.hypot(*p) for p in pts), default=0)
    top = sorted(T, key=lambda e: (-RANK[e["rar"]], e.get("dmin") if e.get("dmin") is not None else 1e9))
    rarest = top[0] if top else None
    # fit to the tracks' own bounding box (not centred on the receiver)
    box = (90, 250, W - 90, 1220)
    if pts:
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        k = min((box[2] - box[0]) / max(x1 - x0, 1), (box[3] - box[1]) / max(y1 - y0, 1))
        ox = box[0] + ((box[2] - box[0]) - (x1 - x0) * k) / 2; oy = box[1] + ((box[3] - box[1]) - (y1 - y0) * k) / 2
        X = lambda x: ox + (x - x0) * k; Y = lambda y: oy + (y1 - y) * k
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" class="skyposter" viewBox="0 0 {W} {H}" width="{W}" height="{H}" data-date="{day}">',
         f'<title>Overhead sky poster, {esc(title)}</title>',
         '<style>.trk{fill:none;stroke:%s;stroke-linecap:round;stroke-linejoin:round}.pl path.tr{fill:%s;stroke:none;fill-rule:evenodd}'
         '.pl path.bg{fill:%s;stroke:none}text{fill:%s;font-family:Georgia,"Times New Roman",serif}.sans{font-family:Helvetica,Arial,sans-serif;letter-spacing:.22em}</style>' % (INK, INK, CREAM, INK),
         f'<rect class="poster-bg" width="{W}" height="{H}" fill="{CREAM}"/>',
         f'<rect x="40" y="40" width="{W-80}" height="{H-80}" fill="none" stroke="{INK}" stroke-width="1.5"/>',
         f'<text x="{W/2}" y="150" text-anchor="middle" font-size="64" font-style="italic">{esc(title)}</text>',
         f'<text class="sans" x="{W/2}" y="200" text-anchor="middle" font-size="18">THE SKY OVERHEAD · {n} AIRCRAFT</text>']
    o.append('<g class="tracks">')
    for e in sorted(T, key=lambda e: RANK[e["rar"]]):
        d = "M" + " L".join(f"{X(x):.1f} {Y(y):.1f}" for x, y in e["p"])
        o.append(f'<path class="trk r-{e["rar"].lower()}" d="{d}" stroke-width="{STROKE[e["rar"]]}" stroke-opacity="{OPAC[e["rar"]]}"/>')
    o.append('</g>')
    if not T:
        o.append(f'<text x="{W/2}" y="{(box[1]+box[3])/2}" text-anchor="middle" font-size="40" font-style="italic">Quiet skies</text>')
    # best sightings strip: up to 4 distinct types, rarest first, then closest
    best, seen = [], set()
    for e in top:
        if e.get("t") and e["t"] not in seen and (RANK[e["rar"]] >= 1 or len(best) < 2): best.append(e); seen.add(e["t"])
        if len(best) == 4: break
    o.append(f'<line x1="90" y1="1265" x2="{W-90}" y2="1265" stroke="{INK}" stroke-width="1"/>')
    o.append(f'<text class="sans" x="90" y="1300" font-size="16">BEST SIGHTINGS</text>')
    cw = (W - 180) / 4
    for i, e in enumerate(best):
        cx = 90 + cw * i; k = shape_for(e.get("t"), e.get("rotor"), types); s = shapes.get(k, "")
        if s: o.append(f'<g class="pl" transform="translate({cx + 10:.0f} 1315) scale({(cw - 30) / 200:.3f})">{s}</g>')
        o.append(f'<text x="{cx + 10:.0f}" y="1440" font-size="28">{esc(e["t"])}</text>')
        o.append(f'<text class="sans" x="{cx + 10:.0f}" y="1468" font-size="13">{e["rar"].upper()}{" · " + esc(e["id"]) if e.get("id") else ""}</text>')
        if e.get("dmin") is not None: o.append(f'<text x="{cx + 10:.0f}" y="1494" font-size="18" font-style="italic">closest {e["dmin"]:.1f} km</text>')
    stats = f'{n} aircraft' + (f' · rarest {rarest["t"]} ({rarest["rar"]})' if rarest and rarest.get("t") else "") + (f' · farthest {far:.0f} km' if far else "")
    o.append(f'<text class="sans" x="{W/2}" y="1540" text-anchor="middle" font-size="16">{esc(stats.upper())}</text>')
    o.append('</svg>')
    meta = {"date": day, "aircraft": n, "rarest": rarest["t"] if rarest else None,
            "rarest_tier": rarest["rar"] if rarest else None, "farthest_km": round(far)}
    return "\n".join(o) + "\n", meta

def demo_tracks(seed=26):
    """Synthetic day: airway streams, an approach fan, GA wiggles, a helicopter and a rare visitor. Offsets only."""
    R = random.Random(seed); tr = {}
    def add(hx, t, pts, **k):
        tr[hx] = dict({"t": t, "id": k.pop("id", ""), "p": [[round(x, 1), round(y, 1)] for x, y in pts], "mil": False,
                       "rotor": False, "dmin": round(min(math.hypot(x, y) for x, y in pts), 1), "amax": 30000}, **k)
    airways = [(20, 15), (75, -40), (130, 60), (160, -10)]
    i = 0
    for ang, off in airways:
        a = math.radians(ang)
        for j in range(R.randint(25, 60)):
            o_ = off + R.gauss(0, 3); L = 280
            pts = [(s * math.cos(a) - o_ * math.sin(a) + R.gauss(0, .3), s * math.sin(a) + o_ * math.cos(a) + R.gauss(0, .3)) for s in range(-L // 2, L // 2, 6)]
            if j % 2: pts.reverse()
            add(f"d{i:05x}", R.choice(["B738", "A320", "E75L", "CRJ9", "B739", "A321", "B38M", "B789"]), pts, id=f"DMO{i}"); i += 1
    for j in range(45):                                   # arrivals curving into a runway at (40,-30)
        b = math.radians(R.uniform(0, 360)); r0 = R.uniform(90, 160); pts = []
        for s in range(0, 31):
            f = s / 30; ang_ = b + f * R.uniform(-.8, .8)
            pts.append(((1 - f) * r0 * math.cos(ang_) + f * 40, (1 - f) * r0 * math.sin(ang_) + f * -30))
        pts += [(40 + q * 1.8, -30 - q * .9) for q in range(1, 8)]
        add(f"d{i:05x}", R.choice(["B738", "A320", "E75L", "CRJ9"]), pts); i += 1
    for j in range(14):                                   # GA locals
        cx, cy = R.uniform(-40, 40), R.uniform(-40, 40); pts = []
        x, y, h = cx, cy, R.uniform(0, 6.28)
        for s in range(40): h += R.gauss(0, .18); x += 2 * math.cos(h); y += 2 * math.sin(h); pts.append((x, y))
        add(f"d{i:05x}", R.choice(["C172", "PA28", "SR22", "BE58"]), pts, id=f"N0FAKE{j}"); i += 1
    add("dheli1", "R44", [(8 + 6 * math.cos(s / 4), 5 + 4 * math.sin(s / 3)) for s in range(30)], rotor=True, id="N0HELO")
    add("dhook1", "H47", [(-120 + s * 6, 70 - s * 2.2) for s in range(40)], rotor=True, mil=True, id="DEMO47")
    vt, vid = [("V22", "DEMO22"), ("B52", "DEMO52"), ("C17", "DEMO17"), ("A388", "DEMO38"), ("DHC2", "N0FAKEB")][(seed + 4) % 5]
    add("dv22a1", vt, [(100 - s * 5, -110 + s * 4.5) for s in range(40)], mil=vt in ("V22", "B52", "C17"), id=vid)
    tr["dv22a1"]["dmin"] = 3.1
    return tr

def build(ot, day, page, keep=KEEP):
    t = load_json(os.path.join(ot, ".tracks", day + ".json"), None)
    if t is None: print(f"no tracks for {day}", file=sys.stderr); return None
    shapes, types = page_shapes(page)
    svg, meta = render(day, t.get("tracks", {}), load_json(os.path.join(ot, "collection.json"), {}), shapes, types)
    pd = os.path.join(ot, "posters"); write_atomic(os.path.join(pd, day + ".svg"), svg)
    idx = [m for m in load_json(os.path.join(pd, "index.json"), {}).get("posters", []) if m.get("date") != day] + [meta]
    idx = sorted(idx, key=lambda m: m["date"])[-keep:]
    have = {m["date"] for m in idx}
    for f in os.listdir(pd):
        if re.match(r"^\d{4}-\d\d-\d\d\.svg$", f) and f[:10] not in have:
            try: os.remove(os.path.join(pd, f))
            except OSError: pass
    write_atomic(os.path.join(pd, "index.json"), json.dumps({"now": int(time.time()), "posters": idx}, separators=(",", ":")))
    return meta

def selftest(page):
    ok = True; shapes, types = page_shapes(page)
    svg, meta = render("2026-10-26", demo_tracks(), {}, shapes, types)
    g = svg.startswith("<svg") and "Monday 26 October 2026" in svg and meta["rarest"] == "V22" and meta["aircraft"] > 150 \
        and svg.count('class="trk') == meta["aircraft"] and "lat" not in svg.replace("translate", "") and CREAM in svg
    print("PASS" if g else "FAIL", "render: title, all tracks, rarest, cream", meta); ok &= g
    g = (not shapes) or ('class="pl"' in svg)
    print("PASS" if g else "FAIL", "best-sighting drawings from page", len(shapes), "shapes"); ok &= g
    import shutil
    d = tempfile.mkdtemp()
    try:
        os.makedirs(os.path.join(d, ".tracks"))
        for i in range(3):
            day = f"2026-10-{20 + i:02d}"
            with open(os.path.join(d, ".tracks", day + ".json"), "w") as fh: json.dump({"tracks": demo_tracks(i)}, fh)
            build(d, day, page, keep=2)
        idx = load_json(os.path.join(d, "posters", "index.json"), {})["posters"]
        files = sorted(f for f in os.listdir(os.path.join(d, "posters")) if f.endswith(".svg"))
        g = [m["date"] for m in idx] == ["2026-10-21", "2026-10-22"] and files == ["2026-10-21.svg", "2026-10-22.svg"] \
            and build(d, "2026-01-01", page) is None
        print("PASS" if g else "FAIL", "archive: index + retention", files); ok &= g
    finally: shutil.rmtree(d)
    print("selftest", "OK" if ok else "FAILED"); return ok

def main():
    here = os.path.dirname(os.path.abspath(__file__))
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--dir", default="/usr/local/share/tar1090/html/ot")
    p.add_argument("--date", default=time.strftime("%Y-%m-%d"))
    p.add_argument("--page", default=None, help="overhead.html to borrow the line drawings from (default: next to --dir, else repo)")
    p.add_argument("--keep", type=int, default=KEEP)
    p.add_argument("--demo", action="store_true"); p.add_argument("--out", default=None)
    p.add_argument("--selftest", action="store_true")
    o = p.parse_args()
    page = o.page or next((c for c in (os.path.join(os.path.dirname(os.path.abspath(o.dir)), "overhead.html"),
                                      os.path.join(here, "..", "overhead.html")) if os.path.exists(c)), "")
    if o.selftest: sys.exit(0 if selftest(page) else 1)
    if o.demo:
        shapes, types = page_shapes(page); svg, meta = render(o.date, demo_tracks(int(o.date[-2:]) or 26), {}, shapes, types)
        if o.out: write_atomic(o.out, svg)
        else: sys.stdout.write(svg)
        print(json.dumps(meta), file=sys.stderr); return
    m = build(o.dir, o.date, page, o.keep)
    if m is None: sys.exit(0)                  # no data yet is not a failure for the timer
    print(json.dumps(m))

if __name__ == "__main__":
    main()
