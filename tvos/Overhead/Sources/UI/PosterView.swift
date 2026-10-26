import SwiftUI

/// Daily sky poster (ot/posters/YYYY-MM-DD.svg) drawn natively from the SVG subset. Left: poster, right: archive list.
struct PosterView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        let th = model.night ? Theme.night : Theme.day
        HStack(alignment: .top, spacing: 50) {
            PosterCanvas(poster: model.poster, night: model.night)
                .aspectRatio(CGFloat((model.poster?.width ?? 1200) / (model.poster?.height ?? 1600)), contentMode: .fit)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 14) {
                Text("Sky posters").font(Fonts.serif(56, italic: true)).foregroundStyle(th.ink)
                Rectangle().fill(th.ink).frame(height: 2)
                if model.posters.isEmpty {
                    Text(model.settings.demo ? "Demo poster (synthetic day)." : "No archive yet. overhead-poster.timer draws one each night at 23:55.")
                        .font(Fonts.serif(30, italic: true)).foregroundStyle(th.mid)
                }
                ForEach(Array(model.posters.prefix(9).enumerated()), id: \.element.id) { i, p in
                    HStack {
                        Text(i == model.posterIndex ? "▶" : " ").font(Fonts.mono(26)).foregroundStyle(th.ink)
                        Text(p.date).font(Fonts.mono(30)).foregroundStyle(th.ink)
                        Spacer()
                        Text("\(p.aircraft ?? 0) aircraft · \(p.rarest ?? "—")").font(Fonts.serif(26, italic: true)).foregroundStyle(th.mid)
                    }
                }
                Spacer()
                Text("▲ ▼ choose day").font(Fonts.mono(20)).foregroundStyle(th.faint)
            }
        }
        .task { if model.poster == nil { await model.loadPoster() } }
    }
}

struct PosterCanvas: View {
    let poster: PosterSVG?
    let night: Bool
    var body: some View {
        Canvas { ctx, size in
            guard let p = poster else { return }
            let s = min(size.width / p.width, size.height / p.height)
            let f: (Double, Double) -> CGPoint = { x, y in CGPoint(x: x * s, y: y * s) }
            func col(_ h: String?) -> Color? {
                guard let h = h, h != "none" else { return nil }
                if night { return h.lowercased() == "#f4efe4" ? .black : Theme.night.ink }
                return Color(hex: h)
            }
            for it in p.items {
                switch it {
                case let .rect(x, y, w, h, fill, stroke, width):
                    let r = Path(CGRect(x: x * s, y: y * s, width: w * s, height: h * s))
                    if let c = col(fill) { ctx.fill(r, with: .color(c)) }
                    if let c = col(stroke) { ctx.stroke(r, with: .color(c), lineWidth: max(1, width * s)) }
                case let .path(ops, fill, stroke, width, eo):
                    let path = Path(ops: ops, f)
                    if let c = col(fill) { ctx.fill(path, with: .color(c), style: FillStyle(eoFill: eo)) }
                    if let c = col(stroke) { ctx.stroke(path, with: .color(c.opacity(0.85)), style: StrokeStyle(lineWidth: max(0.6, width * s), lineCap: .round, lineJoin: .round)) }
                case let .text(str, x, y, size0, anchor, italic, sans):
                    let font: Font = sans ? .system(size: size0 * s, weight: .medium) : Fonts.serif(size0 * s, italic: italic)
                    let a: UnitPoint = anchor == "middle" ? .bottom : anchor == "end" ? .bottomTrailing : .bottomLeading
                    ctx.draw(Text(str).font(font).foregroundColor(night ? Theme.night.ink : Color(hex: "#111")), at: f(x, y), anchor: a)
                }
            }
        }
    }
}
