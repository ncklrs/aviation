import SwiftUI

/// Side-view line drawing from shapes.json: white (paper) halo silhouette, then black line art with even-odd fill.
/// Faces right when heading east, mirrored when west; nose tilts with climb/descent; sized by class like the page.
struct PlaneDrawing: View {
    let shape: String
    var heading: Double = 90
    var climbFpm: Double = 0
    var showGround = true
    @EnvironmentObject var model: AppModel

    var body: some View {
        let th = model.night ? Theme.night : Theme.day
        Canvas { ctx, size in
            guard let art = model.art[shape] ?? model.art["cessna"] else { return }
            let s = min(size.width / 200, size.height / 74), ox = (size.width - 200 * s) / 2, oy = (size.height - 74 * s) / 2 + 2 * s
            let west = ((heading.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) >= 180
            let k = model.scale[shape] ?? 1
            let tilt = -max(-7, min(7, climbFpm / 300)) * .pi / 180
            let f: (Double, Double) -> CGPoint = { x0, y0 in
                // scale about ground centre (100,70), then rotate about (100,45), then mirror
                var x = 100 + (x0 - 100) * k, y = 70 + (y0 - 70) * k
                let dx = x - 100, dy = y - 45
                x = 100 + dx * cos(tilt) - dy * sin(tilt); y = 45 + dx * sin(tilt) + dy * cos(tilt)
                if west { x = 200 - x }
                return CGPoint(x: ox + x * s, y: oy + y * s)
            }
            if showGround {
                var g = Path(); g.move(to: CGPoint(x: ox, y: oy + 70 * s)); g.addLine(to: CGPoint(x: ox + 200 * s, y: oy + 70 * s))
                ctx.stroke(g, with: .color(th.faint), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
            }
            ctx.fill(Path(ops: art.bg, f), with: .color(th.halo))
            ctx.fill(Path(ops: art.tr, f), with: .color(th.ink), style: FillStyle(eoFill: true))
        }
    }
}
