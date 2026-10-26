import SwiftUI

/// Day: black ink on white paper (the e-ink look). Night: dim red on black, like the page's night mode.
struct Theme {
    let ink: Color, mid: Color, faint: Color, paper: Color, halo: Color
    static let day = Theme(ink: .black, mid: Color(white: 0.33), faint: Color(white: 0.6), paper: .white, halo: .white)
    static let night = Theme(ink: Color(red: 0.85, green: 0.16, blue: 0.12), mid: Color(red: 0.55, green: 0.1, blue: 0.08),
                             faint: Color(red: 0.32, green: 0.06, blue: 0.05), paper: .black, halo: .black)
}

enum Fonts {
    static func serif(_ s: CGFloat, italic: Bool = false) -> Font { let f = Font.system(size: s, design: .serif); return italic ? f.italic() : f }
    static func mono(_ s: CGFloat) -> Font { .system(size: s, design: .monospaced) }
    static func kicker(_ s: CGFloat = 24) -> Font { .system(size: s, weight: .medium) }
}

extension Path {
    /// Build a path from parsed SVG ops through a point transform.
    init(ops: [PathOp], _ f: (Double, Double) -> CGPoint) {
        self.init()
        for op in ops {
            switch op {
            case let .move(x, y): move(to: f(x, y))
            case let .line(x, y): addLine(to: f(x, y))
            case let .curve(a, b, c, d, e, g): addCurve(to: f(e, g), control1: f(a, b), control2: f(c, d))
            case .close: closeSubpath()
            }
        }
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ")); if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        let v = UInt32(s, radix: 16) ?? 0
        self.init(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
    }
}
