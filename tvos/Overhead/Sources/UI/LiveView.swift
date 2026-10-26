import SwiftUI

/// TV layout: left half = live sky map, right half = focused / nearest aircraft card + recent & interesting.
struct LiveView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        let th = model.night ? Theme.night : Theme.day
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Overhead").font(Fonts.serif(56, italic: true)).foregroundStyle(th.ink)
                Spacer()
                Text("◀ ▶ views · ▲ ▼ aircraft · ⏯ settings").font(Fonts.kicker(20)).foregroundStyle(th.faint)
            }
            Rectangle().fill(th.ink).frame(height: 2).padding(.vertical, 12)
            HStack(spacing: 40) {
                MapPanel().aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity)
                InfoPanel().frame(maxWidth: .infinity, alignment: .topLeading)
            }
            Rectangle().fill(th.faint).frame(height: 1).padding(.vertical, 10)
            HStack {
                Text(model.status).font(Fonts.mono(22)).foregroundStyle(th.mid)
                Spacer()
                Text(model.lastUpdate.map { "updated " + $0.formatted(date: .omitted, time: .shortened) } ?? "—")
                    .font(Fonts.mono(22)).foregroundStyle(th.mid)
            }
        }
    }
}

struct MapPanel: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        let th = model.night ? Theme.night : Theme.day
        let list = model.sorted, focus = model.focused?.a.hex, R = model.settings.mapNm
        Canvas { ctx, size in
            guard let h = model.home else {
                ctx.draw(Text("waiting for position…").font(Fonts.serif(32, italic: true)).foregroundColor(th.mid), at: CGPoint(x: size.width / 2, y: size.height / 2))
                return
            }
            let c = CGPoint(x: size.width / 2, y: size.height / 2), s = min(size.width, size.height) / 2 / R
            let P: (Double, Double) -> CGPoint = { la, lo in let (x, y) = Geo.xy(h, la, lo); return CGPoint(x: c.x + x * s, y: c.y + y * s) }
            // range rings + ticks
            for r in [R / 5, R / 2, R] {
                let rr = r * s
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: 2 * rr, height: 2 * rr)), with: .color(th.faint), lineWidth: 1.5)
                ctx.draw(Text(model.settings.distance(r)).font(Fonts.mono(18)).foregroundColor(th.faint), at: CGPoint(x: c.x + rr * 0.71 + 6, y: c.y - rr * 0.71 - 6), anchor: .bottomLeading)
            }
            ctx.draw(Text("N").font(Fonts.kicker(22)).foregroundColor(th.mid), at: CGPoint(x: c.x, y: c.y - R * s - 4), anchor: .bottom)
            // reception outline (readsb outline.json), dashed like the page
            if model.outline.count > 2 {
                var p = Path(); for (i, q) in model.outline.enumerated() { let pt = P(q.0, q.1); i == 0 ? p.move(to: pt) : p.addLine(to: pt) }
                p.closeSubpath()
                ctx.stroke(p, with: .color(th.faint), style: StrokeStyle(lineWidth: 2, dash: [10, 6]))
            }
            // home
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12)), with: .color(th.ink))
            ctx.clip(to: Path(ellipseIn: CGRect(x: c.x - R * s - 30, y: c.y - R * s - 30, width: 2 * R * s + 60, height: 2 * R * s + 60)))
            // aircraft, farthest first so near ones sit on top
            for (a, _) in list.reversed() {
                guard a.hasPosition, let la = a.lat, let lo = a.lon else { continue }
                let p = P(la, lo), tags = Classify.why(a), hot = tags.contains { $0.hasPrefix("Military") || $0.hasPrefix("Medevac") || $0.hasPrefix("Emergency") || $0.hasPrefix("Hijack") || $0.hasPrefix("Radio") }
                let big = a.hex == focus
                let k: CGFloat = big ? 1.6 : 1.1
                let r = a.heading * .pi / 180
                func rot(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: p.x + (x * cos(r) - y * sin(r)) * k, y: p.y + (x * sin(r) + y * cos(r)) * k) }
                var arrow = Path(); arrow.move(to: rot(0, -16)); arrow.addLine(to: rot(10, 12)); arrow.addLine(to: rot(0, 6)); arrow.addLine(to: rot(-10, 12)); arrow.closeSubpath()
                ctx.stroke(arrow, with: .color(th.halo), style: StrokeStyle(lineWidth: 8, lineJoin: .round))   // white halo
                ctx.fill(arrow, with: .color(th.ink))
                if hot || big {
                    let rr: CGFloat = big ? 34 : 26
                    ctx.stroke(Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: 2 * rr, height: 2 * rr)), with: .color(th.ink),
                               style: StrokeStyle(lineWidth: big ? 3 : 2, dash: big ? [] : [5, 4]))
                }
                let label = a.callsign + "  " + model.settings.altitude(a.alt)
                let lp = CGPoint(x: p.x + 22 * k, y: p.y - 4)
                let txt = { (col: Color) in Text(label).font(Fonts.mono(big ? 26 : 20)).fontWeight(big ? .bold : .regular).foregroundColor(col) }
                for (dx, dy) in [(-2.0, 0.0), (2, 0), (0, -2), (0, 2), (-1.5, -1.5), (1.5, 1.5), (-1.5, 1.5), (1.5, -1.5)] {
                    ctx.draw(txt(th.halo), at: CGPoint(x: lp.x + dx, y: lp.y + dy), anchor: .leading)
                }
                ctx.draw(txt(th.ink), at: lp, anchor: .leading)
                if let tag = tags.first(where: { $0.hasPrefix("Military") || $0.hasPrefix("Medevac") || $0.hasPrefix("Emergency") }) {
                    ctx.draw(Text(tag.uppercased()).font(Fonts.kicker(16)).foregroundColor(th.mid), at: CGPoint(x: lp.x, y: lp.y + 24), anchor: .leading)
                }
            }
        }
    }
}

