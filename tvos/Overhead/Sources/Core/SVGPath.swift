import Foundation

/// Minimal SVG path-data parser (M m L l H h V v C c Z z) into absolute ops. Enough for art/paths.json and posters.
enum PathOp: Equatable {
    case move(Double, Double), line(Double, Double), curve(Double, Double, Double, Double, Double, Double), close
}

enum SVGPath {
    static func parse(_ d: String) -> [PathOp] {
        var ops: [PathOp] = []
        let ch = Array(d.utf8); var i = 0
        var cmd: UInt8 = 0, x = 0.0, y = 0.0, sx = 0.0, sy = 0.0

        func skip() { while i < ch.count, ch[i] == 32 || ch[i] == 44 || ch[i] == 10 || ch[i] == 9 || ch[i] == 13 { i += 1 } }
        func num() -> Double? {
            skip(); let st = i; var dot = false, exp = false
            if i < ch.count, ch[i] == 45 || ch[i] == 43 { i += 1 }
            while i < ch.count {
                let c = ch[i]
                if c >= 48 && c <= 57 { i += 1 }
                else if c == 46 && !dot && !exp { dot = true; i += 1 }
                else if (c == 101 || c == 69) && !exp { exp = true; i += 1; if i < ch.count, ch[i] == 45 || ch[i] == 43 { i += 1 } }
                else { break }
            }
            guard i > st, let s = String(bytes: ch[st..<i], encoding: .utf8), let v = Double(s) else { i = st; return nil }
            return v
        }
        while true {
            skip(); guard i < ch.count else { break }
            let c = ch[i]
            if (c >= 65 && c <= 90) || (c >= 97 && c <= 122) { cmd = c; i += 1 }
            let rel = cmd >= 97
            switch cmd | 0x20 {
            case 122: ops.append(.close); x = sx; y = sy; cmd = 0
            case 109:
                guard let a = num(), let b = num() else { return ops }
                x = rel ? x + a : a; y = rel ? y + b : b; sx = x; sy = y; ops.append(.move(x, y))
                cmd = rel ? 108 : 76   // implicit lineto after moveto
            case 108:
                guard let a = num(), let b = num() else { return ops }
                x = rel ? x + a : a; y = rel ? y + b : b; ops.append(.line(x, y))
            case 104:
                guard let a = num() else { return ops }
                x = rel ? x + a : a; ops.append(.line(x, y))
            case 118:
                guard let b = num() else { return ops }
                y = rel ? y + b : b; ops.append(.line(x, y))
            case 99:
                guard let a = num(), let b = num(), let c1 = num(), let d1 = num(), let e = num(), let f = num() else { return ops }
                let ox = rel ? x : 0, oy = rel ? y : 0
                ops.append(.curve(ox + a, oy + b, ox + c1, oy + d1, ox + e, oy + f)); x = ox + e; y = oy + f
            default: return ops   // unsupported command: stop rather than misdraw
            }
        }
        return ops
    }
}

/// Bundled drawings: class -> (bg halo path, tr line-art path), drawn in a 200 x 74 box (viewBox 0 -2 200 74, ground at y=70).
struct ShapeArt {
    let bg: [PathOp]; let tr: [PathOp]
    static func load(_ data: Data) -> (art: [String: ShapeArt], scale: [String: Double]) {
        guard let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return ([:], [:]) }
        var art: [String: ShapeArt] = [:], scale: [String: Double] = [:]
        for (k, v) in j {
            if k == "_scale", let s = v as? [String: Double] { scale = s; continue }
            guard let o = v as? [String: String] else { continue }
            art[k] = ShapeArt(bg: SVGPath.parse(o["bg"] ?? ""), tr: SVGPath.parse(o["tr"] ?? ""))
        }
        return (art, scale)
    }
}
