import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Parses the subset of SVG that pi/overhead-poster.py writes (rect, line, path, text, g translate/scale)
/// so the TV can draw posters natively. tvOS has no WebKit and SwiftUI has no SVG renderer.
struct PosterSVG {
    enum Item {
        case rect(x: Double, y: Double, w: Double, h: Double, fill: String?, stroke: String?, width: Double)
        case path(ops: [PathOp], fill: String?, stroke: String?, width: Double, evenOdd: Bool)
        case text(String, x: Double, y: Double, size: Double, anchor: String, italic: Bool, sans: Bool)
    }
    var width = 1200.0, height = 1600.0, items: [Item] = []

    static func parse(_ data: Data) -> PosterSVG? {
        let p = Parser(); let x = XMLParser(data: data); x.delegate = p
        guard x.parse() || !p.out.items.isEmpty else { return nil }
        return p.out
    }

    private final class Parser: NSObject, XMLParserDelegate {
        var out = PosterSVG()
        var stack: [(tx: Double, ty: Double, s: Double)] = [(0, 0, 1)]
        var textAttrs: [String: String]? ; var textBuf = ""
        let ink = "#111", paper = "#f4efe4"

        func num(_ s: String?) -> Double { Double(s ?? "") ?? 0 }
        func transform(_ t: String?) -> (Double, Double, Double) {
            guard let t = t else { return (0, 0, 1) }
            var tx = 0.0, ty = 0.0, s = 1.0
            if let r = t.range(of: #"translate\(([-\d.]+)[ ,]+([-\d.]+)\)"#, options: .regularExpression) {
                let v = t[r].dropFirst(10).dropLast().split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
                if v.count == 2 { tx = v[0]; ty = v[1] }
            }
            if let r = t.range(of: #"scale\(([-\d.]+)\)"#, options: .regularExpression) { s = Double(t[r].dropFirst(6).dropLast()) ?? 1 }
            return (tx, ty, s)
        }
        func map(_ x: Double, _ y: Double) -> (Double, Double) { let c = stack.last!; return (c.tx + x * c.s, c.ty + y * c.s) }
        func mapOps(_ ops: [PathOp]) -> [PathOp] {
            ops.map {
                switch $0 {
                case let .move(x, y): let p = map(x, y); return .move(p.0, p.1)
                case let .line(x, y): let p = map(x, y); return .line(p.0, p.1)
                case let .curve(a, b, c, d, e, f): let p = map(a, b), q = map(c, d), r = map(e, f); return .curve(p.0, p.1, q.0, q.1, r.0, r.1)
                case .close: return .close
                }
            }
        }
        func parser(_ parser: XMLParser, didStartElement el: String, namespaceURI: String?, qualifiedName: String?, attributes a: [String: String]) {
            let cls = a["class"] ?? "", sc = stack.last!.s
            switch el {
            case "svg":
                if let vb = a["viewBox"]?.split(separator: " ").compactMap({ Double($0) }), vb.count == 4 { out.width = vb[2]; out.height = vb[3] }
            case "g":
                let (tx, ty, s) = transform(a["transform"]); let c = stack.last!
                stack.append((c.tx + tx * c.s, c.ty + ty * c.s, c.s * s))
            case "rect":
                let p = map(num(a["x"]), num(a["y"]))
                out.items.append(.rect(x: p.0, y: p.1, w: num(a["width"]) * sc, h: num(a["height"]) * sc,
                                       fill: a["fill"] == "none" ? nil : (a["fill"] ?? ink), stroke: a["stroke"], width: num(a["stroke-width"]) * sc))
            case "line":
                let p = map(num(a["x1"]), num(a["y1"])), q = map(num(a["x2"]), num(a["y2"]))
                out.items.append(.path(ops: [.move(p.0, p.1), .line(q.0, q.1)], fill: nil, stroke: a["stroke"] ?? ink,
                                       width: max(num(a["stroke-width"]), 1) * sc, evenOdd: false))
            case "path":
                let ops = mapOps(SVGPath.parse(a["d"] ?? ""))
                if cls.contains("trk") {
                    out.items.append(.path(ops: ops, fill: nil, stroke: a["stroke"] ?? ink, width: max(num(a["stroke-width"]), 0.6) * sc, evenOdd: false))
                } else if cls == "bg" {
                    out.items.append(.path(ops: ops, fill: paper, stroke: nil, width: 0, evenOdd: false))
                } else {
                    out.items.append(.path(ops: ops, fill: a["fill"] ?? ink, stroke: a["stroke"], width: num(a["stroke-width"]) * sc, evenOdd: cls == "tr"))
                }
            case "text":
                textAttrs = a; textBuf = ""
            default: break
            }
        }
        func parser(_ parser: XMLParser, foundCharacters s: String) { if textAttrs != nil { textBuf += s } }
        func parser(_ parser: XMLParser, didEndElement el: String, namespaceURI: String?, qualifiedName: String?) {
            if el == "g", stack.count > 1 { stack.removeLast() }
            if el == "text", let a = textAttrs {
                let p = map(num(a["x"]), num(a["y"]))
                out.items.append(.text(textBuf.trimmingCharacters(in: .whitespacesAndNewlines), x: p.0, y: p.1,
                                       size: (Double(a["font-size"] ?? "") ?? 16) * stack.last!.s, anchor: a["text-anchor"] ?? "start",
                                       italic: a["font-style"] == "italic", sans: (a["class"] ?? "").contains("sans")))
                textAttrs = nil
            }
        }
    }
}
