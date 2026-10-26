import Foundation

/// New-card reveal trigger, the same rule as overhead.html `revealPick()` (cases in tools/reveal_cases.json).
/// An unlock (type first seen) is revealed once: if it's under 30 min old, not seen before, not from the future.
/// At most `batch` per poll (newest), oldest first.
enum Reveal {
    static let maxAge: Double = 1800, batch = 3, queueCap = 5, seenCap = 60
    static let seenKey = "reveal:v1"

    static func key(_ u: HangarUnlock) -> String { "\(u.t)@\(Int(u.at ?? 0))" }

    static func pick(_ unlocks: [HangarUnlock], seen: inout [String], now: Double,
                     maxAge: Double = Reveal.maxAge, batch: Int = Reveal.batch) -> [HangarUnlock] {
        var out: [HangarUnlock] = []
        for u in unlocks.sorted(by: { ($0.at ?? 0) < ($1.at ?? 0) }) {
            guard let at = u.at else { continue }
            let k = key(u)
            if seen.contains(k) || now - at > maxAge || at > now + 60 { continue }
            out.append(u); seen.append(k)
        }
        if seen.count > seenCap { seen.removeFirst(seen.count - seenCap) }
        return Array(out.suffix(batch))
    }

    static func loadSeen(_ d: UserDefaults = .standard) -> [String]? { d.stringArray(forKey: seenKey) }
    static func saveSeen(_ s: [String], _ d: UserDefaults = .standard) { d.set(s, forKey: seenKey) }

    /// Glow colours by tier (hex), shared look with the web overlay.
    static let glow = ["Common": "#b0bec5", "Uncommon": "#43a047", "Rare": "#1e88e5", "Epic": "#ab47bc", "Legendary": "#ffb300"]
    static let particles = ["Common": 0, "Uncommon": 10, "Rare": 18, "Epic": 30, "Legendary": 48]
}
