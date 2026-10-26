import SwiftUI

/// Hangar: one trading card per type ever seen (ot/collection.json). 10 per page, ▲ ▼ pages. Full width.
struct CardsView: View {
    @EnvironmentObject var model: AppModel
    static let perPage = 10
    struct Card: Identifiable { var id: String; var t: HangarType; var tier: String }

    var cards: [Card] {
        let types = model.hangar?.types ?? [:]
        return types.map { k, v in Card(id: k, t: v, tier: v.rarity ?? Classify.rarity(k, tails: v.tails ?? 0, mil: v.mil ?? false, rotor: v.rotor ?? false)) }
            .sorted { (Classify.tiers.firstIndex(of: $0.tier) ?? 0, $0.t.first ?? 0) > (Classify.tiers.firstIndex(of: $1.tier) ?? 0, $1.t.first ?? 0) }
    }

    var body: some View {
        let th = model.night ? Theme.night : Theme.day, all = cards
        let pages = max(1, (all.count + Self.perPage - 1) / Self.perPage), pg = min(model.cardsPage, pages - 1)
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("The Hangar").font(Fonts.serif(56, italic: true)).foregroundStyle(th.ink)
                Spacer()
                Text("\(all.count) types · " + Classify.tiers.reversed().map { t in "\(all.filter { $0.tier == t }.count) \(t)" }.joined(separator: " · "))
                    .font(Fonts.mono(22)).foregroundStyle(th.mid)
            }
            Rectangle().fill(th.ink).frame(height: 2)
            if all.isEmpty {
                Spacer()
                Text("No collection yet. The Pi logger writes ot/collection.json.").font(Fonts.serif(36, italic: true)).foregroundStyle(th.mid)
                Spacer()
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: 5), spacing: 24) {
                    ForEach(Array(all.dropFirst(pg * Self.perPage).prefix(Self.perPage))) { c in card(c, th) }
                }
                Spacer(minLength: 0)
                Text("page \(pg + 1) of \(pages) · ▲ ▼").font(Fonts.mono(20)).foregroundStyle(th.faint).frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func card(_ c: Card, _ th: Theme) -> some View {
        let shape = Classify.shape(Aircraft(hex: c.id, t: c.id, desc: c.t.desc, category: (c.t.rotor ?? false) ? "A7" : "", dbFlags: (c.t.mil ?? false) ? 1 : 0))
        let marks = ["Common": "●", "Uncommon": "●●", "Rare": "★", "Epic": "★★", "Legendary": "★★★"][c.tier] ?? ""
        let heavy = c.tier == "Epic" || c.tier == "Legendary"
        return VStack(alignment: .leading, spacing: 6) {
            HStack { Text(c.id).font(Fonts.mono(34)).bold(); Spacer(); Text(marks).font(.system(size: 22)) }.foregroundStyle(th.ink)
            PlaneDrawing(shape: shape, showGround: false).frame(height: 110)
            Text(c.t.desc ?? Classify.label(shape)).font(Fonts.serif(20, italic: true)).foregroundStyle(th.mid).lineLimit(1)
            Text(c.tier.uppercased()).font(Fonts.kicker(16)).tracking(4).foregroundStyle(th.ink)
            Text("\(c.t.n ?? 0) seen · \(c.t.tails ?? 0) tails" + (c.t.best_km.map { String(format: " · %.0f km", $0) } ?? ""))
                .font(Fonts.mono(16)).foregroundStyle(th.mid)
        }
        .padding(16)
        .background(hatch(c.tier, th))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(th.ink, lineWidth: heavy ? 5 : 2))
    }

    /// Line-hatching "holo" for Rare and above, like the page.
    private func hatch(_ tier: String, _ th: Theme) -> some View {
        let angles: [Double] = ["Rare": [45], "Epic": [45, -45], "Legendary": [45, -45, 0]][tier] ?? []
        return Canvas { ctx, size in
            for a in angles {
                let r = a * .pi / 180, L = size.width + size.height, step: CGFloat = 14
                var p = Path(); var o = -L
                while o < L {
                    let cx = size.width / 2 + o * cos(r + .pi / 2), cy = size.height / 2 + o * sin(r + .pi / 2)
                    p.move(to: CGPoint(x: cx - L * cos(r), y: cy - L * sin(r))); p.addLine(to: CGPoint(x: cx + L * cos(r), y: cy + L * sin(r)))
                    o += step
                }
                ctx.stroke(p, with: .color(th.faint.opacity(0.35)), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
