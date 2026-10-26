import SwiftUI

enum Screen: Int, CaseIterable { case live, cards, poster
    var title: String { ["Live", "Hangar", "Sky poster"][rawValue] }
}

/// Polls the Pi (or the bundled demo data) and holds everything the views draw.
@MainActor
final class AppModel: ObservableObject {
    @Published var settings = OverheadSettings.load()
    @Published var aircraft: [Aircraft] = []
    @Published var home: Home?
    @Published var outline: [(Double, Double)] = []
    @Published var hangar: HangarFile?
    @Published var posters: [PosterEntry] = []
    @Published var poster: PosterSVG?
    @Published var posterIndex = 0
    @Published var interesting: [InterestingEntry] = []
    @Published var routes: [String: RouteLookup.Route] = [:]
    @Published var status = "connecting…"
    @Published var lastUpdate: Date?
    @Published var screen: Screen = .live
    @Published var focusIndex = 0
    @Published var cardsPage = 0
    @Published var showSettings = false

    let art: [String: ShapeArt]
    let scale: [String: Double]
    private var loop: Task<Void, Never>?
    private var slowTick = 0
    private let routeLookup = RouteLookup()
    private var demoBase: [Aircraft] = []
    private var demoStart = Date()

    init() {
        let data = Bundle.main.url(forResource: "shapes", withExtension: "json").flatMap { try? Data(contentsOf: $0) } ?? Data()
        (art, scale) = ShapeArt.load(data)
    }

    var night: Bool {
        switch settings.night {
        case "on": return true
        case "off": return false
        default: return home.map { Sun.isNight($0) } ?? false
        }
    }

