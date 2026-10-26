# Overhead: ADS-B line-drawing page for Tesserae

`index.html` is one self-contained file (no external assets). Thin black strokes on white,
legible on B/W or 16-grey e-ink at 800x480, 1200x1600 (portrait stacks) and 1872x1404.

- **Up high**: highest aircraft at or above 18,000 ft, drawn large and rotated to its track, with callsign, FL, ground speed, distance and heading.
- **The pattern**: up to 5 nearest aircraft below 18,000 ft. Category A1 or unknown gets a high-wing Cessna drawing, A2 a bizjet, A3 to A6 an airliner, and A7 a helicopter.
- Empty states read "Quiet skies" or "Nothing up high". The footer shows the count and the time the data was updated.
- Config constants sit at the top of the `<script>` block: `AIRCRAFT_URL` (default `http://pi.local:8080/data/aircraft.json`), `HIGH_FT`, `MAX_PATTERN`, `MAX_SEEN_S`, and an optional `HOME`. `receiver.json` is read from the same folder to get the lat/lon used for distance.
- URL params: `?demo=1` (uses the fake `sample-aircraft.json` / `sample-receiver.json`, with an inline copy as fallback), `?url=…`, `?receiver=…`, `?refresh=SECONDS` (standalone only).

## Important: Tesserae can't fetch from your Pi directly
I checked this against the dmellok/tesserae source:
- A **Code** element runs in a sandboxed iframe with **no fetch/XHR**. Data is fetched server-side and injected as `ctx.data[name]`.
- The generic **REST / JSON** source (`rest_service`) and raw-URL code sources go through `app/net_guard`, which **blocks loopback and private-LAN hosts**. So `http://pi.local:8080/...` or `192.168.x.x` will come back as `{"error": ...}`.
- The **Webpage** widget renders a URL with headless Chromium using operator trust, so **LAN URLs are allowed**.

