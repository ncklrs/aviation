import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Optional callsign -> route lookup at adsbdb.com (same public API the web page uses). Cached 24 h, spaced >= 4 s.
actor RouteLookup {
    struct Route: Equatable { var from: String; var to: String }
    private var cache: [String: (Route?, Date)] = [:]
    private var lastCall = Date.distantPast

    static func parse(_ data: Data) -> Route? {
        guard let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let r = (j["response"] as? [String: Any])?["flightroute"] as? [String: Any],
              let o = r["origin"] as? [String: Any], let d = r["destination"] as? [String: Any] else { return nil }
        func code(_ a: [String: Any]) -> String {
            (a["iata_code"] as? String) ?? (a["icao_code"] as? String) ?? (a["municipality"] as? String) ?? "?"
        }
        return Route(from: code(o), to: code(d))
    }

    /// Airline-style callsigns only (3 letters + digits), like the page.
    static func eligible(_ cs: String) -> Bool { cs.range(of: #"^[A-Z]{3}\d{1,4}[A-Z]?$"#, options: .regularExpression) != nil }

    func route(for cs: String) async -> Route? {
        if let (r, t) = cache[cs], Date().timeIntervalSince(t) < 86400 { return r }
        guard Self.eligible(cs), Date().timeIntervalSince(lastCall) > 4,
              let url = URL(string: "https://api.adsbdb.com/v0/callsign/" + cs) else { return nil }
        lastCall = Date()
        let r = (try? await URLSession.shared.data(from: url)).flatMap { Self.parse($0.0) }
        cache[cs] = (r, Date())
        return r
    }
}
