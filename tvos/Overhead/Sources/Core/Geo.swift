import Foundation

enum Geo {
    /// Flat-earth offset in nm (east, south-positive y) like the page's toXY.
    static func xy(_ h: Home, _ lat: Double, _ lon: Double) -> (Double, Double) {
        ((lon - h.lon) * 60 * cos(h.lat * .pi / 180), -(lat - h.lat) * 60)
    }
    /// Great-circle distance in nm.
    static func nm(_ h: Home, _ lat: Double, _ lon: Double) -> Double {
        let r = Double.pi / 180, p1 = h.lat * r, p2 = lat * r, dp = (lat - h.lat) * r, dl = (lon - h.lon) * r
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * 3440.065 * atan2(sqrt(a), sqrt(1 - a))
    }
    static func compass(_ deg: Double) -> String {
        let n = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return n[Int(((deg.truncatingRemainder(dividingBy: 360) + 360 + 22.5) / 45)) % 8]
    }
    /// Median of positioned aircraft, used when receiver.json has no position.
    static func estimateHome(_ list: [Aircraft]) -> Home? {
        let la = list.compactMap { $0.hasPosition ? $0.lat : nil }.sorted()
        let lo = list.compactMap { $0.hasPosition ? $0.lon : nil }.sorted()
        guard la.count >= 2 else { return nil }
        return Home(lat: la[la.count / 2], lon: lo[lo.count / 2], estimated: true)
    }
    static func flightLevel(_ ft: Double?) -> String {
        guard let ft = ft else { return "—" }
        if ft <= 0 { return "GND" }
        if ft >= TypeTable.highFt { return String(format: "FL%03d", Int((ft / 100).rounded())) }
        return grouped(ft) + " ft"
    }
    static func grouped(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.locale = Locale(identifier: "en_US"); f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v.rounded())) ?? "\(Int(v))"
    }
}
