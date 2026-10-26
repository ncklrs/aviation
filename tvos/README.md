# Overhead for Apple TV (tvOS 17+)

A native SwiftUI version of `overhead.html` for the living-room TV: live sky map on the left, a big card for the nearest (or selected) aircraft on the right, plus the Hangar cards and daily sky posters. Everything is read from your own receiver on the local network. The app has no accounts and no analytics, and the only outside call is the optional adsbdb.com route lookup.

## Build

```sh
brew install xcodegen
cd tvos && xcodegen          # writes Overhead.xcodeproj from project.yml
open Overhead.xcodeproj
```

1. In `project.yml`, change `BUNDLE_PREFIX: com.example` to your own reverse domain (or edit it in Xcode).
2. In Xcode, go to Signing & Capabilities and choose your Team for **both** targets. The App Group `group.<prefix>.overhead` is created automatically.
3. Choose your Apple TV (pair it under Window > Devices; on the TV, open Settings > Remotes and Devices > Remote App and Devices) or the tvOS Simulator, then Run.
4. The first time it connects, tvOS asks for **Local Network** permission. Allow it.

You don't want Top Shelf? Delete the `OverheadTopShelf` target and its `dependencies:` entry in `project.yml`. The app runs fine without the App Group.

## Settings (press Play/Pause)

| Setting | Default | Notes |
|---|---|---|
| Host | `adsb.local` | Pi running readsb + tar1090. Reads `http://HOST/tar1090/data/aircraft.json` (every second) and `receiver.json`/`outline.json` (each minute). It also reads `/ot/` or `/tar1090/ot/` for collection.json, interesting.json and posters. |
| Demo mode | off | Fake aircraft around 39°N 98°W from the bundled samples. Needs no network. |
| Night mode | auto | Dim red on black after sunset at the receiver, or always on/off. |
| Units | aviation | kt/ft/nm, imperial or metric |
| Map radius | 25 nm | |
| Routes | on | adsbdb.com lookup for airline callsigns (cached 24 h, rate-limited) |

Photos are not used.

## Remote

- **Swipe or click ◀ ▶** cycles Live → Hangar cards → Sky poster.
- **▲ ▼**: on Live, picks the next or previous aircraft. On Hangar it pages the cards. On Poster it picks the day.
- **Play/Pause** opens settings.

## Ambient behaviour

- The idle timer is off while the app is in front, so the screensaver won't start.
- The whole layout drifts slowly (±14×10 pt over a few minutes) to prevent burn-in.
- After 2 minutes with no aircraft, the Live screen dims to 35 %.
- Top Shelf (optional) shows the live count and nearest callsign (refreshed every 30 s while the app is open), plus the latest poster rendered to PNG.

## Layout

```
Overhead/Sources/Core/   Foundation-only logic (type rules, geometry, SVG path/poster parsing, settings, routes) – also compiles on Linux
Overhead/Sources/UI/     SwiftUI views (tvOS)
Overhead/Resources/      shapes.json (line drawings from overhead.html), demo samples, sample poster
TopShelf/                TVTopShelfContentProvider
LinuxCheck/              `bash LinuxCheck/run.sh` – compiles Core with swiftc and runs the test_types.js cases + parsers
```

`Core/TypeTable.swift` is generated from overhead.html by `node tools/gen_tvos_types.js`. Run it again after you change the type rules on the web page.

## Known gaps

- The UI and Top Shelf code has only been syntax-checked (`swiftc -parse`), not compiled against the tvOS SDK. Expect a few small fixes on first build in Xcode.
- There's no app icon yet. Xcode warns about this, and you'll need one for TestFlight or the App Store (tvOS uses layered "App Icon & Top Shelf Image" brand assets).
- If your Pi serves the logger files somewhere other than `/ot/` or `/tar1090/ot/`, the Hangar and Poster screens show their empty states.
- Posters are drawn by a small SVG subset renderer (rect/line/path/text/g). If you add other elements to the poster, they won't be drawn.
