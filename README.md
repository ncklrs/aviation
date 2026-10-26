# Overhead: ADS-B line-drawing page

![Overhead demo](docs/demo.gif)

A single-file web page for a tar1090/readsb receiver that shows the aircraft above you as clean side-profile line drawings, sized for iPads and e-ink panels.

## Features

- Highest aircraft drawn large with callsign, airline, type, **route** (e.g. `EWR → TLV`), altitude, speed, distance and heading; the two nearest below it.
- 23 original aircraft drawings, picked from the ICAO type code.
- Faint background map (OpenStreetMap) plus your receiver's own coverage outline.
- **Recently seen** strip and an **Interesting this week** page (military, medevac, emergencies, rotorcraft, rare types).
- **Stats** page: unique aircraft, busiest hour, farthest contact (today and 7 days) and the top 10 types.
- **Night mode** (red on black after local sunset), **e-ink mode**, units (knots/ft, mph/mi, metric).
- Optional Pi logger with **ntfy push alerts**, and a nightly md5-verified **auto-update**.

| Live | Stats | Night |
|---|---|---|
| ![live](docs/screenshot-live.png) | ![stats](docs/screenshot-stats.png) | ![night](docs/screenshot-night.png) |

All screenshots use `?demo=1` (invented aircraft and a synthetic map).

## Install (stock tar1090 Pi)

```sh
git clone https://github.com/ncklrs/aviation && cd aviation && sudo ./install.sh
# page only:            sudo NO_LOGGER=1 NO_TIMER=1 ./install.sh
```

This installs `overhead.html` into `/usr/local/share/tar1090/html/`, creates `html/ot/` (www-data) with `html/interesting.json` symlinked to `ot/interesting.json`, the logger as `interesting-logger.service`, and the nightly `overhead-update.timer`. Then open `http://<pi>/tar1090/overhead.html`. Set your receiver location in readsb so distances, the map and night mode work.

## Routes

