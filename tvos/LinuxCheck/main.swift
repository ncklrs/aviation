// Linux sanity checks for the tvOS app's non-UI logic. Run: sh tvos/LinuxCheck/run.sh
import Foundation

var bad = 0
func check(_ ok: Bool, _ msg: String) { print((ok ? "PASS  " : "FAIL  ") + msg); if !ok { bad += 1 } }
let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
func file(_ p: String) -> Data { FileManager.default.contents(atPath: root + "/" + p) ?? Data() }

// 1. Type mapping: same cases as tools/test_types.js
let want: [(String, String)] = [("GA8C","bizjet"),("GA7C","bizjet"),("GA6C","bizjet"),("GA5C","bizjet"),("GLF6","bizjet"),("GLF5","bizjet"),
  ("GLF4","bizjet"),("G800","bizjet"),("G650","bizjet"),("GLEX","bizjet"),("GL5T","bizjet"),("GL7T","bizjet"),("FA7X","bizjet"),("FA8X","bizjet"),
  ("F900","bizjet"),("F2TH","bizjet"),("CL60","bizjet"),("CL35","bizjet"),("LJ35","bizjet-light"),("LJ45","bizjet-light"),("LJ60","bizjet-light"),
  ("LJ75","bizjet-light"),("C68A","bizjet-light"),("E55P","bizjet-light"),("B38M","b737"),("A320","a320"),("B789","widebody"),("CRJ9","regional"),
  ("C172","cessna"),("B52","widebody")]
for (t, c) in want { let g = Classify.shape(Aircraft(hex: "x", t: t, category: "A3")); check(g == c, "\(t.padding(toLength: 5, withPad: " ", startingAt: 0)) -> \(g)") }
check(Classify.shape(Aircraft(hex: "x", t: "ZZZZ", desc: "GULFSTREAM G-8 G800", category: "A3")) == "bizjet", "desc GULFSTREAM G-8 G800 -> bizjet")
check(Classify.shape(Aircraft(hex: "x", category: "A3", dbFlags: 1)) == "milcargo", "no type, A3 + military -> milcargo")
check(Classify.shape(Aircraft(hex: "x", category: "A7")) == "heli", "no type, A7 -> heli")
check(Classify.shape(Aircraft(hex: "x", alt: 30000)) == "airliner", "no type/category, 30000 ft -> airliner")
check(Classify.shape(Aircraft(hex: "x", t: "C17", category: "A5")) == "heavy-airlifter", "C17 -> heavy-airlifter (not widebody)")
check(Classify.why(Aircraft(hex: "x", flight: "LN2", t: "EC35", category: "A7")).contains("Medevac"), "LN2 EC35 tagged Medevac")
check(Classify.rarity("V22", tails: 1, mil: true, rotor: false) == "Legendary", "rarity V22 Legendary")
check(Classify.rarity("C172", tails: 30, mil: false, rotor: false) == "Common", "rarity C172 x30 Common")