    /// Positioned aircraft sorted nearest first.
    var sorted: [(a: Aircraft, nm: Double?)] {
        aircraft.map { a -> (Aircraft, Double?) in
            guard let h = home, a.hasPosition, let la = a.lat, let lo = a.lon else { return (a, nil) }
            return (a, Geo.nm(h, la, lo))
        }.sorted { ($0.1 ?? 1e9) < ($1.1 ?? 1e9) }
    }
    var focused: (a: Aircraft, nm: Double?)? {
        let s = sorted; guard !s.isEmpty else { return nil }
        return s[min(focusIndex, s.count - 1)]
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick()
                try? await Task.sleep(nanoseconds: UInt64(max(0.5, self.settings.pollSeconds) * 1_000_000_000))
            }
        }
    }
    func restart() { loop?.cancel(); loop = nil; slowTick = 0; aircraft = []; home = nil; outline = []; hangar = nil
        posters = []; poster = nil; interesting = []; demoBase = []; settings.save(); start() }

    func cycle(_ d: Int) {
        let n = Screen.allCases.count
        screen = Screen(rawValue: (screen.rawValue + d + n) % n) ?? .live
        if screen == .poster { Task { await loadPoster() } }
    }

    private func tick() async {
        if settings.demo { demoTick(); return }
        guard let url = settings.aircraftURL else { status = "bad host"; return }
        do {
            let d = try await fetch(url)
            let f = try JSONDecoder().decode(AircraftFile.self, from: d)
            aircraft = f.aircraft.filter { ($0.seen ?? 0) < 60 }
            lastUpdate = Date(); status = "\(aircraft.count) aircraft tracked"
        } catch { status = "no data from \(settings.host)" }
        if slowTick % 60 == 0 { await slowLoad() }
        if home == nil { home = Geo.estimateHome(aircraft) }
        slowTick += 1
        await lookupRoute()
        shareSnapshot()
    }

    /// Every ~60 s: receiver position, reception outline, logger files.
    private func slowLoad() async {
        if let u = settings.receiverURL, let d = try? await fetch(u), let r = try? JSONDecoder().decode(Receiver.self, from: d),
           let la = r.lat, let lo = r.lon { home = Home(lat: la, lon: lo) }
        if let u = settings.outlineURL, let d = try? await fetch(u), let o = Outline.parse(d) { outline = o }
        for b in settings.otBases {
            guard let u = URL(string: b + "interesting.json"), let d = try? await fetch(u),
                  let f = try? JSONDecoder().decode(InterestingFile.self, from: d) else { continue }
            interesting = f.aircraft.sorted { ($0.last ?? 0) > ($1.last ?? 0) }
            if let u = URL(string: b + "collection.json"), let d = try? await fetch(u) { hangar = try? JSONDecoder().decode(HangarFile.self, from: d) }
            if let u = URL(string: b + "posters/index.json"), let d = try? await fetch(u),
               let p = try? JSONDecoder().decode(PosterIndex.self, from: d) { posters = p.posters.sorted { $0.date > $1.date } }
            otBase = b; break
        }
    }
    private var otBase: String?

    func loadPoster() async {
        if posters.isEmpty && !settings.demo { poster = nil; return }
        if settings.demo {
            if let u = Bundle.main.url(forResource: "sample-poster", withExtension: "svg"), let d = try? Data(contentsOf: u) { poster = PosterSVG.parse(d) }
            exportPoster(); return
        }
        posterIndex = min(max(0, posterIndex), posters.count - 1)
        guard let b = otBase, let u = URL(string: b + "posters/" + posters[posterIndex].date + ".svg"), let d = try? await fetch(u) else { return }
        poster = PosterSVG.parse(d)
        if posterIndex == 0 { exportPoster() }
    }

    private func lookupRoute() async {
        guard settings.routes, let f = focused?.a, let cs = f.flight, routes[cs] == nil, RouteLookup.eligible(cs) else { return }
        if let r = await routeLookup.route(for: cs) { routes[cs] = r }
    }

    private func fetch(_ url: URL) async throws -> Data {
        var r = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 4)
        r.setValue("Overhead-tvOS", forHTTPHeaderField: "User-Agent")
        let (d, resp) = try await URLSession.shared.data(for: r)
        if let h = resp as? HTTPURLResponse, h.statusCode != 200 { throw URLError(.badServerResponse) }
        return d
    }

    // MARK: demo (bundled fake aircraft around 39.0N 98.0W, moved along their tracks)
    private func demoTick() {
        if demoBase.isEmpty {
            func res(_ n: String, _ e: String) -> Data? { Bundle.main.url(forResource: n, withExtension: e).flatMap { try? Data(contentsOf: $0) } }
            demoBase = res("sample-aircraft", "json").flatMap { try? JSONDecoder().decode(AircraftFile.self, from: $0) }?.aircraft ?? []
            home = OverheadSettings.demoHome; demoStart = Date()
            hangar = res("sample-collection", "json").flatMap { try? JSONDecoder().decode(HangarFile.self, from: $0) }
            interesting = res("sample-interesting", "json").flatMap { try? JSONDecoder().decode(InterestingFile.self, from: $0) }?.aircraft ?? []
            outline = (0..<36).map { i in let b = Double(i) * 10 * .pi / 180, r = (0.6 + 0.25 * sin(Double(i) * 1.7)) * 2.6
                return (39.0 + r * cos(b) / 1.0, -98.0 + r * sin(b) / cos(39 * .pi / 180)) }
        }
        let dt = Date().timeIntervalSince(demoStart)
        aircraft = demoBase.map { a in
            var b = a
            if let la = a.lat, let lo = a.lon, let gs = a.gs, let tr = a.track {
                let nm = gs * dt / 3600, r = tr * .pi / 180
                b.lat = la + nm * cos(r) / 60; b.lon = lo + nm * sin(r) / 60 / cos(la * .pi / 180)
            }
            return b
        }
        lastUpdate = Date(); status = "\(aircraft.count) aircraft tracked · DEMO DATA"
        shareSnapshot()
    }

    /// Top Shelf snapshot (count + nearest callsign), at most every 30 s.
    private var lastShare = Date.distantPast
    private func shareSnapshot() {
        guard Date().timeIntervalSince(lastShare) > 30 else { return }
        lastShare = Date()
        SharedState.write(count: aircraft.count, nearest: focused?.a.callsign)
        if !sharedPoster { Task { await loadPoster() } }
    }
    private var sharedPoster = false

    /// Renders the current poster to a PNG in the App Group for the Top Shelf image.
    private func exportPoster() {
        guard let p = poster, let url = SharedState.posterURL else { return }
        let r = ImageRenderer(content: PosterCanvas(poster: p, night: false).frame(width: 600, height: 600 * p.height / p.width))
        r.scale = 2
        if let img = r.uiImage, let png = img.pngData() { try? png.write(to: url, options: .atomic); sharedPoster = true }
    }
}
