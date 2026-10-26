import SwiftUI

/// Full-screen "new card" moment, like the web page: face-down card back flies in and spins (~1.2 s),
/// lands face-up with a holo shine sweep, tier-coloured glow and particle burst, holds ~6 s,
/// then shrinks toward the corner (into the Hangar). Reduce Motion: static card, no spin/shine/particles.
struct RevealOverlay: View {
    let item: RevealItem
    let waiting: Int
    let done: () -> Void
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var angle: Double = -900
    @State private var landed = false
    @State private var shine: CGFloat = -1.4
    @State private var burst = false
    @State private var glow: CGFloat = 0
    @State private var leaving = false
    @State private var shown = false

    private let cardW: CGFloat = 520
    private var cardH: CGFloat { cardW * 88 / 63 }
    private var glowColor: Color { Color(hex: Reveal.glow[item.tier] ?? "#ffffff") }
    private var marks: String { ["Common": "●", "Uncommon": "●●", "Rare": "★", "Epic": "★★", "Legendary": "★★★"][item.tier] ?? "" }

    var body: some View {
        let th = model.night ? Theme.night : Theme.day
        ZStack {
            Color.black.opacity(shown ? 0.78 : 0).ignoresSafeArea()
            VStack {
                Text("NEW CARD").font(.system(size: 64, weight: .bold)).tracking(18).foregroundStyle(.white)
                    .opacity(landed && !leaving ? 1 : 0)
                Spacer()
                Text("\(marks) \(item.tier.uppercased()) · \(item.total) IN THE HANGAR" + (waiting > 0 ? " · \(waiting) MORE" : ""))
                    .font(.system(size: 28, weight: .medium)).tracking(6).foregroundStyle(.white.opacity(0.85))
                    .opacity(landed && !leaving ? 1 : 0)
            }
            .padding(.vertical, 40)

            ZStack {
                if !reduceMotion { particles }
                FlipCard(angle: angle,
                         front: AnyView(front(th)),
                         back: AnyView(CardBack()))
                    .frame(width: cardW, height: cardH)
                    .shadow(color: glowColor.opacity(glow > 0 ? 0.95 : 0), radius: glow)
            }
            .scaleEffect(leaving ? 0.06 : (landed || reduceMotion ? 1 : 0.35))
            .offset(x: leaving ? 760 : 0, y: leaving ? -440 : (landed || reduceMotion ? 0 : 700))
            .opacity(leaving ? 0.2 : 1)
        }
        .onAppear(perform: run)
    }

    private func front(_ th: Theme) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22).fill(Theme.day.paper)
            HangarCardView(code: item.code, t: item.t, tier: item.tier, big: true)
                .environmentObject(model)
            if !reduceMotion {
                GeometryReader { g in
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .white.opacity(0.95), location: 0.45),
                                           .init(color: Color(red: 1, green: 0.9, blue: 0.98).opacity(0.6), location: 0.5),
                                           .init(color: Color(red: 0.78, green: 0.94, blue: 1).opacity(0.7), location: 0.55), .init(color: .clear, location: 1)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: g.size.width * 0.6, height: g.size.height * 1.6)
                        .rotationEffect(.degrees(20))
                        .offset(x: shine * g.size.width, y: -g.size.height * 0.3)
                        .blendMode(.screen)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white, lineWidth: 8))
    }

    private var particles: some View {
        let n = Reveal.particles[item.tier] ?? 0
        var seed = UInt64(item.code.unicodeScalars.reduce(7) { $0 &* 31 &+ UInt64($1.value) })
        func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
        let pts: [(dx: Double, dy: Double, s: Double)] = (0..<n).map { _ in
            let a = rnd() * 2 * .pi, d = 360 + rnd() * 480
            return (cos(a) * d, sin(a) * d * 0.62, 10 + rnd() * 26)
        }
        return ZStack {
            ForEach(0..<pts.count, id: \.self) { i in
                Circle().fill(glowColor).frame(width: pts[i].s, height: pts[i].s)
                    .shadow(color: glowColor, radius: 8)
                    .offset(x: burst ? pts[i].dx : 0, y: burst ? pts[i].dy : 0)
                    .opacity(burst ? 0 : (landed ? 1 : 0))
            }
        }
    }

    private func after(_ s: Double, _ f: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + s, execute: f)
    }

    private func run() {
        withAnimation(.easeIn(duration: 0.35)) { shown = true }
        if reduceMotion {
            angle = 0; landed = true; glow = 0
            after(6) { withAnimation(.easeInOut(duration: 0.4)) { shown = false; leaving = true }; after(0.45, done) }
            return
        }
        withAnimation(.timingCurve(0.15, 0.75, 0.25, 1, duration: 1.2)) { angle = 0; landed = true }
        after(1.2) {
            withAnimation(.easeOut(duration: 0.25)) { glow = 90 }
            withAnimation(.easeInOut(duration: 0.9)) { shine = 1.4 }
            withAnimation(.timingCurve(0.1, 0.8, 0.3, 1, duration: 1.9)) { burst = true }
            after(0.3) { withAnimation(.easeOut(duration: 1.5)) { glow = 40 } }
        }
        after(7.2) {
            withAnimation(.easeIn(duration: 0.8)) { leaving = true }
            withAnimation(.linear(duration: 0.8)) { shown = false }
            after(0.85, done)
        }
    }
}

/// Animatable Y-axis flip: shows the back while the card faces away.
struct FlipCard: View, Animatable {
    var angle: Double
    let front: AnyView
    let back: AnyView
    var animatableData: Double { get { angle } set { angle = newValue } }
    var body: some View {
        let faceUp = cos(angle * .pi / 180) >= 0
        ZStack {
            if faceUp { front } else { back.rotation3DEffect(.degrees(180), axis: (0, 1, 0)) }
        }
        .rotation3DEffect(.degrees(angle), axis: (0, 1, 0), perspective: 0.45)
        .rotation3DEffect(.degrees(angle / 900 * 8), axis: (0, 0, 1))
    }
}

/// Branded card back: dark navy, radar rings, plane mark, "Overhead".
struct CardBack: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22).fill(Color(hex: "#0d1b2a"))
            RoundedRectangle(cornerRadius: 22).stroke(.white, lineWidth: 8)
            RoundedRectangle(cornerRadius: 14).stroke(.white, lineWidth: 2).padding(26)
            VStack(spacing: 18) {
                ZStack {
                    Circle().stroke(.white, lineWidth: 3).frame(width: 260)
                    Circle().stroke(.white, style: StrokeStyle(lineWidth: 2, dash: [6, 6])).frame(width: 170)
                    Circle().stroke(.white, lineWidth: 2).frame(width: 76)
                    Rectangle().fill(.white).frame(width: 2, height: 300)
                    Rectangle().fill(.white).frame(width: 300, height: 2)
                    Image(systemName: "airplane").font(.system(size: 64)).rotationEffect(.degrees(-90)).foregroundStyle(.white)
                }
                Text("Overhead").font(Fonts.serif(54, italic: true)).foregroundStyle(.white)
                Text("PLANE TRADING CARDS").font(.system(size: 18, weight: .medium)).tracking(6).foregroundStyle(.white.opacity(0.9))
            }
        }
    }
}
