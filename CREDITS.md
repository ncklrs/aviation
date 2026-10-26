# Credits

## Aircraft side-profile drawings

All 23 aircraft drawings are original art made for this project. Each was generated as a generic, unbranded line drawing with an AI image model, then vectorized with potrace (via `potracer`) into a single filled outline path plus a white backing silhouette. The source images and the conversion script live in `art/` (`art/build.py`). No third-party drawings, traces, or logos are used. They are released under the same license as this project.

Classes: high-wing single, low-wing single, light twin, helicopter, twin-engine helicopter, tandem-rotor helicopter, tiltrotor, twin turboprop, business jet, regional jet, narrowbody jet, widebody jet, high-wing retractable single, military transport, heavy jet airlifter, fighter / jet trainer, E-Jet, Airbus A320 family, Boeing 737, Boeing 757, Airbus A220, light/midsize business jet, single turboprop.

### Reference photos

These drawings were generated with a Wikimedia Commons photo given to the image model as a shape reference only. No pixels from the photos appear in the drawings, and liveries and registrations were left out.

- `e-jet`: lead image of the English Wikipedia article "Embraer E-Jet family" (Wikimedia Commons), by Richard Vandervord, CC BY-SA 4.0
- `a320`: lead image of the English Wikipedia article "Airbus A320 family" (Wikimedia Commons), by Pedro Aragão, CC BY-SA 3.0
- `b737`: lead image of the English Wikipedia article "Boeing 737 Next Generation" (Wikimedia Commons), by 4300streetcar, CC BY 4.0
- `b757`: lead image of the English Wikipedia article "Boeing 757" (Wikimedia Commons), by 4300streetcar, CC BY 4.0
- `a220`: lead image of the English Wikipedia article "Airbus A220" (Wikimedia Commons), by Romain COUPY, CC BY-SA 4.0
- `bizjet-light`: lead image of the English Wikipedia article "Embraer Phenom 300" (Wikimedia Commons), by Aktug Ates, GFDL 1.2
- `pc12`: lead image of the English Wikipedia article "Pilatus PC-12" (Wikimedia Commons), by Chris Finney, GFDL 1.2

## Map data

When the receiver location is known, the faint background map is fetched at runtime from the [Overpass API](https://overpass-api.de/) and cached in the browser's localStorage.
Map data © OpenStreetMap contributors, available under the [Open Database License (ODbL)](https://www.openstreetmap.org/copyright). The page shows this attribution in its footer whenever a map is drawn. No map data is bundled. Demo mode uses a small synthetic map of invented geography.

To turn the map off, use `?map=0`. To point it at another Overpass endpoint, use `?overpass=`.