### Option A (recommended): host the page on the Pi and use the Webpage widget
1. Copy the file to the Pi next to tar1090/dump1090's web root, for example
   `sudo cp index.html /usr/share/tar1090/html/overhead.html` (path varies; for readsb + lighttpd it's often `/usr/local/share/tar1090/html/`).
   Because it's served from the same origin as `data/aircraft.json`, there's **no CORS issue**. Set
   `AIRCRAFT_URL = 'data/aircraft.json'` (relative) if you like.
2. In Tesserae, add a **Webpage** widget at full size with URL `http://pi.local:8080/overhead.html` (use the Pi's IP if
   the Tesserae container can't resolve mDNS `.local`, which is common in Docker). Raise the settle delay to about 2 s so the fetch finishes before capture.

### Option B: paste it as a Code element
Paste the CSS into the element's css field, the body markup into html, and the script into js. Add sources named
`aircraft` (and optionally `receiver`). The script picks up `window.ctx.data.aircraft` / `.receiver` automatically.
This only works if the JSON is reachable at a **public** URL (because the LAN is blocked), for example through a Cloudflare Tunnel
or Tailscale Funnel exposing just `/data/*.json`. If the guard refuses, the page shows "Receiver unreachable" with the error.
Also check whether `ctx` is defined at script run time in your Tesserae version. If not, wrap `main()` in whatever ready hook the editor shows.

## Caveats
- **Refresh**: e-ink renders once per device refresh. A refresh of 2 to 5 minutes is reasonable, so planes will be a snapshot, not live. Each refresh costs battery.
- **CORS**: if you open the page from a different origin (for example `file://` or another host), the browser needs the Pi to send `Access-Control-Allow-Origin`. Option A avoids this.
- `category` is often missing for small GA transponders. Those default to the Cessna drawing, or the airliner if they're above 18,000 ft.
- `receiver.json` only has lat/lon if you set a location in readsb/dump1090. Otherwise set `HOME`, or distances show "—".
- The demo data is entirely fake (DEMO101, N0FAKE1, and so on).

Previews: `preview-800x480.png`, `preview-1200x1600.png`, `preview-1872x1404.png`.

## URL parameters

| Param | Default | Meaning |
|---|---|---|
| `demo=1` | off | Fake aircraft, synthetic map, fake weekly entries |
| `refresh=N` | 0 | Re-poll every N seconds (0 = render once) |
| `lat=` `lon=` | receiver.json | Map center if receiver.json has no position |
| `map=0` / `mapNm=N` / `overpass=URL` | on / 25 / public | Background OSM line map |
| `cycle=N` | 120 | Seconds per live/weekly cycle; `cycle=0` never shows the weekly page |
| `weekSecs=N` | 20 | Seconds the weekly page shows in each cycle |
| `view=week` / `view=live` | | Pin one view (screenshots) |
| `interesting=URL` | auto | Logger output location (tries `data/interesting.json`, then `interesting.json` next to the page) |
| `units=aero\|imperial\|metric` | `aero` | aero: kt / ft (FL above `upHighFt`) / nm · imperial: mph / ft / mi · metric: km/h / m / km |
| `eink=1` | off | Strict 1-bit black and white, no motion, thicker strokes; refresh defaults to 60 s |
| `recent=0` | on | Hide the "Recently seen" strip |
| `url=URL` / `receiver=URL` | `data/aircraft.json` / alongside | Receiver data sources |
| `upHighFt=N` | 18000 | "Up high" threshold |

The cycle is clock-based (`now mod cycle < weekSecs`), so render-once snapshots also land on the weekly page for the same share of runs.

## Configuration

No code edits needed. Settings resolve in this order: **URL param → `window.OVERHEAD_CONFIG` → constants at the top of the script**.

Option 1, URL params (see table above), e.g. `overhead.html?units=metric&eink=1&refresh=60`.

Option 2, a config block. Put this in a `<script>` placed *before* the main script (or in a `config.js` you include there):

```html
<script>
window.OVERHEAD_CONFIG = {
  aircraftUrl:    'data/aircraft.json',   // readsb/tar1090 aircraft.json
  receiverUrl:    null,                   // default: receiver.json next to aircraft.json
  interestingUrl: null,                   // default: auto (see below)
  home:           null,                   // {lat: 0.0, lon: 0.0}; null = use receiver.json position
  units:          'aero',                 // 'aero' | 'imperial' | 'metric'
  eink:           false,
  refresh:        0,                      // seconds; 0 = render once (eink defaults to 60)
  recent:         true                    // "Recently seen" strip
};
</script>
```

Home position: if `home` is null the page uses the lat/lon in `receiver.json`. Nothing about your location is stored in the code. `?lat=&lon=` override both. Without any position, distances show "—" and the map is skipped.

Try it with `?demo=1` (fake aircraft around an arbitrary demo point, synthetic map).

## E-ink mode

`?eink=1` turns every grey into black, uses dotted black lines for the map, thickens the line drawings, disables transitions and animations, and re-polls every 60 s (override with `refresh=`). For panels that do a full refresh per render, `refresh=0` renders once and leaves the refresh to your screenshot tool.

## Recently seen strip

A one-line strip above the footer listing the newest military, rotorcraft (incl. Chinook, Osprey), medevac and emergency aircraft from the last 7 days, e.g. `RCH431 C17 · Military · 5h`. It comes from the logger's `interesting.json`, or the page's own localStorage log if there's no logger. It's hidden when there is nothing to show, during the weekly page, or with `recent=0`. Medevac is matched on callsign/operator text (Life Flight, Air Methods, PHI, MEDEVAC…), so it's a best effort.

## "Interesting this week"

An aircraft is logged when any of these is true:

- dbFlags military (bit 1), interesting (bit 2), PIA (bit 4) or LADD (bit 8)
- squawk 7500, 7600 or 7700, or an emergency status
- helicopter (category A7 or known rotorcraft type)
- widebody or four-engine type
- above 45,000 ft or faster than 550 kt ground speed
- a type not on the built-in common list (C172, PA28, 737, A320, CRJ and so on)

The weekly page shows up to 8 entries: emergencies first, then military, PIA/LADD, flagged, then the rest, newest first within each group.

Without the logger the page keeps its own 7-day log in localStorage, which only covers time the page was open.

### Optional Pi-side logger

Not installed by default. Run these on the Pi when you want it.

`pi/interesting_logger.py` is one Python 3 script, stdlib only. It polls aircraft.json every 30 s, dedupes by ICAO hex per UTC day (keeping first/last seen, max altitude, max speed) and atomically writes a rolling 7-day `interesting.json` next to the page.

```sh
sudo install -m 755 pi/interesting_logger.py /usr/local/bin/
sudo touch /usr/local/share/tar1090/html/interesting.json
sudo chown www-data /usr/local/share/tar1090/html          # the logger writes a temp file then renames
python3 /usr/local/bin/interesting_logger.py --once && echo ok
```

As a service:

```sh
sudo cp pi/interesting-logger.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now interesting-logger
journalctl -u interesting-logger -f
```

Or cron instead (`pi/crontab.example`):

```
* * * * * /usr/bin/python3 /usr/local/bin/interesting_logger.py --once
```

Options: `--src` (URL or file, e.g. `/run/readsb/aircraft.json`), `--out`, `--interval`, `--max-seen`, `--once`. The page looks for `data/interesting.json` and then `interesting.json` next to itself, so the default `--out` works with no settings. Anywhere else: `?interesting=URL`. Check with `curl -s http://localhost/tar1090/interesting.json | head -c 300`. Remove with `sudo systemctl disable --now interesting-logger`.

## Credits

See `CREDITS.md`: public domain drawings plus original ones; map data © OpenStreetMap contributors (ODbL).
