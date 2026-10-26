import Foundation

/// One aircraft from readsb / tar1090 `aircraft.json`. Every field is optional; decoding never throws on odd values.
struct Aircraft: Decodable, Identifiable, Equatable {
    var hex: String
    var flight: String?
    var r: String?
    var t: String?
    var desc: String?
    var ownOp: String?
    var category: String?
    var squawk: String?
    var emergency: String?
    var dbFlags: Int
    var altBaro: Double?
    var onGround: Bool
    var altGeom: Double?
    var gs: Double?
    var track: Double?
    var trueHeading: Double?
    var baroRate: Double?
    var lat: Double?
    var lon: Double?
    var seen: Double?
    var seenPos: Double?

    var id: String { hex }

    enum K: String, CodingKey {
        case hex, flight, r, t, desc, ownOp, category, squawk, emergency, dbFlags
        case alt_baro, alt_geom, gs, track, true_heading, baro_rate, geom_rate, lat, lon, seen, seen_pos
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        func s(_ k: K) -> String? { (try? c.decodeIfPresent(String.self, forKey: k)) ?? nil }
        func n(_ k: K) -> Double? {
            if let v = (try? c.decodeIfPresent(Double.self, forKey: k)) ?? nil, v.isFinite { return v }
            return nil
        }
        hex = (s(.hex) ?? "??????").lowercased()
        flight = s(.flight)?.trimmingCharacters(in: .whitespaces)
        r = s(.r); t = s(.t)?.uppercased().trimmingCharacters(in: .whitespaces)
        desc = s(.desc); ownOp = s(.ownOp); category = s(.category)?.uppercased()
        squawk = s(.squawk); emergency = s(.emergency)
        dbFlags = (try? c.decodeIfPresent(Int.self, forKey: .dbFlags)) ?? nil ?? 0
        altBaro = n(.alt_baro); onGround = s(.alt_baro) == "ground"
        altGeom = n(.alt_geom); gs = n(.gs); track = n(.track); trueHeading = n(.true_heading)
        baroRate = n(.baro_rate) ?? n(.geom_rate)
        lat = n(.lat); lon = n(.lon); seen = n(.seen); seenPos = n(.seen_pos)
    }

    init(hex: String, flight: String? = nil, t: String? = nil, desc: String? = nil, category: String? = nil,
         dbFlags: Int = 0, alt: Double? = nil, lat: Double? = nil, lon: Double? = nil) {
        self.hex = hex; self.flight = flight; self.t = t; self.desc = desc; self.category = category
        self.dbFlags = dbFlags; self.altBaro = alt; self.lat = lat; self.lon = lon
        onGround = false; r = nil; ownOp = nil; squawk = nil; emergency = nil
        altGeom = nil; gs = nil; track = nil; trueHeading = nil; baroRate = nil; seen = nil; seenPos = nil
    }

    /// Altitude in feet (baro, else geometric), nil if unknown. Ground is 0.
    var alt: Double? { onGround ? 0 : (altBaro ?? altGeom) }
    var heading: Double { track ?? trueHeading ?? 0 }
    var callsign: String {
        if let f = flight, !f.isEmpty { return f }
        if let r = r, !r.isEmpty { return r }
        return "#" + hex.uppercased()
    }
    var hasPosition: Bool { lat != nil && lon != nil && (seenPos ?? 0) < 60 }
}

struct AircraftFile: Decodable {
    var now: Double?
    var messages: Int?
    var aircraft: [Aircraft]
}

struct Receiver: Decodable { var lat: Double?; var lon: Double? }

struct Home: Equatable { var lat: Double; var lon: Double; var estimated = false }

enum Outline {
    /// readsb `outline.json`: `actualRange.last24h.points` (or alltime / plain `points`) as [lat, lon, ...].
    static func parse(_ data: Data) -> [(Double, Double)]? {
        guard let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var pts: [Any]?
        if let a = j["actualRange"] as? [String: Any] {
            pts = ((a["last24h"] as? [String: Any])?["points"] as? [Any]) ?? ((a["alltime"] as? [String: Any])?["points"] as? [Any])
        }
        if pts == nil { pts = j["points"] as? [Any] }
        guard let p = pts else { return nil }
        let out: [(Double, Double)] = p.compactMap { e in
            guard let v = e as? [Any], v.count >= 2, let la = (v[0] as? NSNumber)?.doubleValue,
                  let lo = (v[1] as? NSNumber)?.doubleValue, la.isFinite, lo.isFinite else { return nil }
            return (la, lo)
        }
        return out.count > 2 ? out : nil
    }
}

/// Logger `ot/collection.json` (Hangar). Only types, tails, counts, dates, closest pass. No positions.
struct HangarType: Decodable {
    var first: Double?; var last: Double?; var n: Int?; var tails: Int?
    var best_km: Double?; var mil: Bool?; var rotor: Bool?; var desc: String?; var rarity: String?
}
struct HangarUnlock: Decodable { var t: String; var at: Double? }
struct HangarFile: Decodable {
    var now: Double?
    var types: [String: HangarType]
    var unlocks: [HangarUnlock]?
}

/// Poster archive `ot/posters/index.json`.
struct PosterEntry: Decodable, Identifiable {
    var date: String; var aircraft: Int?; var rarest: String?; var rarest_tier: String?; var farthest_km: Double?
    var id: String { date }
}
struct PosterIndex: Decodable { var posters: [PosterEntry] }

/// interesting.json written by the Pi logger (recent military / medevac / rotorcraft list).
struct InterestingEntry: Decodable, Identifiable {
    var hex: String; var flight: String?; var t: String?; var desc: String?; var why: [String]?; var last: Double?
    var id: String { hex + String(last ?? 0) }
}
struct InterestingFile: Decodable { var aircraft: [InterestingEntry] }