struct InfoPanel: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        let th = model.night ? Theme.night : Theme.day
        VStack(alignment: .leading, spacing: 14) {
            if let f = model.focused {
                let a = f.a, nm = f.nm
                let shape = Classify.shape(a), tags = Classify.why(a)
                Text(kicker(a, nm)).font(Fonts.kicker(24)).tracking(6).foregroundStyle(th.mid)
                Text(a.callsign).font(Fonts.mono(96)).foregroundStyle(th.ink).lineLimit(1).minimumScaleFactor(0.5)
                Text("\(a.t ?? "?") · \(a.desc ?? Classify.label(shape))").font(Fonts.serif(34, italic: true)).foregroundStyle(th.mid).lineLimit(1)
                if let cs = a.flight, let r = model.routes[cs] {
                    Text("\(r.from) → \(r.to)").font(Fonts.serif(40)).foregroundStyle(th.ink)
                }
                PlaneDrawing(shape: shape, heading: a.heading, climbFpm: a.baroRate ?? 0).frame(height: 230)
                HStack(spacing: 44) {
                    stat(model.settings.altitude(a.alt), "ALTITUDE")
                    stat(model.settings.speed(a.gs), "SPEED")
                    stat(model.settings.distance(nm), "DISTANCE")
                    stat("\(Int(a.heading))° \(Geo.compass(a.heading))", "HEADING")
                }
                if !tags.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(Array(tags.prefix(4)), id: \.self) { t in
                            Text(t.uppercased()).font(Fonts.kicker(18)).tracking(3).padding(.horizontal, 12).padding(.vertical, 6)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(th.ink, lineWidth: 2)).foregroundStyle(th.ink)
                        }
                    }
                }
            } else {
                Text("Quiet skies").font(Fonts.serif(64, italic: true)).foregroundStyle(th.mid)
                Text("No aircraft in range right now.").font(Fonts.serif(32)).foregroundStyle(th.faint)
            }
            Rectangle().fill(th.faint).frame(height: 1).padding(.top, 8)
            Text("RECENT & INTERESTING").font(Fonts.kicker(20)).tracking(6).foregroundStyle(th.mid)
            ForEach(Array(recent.prefix(5))) { row in
                HStack {
                    Text(row.call).font(Fonts.mono(26)).foregroundStyle(th.ink).frame(width: 220, alignment: .leading)
                    Text(row.type).font(Fonts.serif(26, italic: true)).foregroundStyle(th.mid).lineLimit(1)
                    Spacer()
                    Text(row.note).font(Fonts.kicker(18)).tracking(2).foregroundStyle(th.mid)
                }
            }
        }
    }

    /// In-view tagged aircraft first, then the logger's interesting.json (or demo list).
    struct Row: Identifiable { var id: String; var call: String; var type: String; var note: String }
    private var recent: [Row] {
        let tagRe = #"^(Military|Helicopter|Medevac|Hijack|Emergency|Radio)"#
        var rows: [Row] = []
        for (a, _) in model.sorted { if let w = Classify.why(a).first(where: { $0.range(of: tagRe, options: .regularExpression) != nil }) {
            rows.append(Row(id: a.hex, call: a.callsign, type: a.t ?? "", note: "NOW · " + w.uppercased())) } }
        for e in model.interesting where !rows.contains(where: { $0.id == e.hex }) {
            guard let w = (e.why ?? []).first(where: { $0.range(of: tagRe, options: .regularExpression) != nil }) else { continue }
            let ago = e.last.map { Date(timeIntervalSince1970: $0).formatted(.relative(presentation: .named)) } ?? ""
            rows.append(Row(id: e.hex, call: e.flight ?? e.hex.uppercased(), type: e.t ?? "", note: w.uppercased() + " · " + ago))
        }
        return rows
    }

    private func kicker(_ a: Aircraft, _ nm: Double?) -> String {
        let n = model.sorted.count, i = min(model.focusIndex, max(0, n - 1)) + 1
        let kind = (a.alt ?? 0) >= TypeTable.highFt ? "UP HIGH" : "NEARBY"
        return "\(model.focusIndex == 0 ? "NEAREST" : kind) · \(i) OF \(n)"
    }
    private func stat(_ v: String, _ l: String) -> some View {
        let th = model.night ? Theme.night : Theme.day
        return VStack(alignment: .leading, spacing: 2) {
            Text(v).font(Fonts.serif(44)).foregroundStyle(th.ink).lineLimit(1).minimumScaleFactor(0.6)
            Text(l).font(Fonts.kicker(16)).tracking(4).foregroundStyle(th.mid)
        }
    }
}