// 2. Parsing
let af = try? JSONDecoder().decode(AircraftFile.self, from: file("Overhead/Resources/sample-aircraft.json"))
check((af?.aircraft.count ?? 0) >= 5, "sample-aircraft.json decodes (\(af?.aircraft.count ?? 0) aircraft)")
let odd = #"{"now":1,"aircraft":[{"hex":"ABC123","alt_baro":"ground","gs":"x","lat":39.1,"lon":-98.1,"flight":"N0FAKE  "}]}"#
let o = try? JSONDecoder().decode(AircraftFile.self, from: Data(odd.utf8))
check(o?.aircraft.first?.alt == 0 && o?.aircraft.first?.gs == nil && o?.aircraft.first?.callsign == "N0FAKE", "lenient decode: ground, bad gs, trimmed callsign")
let rc = try? JSONDecoder().decode(Receiver.self, from: file("Overhead/Resources/sample-receiver.json"))
check(rc?.lat == 39.0 && rc?.lon == -98.0, "sample-receiver.json is the demo point 39,-98")
check(Outline.parse(Data(#"{"actualRange":{"last24h":{"points":[[39,-98,1],[39.5,-98,2],[39.2,-97.5,3]]}}}"#.utf8))?.count == 3, "outline.json parse")
check(RouteLookup.parse(Data(#"{"response":{"flightroute":{"origin":{"iata_code":"DEN"},"destination":{"iata_code":"ORD"}}}}"#.utf8)) == RouteLookup.Route(from: "DEN", to: "ORD"), "adsbdb route parse")
check(RouteLookup.eligible("UAL88") && !RouteLookup.eligible("N0FAKE1"), "route eligibility")

// 3. Art + poster
let (art, scale) = ShapeArt.load(file("Overhead/Resources/shapes.json"))
let classes = Set(TypeTable.rules.map { $0.1 } + ["cessna", "heli", "fighter", "milcargo", "widebody", "airliner", "bizjet"])
check(classes.allSatisfy { art[$0] != nil }, "every class has a drawing (\(art.count) drawings)")
check(art.values.allSatisfy { $0.bg.count > 10 && $0.tr.count > 10 }, "all drawings parse to path ops")
check(scale["bizjet"] == 0.6, "scale table loaded")
var mx = -1e9, mn = 1e9
for a in art.values { for op in a.tr { if case let .move(x, y) = op { mx = max(mx, x, y); mn = min(mn, x, y) } } }
check(mn > -5 && mx < 205, "drawing coordinates inside the 200x74 box (\(Int(mn))..\(Int(mx)))")
check(SVGPath.parse("M10 10h5v5H0z") == [.move(10, 10), .line(15, 10), .line(15, 15), .line(0, 15), .close], "path H/V/z")
let ps = PosterSVG.parse(file("../sample-poster.svg"))
check((ps?.items.count ?? 0) > 200 && ps?.width == 1200, "sample-poster.svg parses (\(ps?.items.count ?? 0) items)")
if case let .text(s, _, _, _, _, italic, _)? = ps?.items.first(where: { if case .text = $0 { return true }; return false }) {
    check(s.contains("October") && italic, "poster title text: \(s)")
} else { check(false, "poster title text") }
check(OverheadSettings().aircraftURL?.absoluteString == "http://adsb.local/tar1090/data/aircraft.json", "default URL uses adsb.local")
var s2 = OverheadSettings(); s2.host = " pi.local/ "
check(s2.aircraftURL?.absoluteString == "http://pi.local/tar1090/data/aircraft.json", "host normalisation")
check(Sun.isNight(Home(lat: 39, lon: -98), at: Date(timeIntervalSince1970: 1793080800)) == true, "sun: 2026-10-27 04:00Z is night at 39,-98")
check(Sun.isNight(Home(lat: 39, lon: -98), at: Date(timeIntervalSince1970: 1793037600)) == false, "sun: 2026-10-26 18:00Z is day at 39,-98")


// New-card reveal trigger: same cases as tools/test_reveal.js
struct RCase: Decodable { var name: String; var now: Double; var seen: [String]; var unlocks: [HangarUnlockIn]; var want: [String] }
struct HangarUnlockIn: Decodable { var t: String; var at: Double }
struct RCases: Decodable { var cases: [RCase] }
let rcPath = root + "/../tools/reveal_cases.json"
if let d = FileManager.default.contents(atPath: rcPath), let rc = try? JSONDecoder().decode(RCases.self, from: d) {
    for c in rc.cases {
        var seen = c.seen
        let got = Reveal.pick(c.unlocks.map { HangarUnlock(t: $0.t, at: $0.at) }, seen: &seen, now: c.now).map { $0.t }
        check(got == c.want, "reveal: \(c.name) -> \(got)")
    }
    var s2: [String] = []; let u = [HangarUnlock(t: "V22", at: 9400)]
    _ = Reveal.pick(u, seen: &s2, now: 10000)
    check(Reveal.pick(u, seen: &s2, now: 10000).isEmpty, "reveal: second call is empty")
} else { check(false, "reveal cases at \(rcPath)") }
if bad > 0 { print("\(bad) FAIL"); exit(1) }
print("tvOS core OK")