Airline callsigns (e.g. `UAL88`) are looked up at [adsbdb.com](https://www.adsbdb.com/) (free, CORS-enabled). Results are cached per callsign for 24 h in localStorage, requests are spaced at least 4 s apart, and failures are silent. Routes come from crowd-sourced data and can be stale. Turn off with `?routes=0` or `OVERHEAD_CONFIG.routes=false`; `OVERHEAD_CONFIG.routeApi` changes the endpoint.

## Night mode

`?night=auto|on|off` (default `auto`, or `OVERHEAD_CONFIG.night`). In auto, sunrise and sunset are computed in the page from the home lat/lon (NOAA-style approximation, no API) and the page turns dim red on black between them. Ignored with `?eink=1`.

## Stats

The page keeps per-day counts in localStorage while it is open (unique ICAO hex, first-seen per hour, types, farthest contact; 8 days kept). The view rotation goes live → interesting this week → stats when `?cycle=` is at least 3× `weekSecs` (default 120 s / 20 s). Pin it with `?view=stats`. Counts only cover time the page was running.

## Push alerts (ntfy)

The logger can post to [ntfy](https://ntfy.sh). Off unless a topic is set. Put it in `/etc/default/interesting-logger` (template: `pi/interesting-logger.default`), never in the code:

```sh
NTFY_TOPIC=some-long-unguessable-name
#NTFY_SERVER=https://ntfy.sh
#NTFY_TAGS=Emergency,Hijack,Radio,Medevac,Military,Helicopter
```

`sudo systemctl restart interesting-logger`. At most one alert per aircraft per 6 h. Same options as flags: `--ntfy-topic`, `--ntfy-server`, `--ntfy-tags`.

## Auto-update

`pi/overhead-update.sh` (run nightly ~03:30 by `overhead-update.timer`) downloads `overhead.html`, `pi/interesting_logger.py` and `pi/interesting-logger.service` from `REPO_RAW` (default `https://raw.githubusercontent.com/ncklrs/aviation/main`), checks each against its published `.md5`, keeps a `.bak`, and swaps atomically only when the file changed and the md5 matches. It also re-creates `html/ot/` and the `interesting.json` symlink if missing. A new logger must pass `--selftest` before the service is restarted; otherwise the backup is restored. Override `REPO_RAW`, `PAGE_DIR`, `LOGGER` in `/etc/default/overhead-update`. Run now: `sudo systemctl start overhead-update; journalctl -u overhead-update`.

Maintainers: run `tools/release.sh` before every commit that touches those files; it runs the selftest and regenerates `overhead.html.md5`, `pi/interesting_logger.py.md5` and `pi/interesting-logger.service.md5`.

## Medevac detection

The logger tags **Medevac** from public, generic signals only: the tar1090 db operator (`ownOp`) naming an air-ambulance operator or hospital program (Air Methods, PHI, Metro Aviation, Med-Trans, Life Flight, CareFlight, Survival Flight, MedFlight, Air Evac, "medical", "hospital"…), or a rotorcraft (category A7 or helicopter type) using an air-ambulance callsign pattern (`LN#`, `LIFE`, `MERCY`, `CARE`, `STAT#`, `MEDEVAC`, `ANGEL`, …). Military aircraft (dbFlags) and `RCH` "Reach" callsigns stay Military. `python3 pi/interesting_logger.py --selftest` checks this.

## Notes

`index.html` is one self-contained file (no external assets). Thin black strokes on white,
legible on B/W or 16-grey e-ink at 800x480, 1200x1600 (portrait stacks) and 1872x1404.

- **Up high**: highest aircraft at or above 18,000 ft, drawn large and rotated to its track, with callsign, FL, ground speed, distance and heading.
- **The pattern**: up to 5 nearest aircraft below 18,000 ft. Category A1 or unknown gets a high-wing Cessna drawing, A2 a bizjet, A3 to A6 an airliner, and A7 a helicopter.
- Empty states read "Quiet skies" or "Nothing up high". The footer shows the count and the time the data was updated.
- Config constants sit at the top of the `<script>` block: `AIRCRAFT_URL` (default `http://pi.local:8080/data/aircraft.json`), `HIGH_FT`, `MAX_PATTERN`, `MAX_SEEN_S`, and an optional `HOME`. `receiver.json` is read from the same folder to get the lat/lon used for distance.
- URL params: `?demo=1` (uses the fake `sample-aircraft.json` / `sample-receiver.json`, with an inline copy as fallback), `?url=…`, `?receiver=…`, `?refresh=SECONDS` (standalone only).

## Caveats
- **Refresh**: e-ink renders once per device refresh. A refresh of 2 to 5 minutes is reasonable, so planes will be a snapshot, not live. Each refresh costs battery.
- **CORS**: if you open the page from a different origin (for example `file://` or another host), the browser needs the Pi to send `Access-Control-Allow-Origin`. Serving the page from the Pi avoids this.
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

A one-line strip above the footer listing the newest military, rotorcraft (incl. Chinook, Osprey), medevac and emergency aircraft from the last 7 days, e.g. `RCH431 C17 · Military · 5h`. It comes from the logger's `interesting.json`, or the page's own localStorage log if there's no logger. It's hidden when there is nothing to show, during the weekly page, or with `recent=0`. Its tag priority is Emergency > Medevac > Military > Helicopter > Rare type. Medevac detection is best effort (see Medevac detection).

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

`install.sh` sets this up for you; the manual steps are below.

`pi/interesting_logger.py` is one Python 3 script, stdlib only. It polls aircraft.json every 30 s, dedupes by ICAO hex per UTC day (keeping first/last seen, max altitude, max speed) and atomically writes a rolling 7-day `html/ot/interesting.json`; `html/interesting.json` is a symlink to it, so only `ot/` is writable by www-data (the html folder itself is never chowned).

```sh
sudo install -m 755 pi/interesting_logger.py /usr/local/bin/
H=/usr/local/share/tar1090/html
sudo install -d -o www-data -m 755 $H/ot                    # the logger only writes here (temp file + rename)
sudo ln -sfn ot/interesting.json $H/interesting.json         # page still finds interesting.json next to itself
sudo -u www-data python3 /usr/local/bin/interesting_logger.py --once --out $H/ot/interesting.json && echo ok
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

Options: `--selftest`, `--ntfy-topic/--ntfy-server/--ntfy-tags`, `--src` (URL or file, e.g. `/run/readsb/aircraft.json`), `--out`, `--interval`, `--max-seen`, `--once`. The page looks for `data/interesting.json` and then `interesting.json` next to itself, so the default `--out` works with no settings. Anywhere else: `?interesting=URL`. Check with `curl -s http://localhost/tar1090/interesting.json | head -c 300`. Remove with `sudo systemctl disable --now interesting-logger`.

## Credits

See `CREDITS.md`: original drawings, map data © OpenStreetMap contributors (ODbL), routes from adsbdb.com. Licensed MIT (`LICENSE`).
