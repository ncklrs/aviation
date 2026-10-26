import Foundation

/// Port of overhead.html shapeFor / whyInteresting / rarity. Tables come from TypeTable.swift (generated).
enum Classify {
    private static func re(_ p: String, _ ci: Bool = false) -> NSRegularExpression {
        try! NSRegularExpression(pattern: p, options: ci ? [.caseInsensitive] : [])
    }
    private static let rules: [(NSRegularExpression, String)] = TypeTable.rules.map { (re($0.0), $0.1) }
    private static let wide = re(TypeTable.wide), quad = re(TypeTable.quad)
    private static let leg = re(TypeTable.legendary), epic = re(TypeTable.epic)
    private static let medevac = re(TypeTable.medevac, true)
    private static let c17 = re("^(C17|C5M)$")
    private static let bizDesc = re("GULFSTREAM|GLOBAL \\d|BD-700|FALCON|CHALLENGER|LEARJET|CITATION|PHENOM", true)
    private static let lightDesc = re("LEARJET|CITATION|PHENOM", true)

    static func hit(_ r: NSRegularExpression, _ s: String) -> Bool {
        r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    /// Drawing class for an aircraft (same order and fallbacks as the web page).
    static func shape(_ a: Aircraft) -> String {
        let t = (a.t ?? "").uppercased().trimmingCharacters(in: .whitespaces)
        if !t.isEmpty && !hit(c17, t) && hit(wide, t) { return "widebody" }
        if !t.isEmpty { for (r, s) in rules where hit(r, t) { return s } }
        let d = a.desc ?? ""
        if hit(bizDesc, d) { return hit(lightDesc, d) ? "bizjet-light" : "bizjet" }
        let c = (a.category ?? "").uppercased(), mil = a.dbFlags & 1 != 0
        if c == "A7" { return "heli" }
        if c == "A6" { return "fighter" }
        if mil && (c == "A3" || c == "A4" || c == "A5") { return "milcargo" }
        if c == "A5" { return "widebody" }
        if c == "A3" || c == "A4" { return "airliner" }
        if c == "A2" { return "bizjet" }
        if c.isEmpty, let al = a.alt, al >= TypeTable.highFt { return "airliner" }
        return "cessna"
    }

    static func label(_ shape: String) -> String { TypeTable.labels[shape] ?? shape }

    /// Reasons an aircraft is interesting, highest priority first (subset of the page's list).
    static func why(_ a: Aircraft) -> [String] {
        var w: [String] = []
        let f = a.dbFlags, sq = a.squawk ?? "", t = (a.t ?? "").uppercased(), al = a.alt ?? 0
        if sq == "7500" { w.append("Hijack 7500") } else if sq == "7600" { w.append("Radio failure 7600") }
        else if sq == "7700" { w.append("Emergency 7700") }
        else if let e = a.emergency, e != "none", !e.isEmpty { w.append("Emergency") }
        if f & 1 != 0 { w.append("Military") }
        if f & 2 != 0 { w.append("Flagged interesting") }
        if f & 4 != 0 { w.append("PIA") }
        if f & 8 != 0 { w.append("LADD") }
        if a.category == "A7" || TypeTable.helis.contains(shape(a)) { w.append("Helicopter") }
        if hit(medevac, [a.flight ?? "", a.ownOp ?? "", a.desc ?? ""].joined(separator: " ")) { w.append("Medevac") }
        if hit(quad, t) { w.append("Four-engine") } else if hit(wide, t) { w.append("Widebody") }
        if al > 45000 { w.append("Very high") }
        if (a.gs ?? 0) > 550 { w.append("Very fast") }
        if !t.isEmpty && !TypeTable.common.contains(t) && !w.contains("Helicopter") && !w.contains("Military") { w.append("Rare type") }
        return w
    }

    static let tiers = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

    static func rarity(_ t: String, tails: Int, mil: Bool, rotor: Bool) -> String {
        let t = t.uppercased()
        if !t.isEmpty && hit(leg, t) { return "Legendary" }
        if mil || rotor || (!t.isEmpty && hit(epic, t)) { return "Epic" }
        if tails >= 25 { return "Common" }
        if TypeTable.common.contains(t) { return tails >= 8 ? "Common" : "Uncommon" }
        return tails >= 8 ? "Uncommon" : "Rare"
    }
}
