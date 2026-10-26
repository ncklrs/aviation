import Foundation

/// User settings (UserDefaults). Default host is a placeholder mDNS name; no address or location ships in the app.
struct OverheadSettings: Equatable {
    static let defaultHost = "adsb.local"
    var host: String = defaultHost
    var demo = false
    var night = "auto"          // auto | on | off
    var units = "aero"          // aero | imperial | metric
    var mapNm = 25.0
    var routes = true           // adsbdb.com callsign -> route lookup
    var pollSeconds = 1.0

    /// Base like "http://adsb.local" (scheme added if missing, trailing slash dropped).
    var base: String {
        var h = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.isEmpty { h = Self.defaultHost }
        if !h.contains("://") { h = "http://" + h }
        while h.hasSuffix("/") { h.removeLast() }
        return h
    }
    var aircraftURL: URL? { URL(string: base + "/tar1090/data/aircraft.json") }
    var receiverURL: URL? { URL(string: base + "/tar1090/data/receiver.json") }
    var outlineURL: URL? { URL(string: base + "/tar1090/data/outline.json") }
    /// Logger output dir; the web page sits next to it at /<page>/ot/. Tries both common spots.
    var otBases: [String] { [base + "/ot/", base + "/tar1090/ot/"] }

    static let demoHome = Home(lat: 39.0, lon: -98.0)

    static func load(_ d: UserDefaults = .standard) -> OverheadSettings {
        var s = OverheadSettings()
        if let v = d.string(forKey: "host"), !v.isEmpty { s.host = v }
        s.demo = d.bool(forKey: "demo")
        if let v = d.string(forKey: "night") { s.night = v }
        if let v = d.string(forKey: "units") { s.units = v }
        if d.object(forKey: "mapNm") != nil { s.mapNm = max(5, d.double(forKey: "mapNm")) }
        if d.object(forKey: "routes") != nil { s.routes = d.bool(forKey: "routes") }
        return s
    }
    func save(_ d: UserDefaults = .standard) {
        d.set(host, forKey: "host"); d.set(demo, forKey: "demo"); d.set(night, forKey: "night")
        d.set(units, forKey: "units"); d.set(mapNm, forKey: "mapNm"); d.set(routes, forKey: "routes")
    }

    func speed(_ kt: Double?) -> String {
        guard let kt = kt else { return "—" }
        switch units { case "imperial": return "\(Int((kt * 1.150779).rounded())) mph"
        case "metric": return "\(Int((kt * 1.852).rounded())) km/h"
        default: return "\(Int(kt.rounded())) kt" }
    }
    func distance(_ nm: Double?) -> String {
        guard let nm = nm else { return "—" }
        let (v, u) = units == "metric" ? (nm * 1.852, "km") : units == "imperial" ? (nm * 1.150779, "mi") : (nm, "nm")
        return String(format: v < 10 ? "%.1f %@" : "%.0f %@", v, u)
    }
    func altitude(_ ft: Double?) -> String {
        if units == "metric", let ft = ft { return ft <= 0 ? "GND" : Geo.grouped(ft * 0.3048) + " m" }
        if units == "imperial", let ft = ft { return ft <= 0 ? "GND" : Geo.grouped(ft) + " ft" }
        return Geo.flightLevel(ft)
    }
}

/// NOAA-style sunrise/sunset approximation (same idea as the page), used for night = auto.
enum Sun {
    static func isNight(_ h: Home, at date: Date = Date()) -> Bool {
        let r = Double.pi / 180
        let jd = date.timeIntervalSince1970 / 86400 + 2440587.5, n = jd - 2451545.0
        let L = (280.46 + 0.9856474 * n).truncatingRemainder(dividingBy: 360)
        let g = ((357.528 + 0.9856003 * n).truncatingRemainder(dividingBy: 360)) * r
        let lam = (L + 1.915 * sin(g) + 0.02 * sin(2 * g)) * r, eps = (23.439 - 0.0000004 * n) * r
        let dec = asin(sin(eps) * sin(lam))
        var ra = atan2(cos(eps) * sin(lam), cos(lam)) / r; if ra < 0 { ra += 360 }
        let gmst = (280.46061837 + 360.98564736629 * n).truncatingRemainder(dividingBy: 360)
        let ha = (gmst + h.lon - ra) * r, lat = h.lat * r
        let elev = asin(sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(ha)) / r
        return elev < -0.833
    }
}
