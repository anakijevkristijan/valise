import SwiftUI

// MARK: - Новогодишни мотиви: снегулки, украси за елка, конфети

enum FestiveShapes {
    private static func pt(_ r: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height)
    }

    // Снегулка - шест краци со по две гранчиња
    static func snowflake(_ r: CGRect, cx: CGFloat = 0.5, cy: CGFloat = 0.5, radius: CGFloat = 0.46,
                          weight: CGFloat = 0.075) -> Path {
        var p = Path()
        let c = pt(r, cx, cy)
        let side = min(r.width, r.height)
        let length = side * radius
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let tip = CGPoint(x: c.x + cos(angle) * length, y: c.y + sin(angle) * length)
            p.move(to: c)
            p.addLine(to: tip)
            let joint = CGPoint(x: c.x + cos(angle) * length * 0.55, y: c.y + sin(angle) * length * 0.55)
            for turn in [CGFloat(-1), 1] {
                let branch = angle + turn * .pi / 4
                p.move(to: joint)
                p.addLine(to: CGPoint(x: joint.x + cos(branch) * length * 0.32,
                                      y: joint.y + sin(branch) * length * 0.32))
            }
        }
        return p.strokedPath(StrokeStyle(lineWidth: side * weight, lineCap: .round, lineJoin: .round))
    }

    // Топка за елка
    static func bauble(_ r: CGRect) -> Path {
        MotifShapes.circle(r, cx: 0.5, cy: 0.62, radius: 0.34)
    }

    static func baubleCap(_ r: CGRect) -> Path {
        let a = pt(r, 0.39, 0.2)
        let b = pt(r, 0.61, 0.31)
        let rect = CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
        return Path(roundedRect: rect, cornerRadius: rect.height * 0.3)
    }

    static func baubleLoop(_ r: CGRect) -> Path {
        MotifShapes.ellipse(r, cx: 0.5, cy: 0.12, w: 0.15, h: 0.15)
            .strokedPath(StrokeStyle(lineWidth: min(r.width, r.height) * 0.05))
    }

    static func baubleShine(_ r: CGRect) -> Path {
        MotifShapes.ellipse(r, cx: 0.37, cy: 0.52, w: 0.1, h: 0.2, degrees: 28)
    }

    /// Шара на топката - бранувиста лента.
    static func baubleBand(_ r: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(r, 0.19, 0.66))
        p.addCurve(to: pt(r, 0.5, 0.66), control1: pt(r, 0.29, 0.56), control2: pt(r, 0.4, 0.76))
        p.addCurve(to: pt(r, 0.81, 0.66), control1: pt(r, 0.6, 0.56), control2: pt(r, 0.71, 0.76))
        return p.strokedPath(StrokeStyle(lineWidth: min(r.width, r.height) * 0.06, lineCap: .round))
    }

    // Конфети - ленти, точки и мала ѕвездичка
    private static func strip(_ r: CGRect, cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat, degrees: CGFloat) -> Path {
        let c = pt(r, cx, cy)
        let size = CGSize(width: w * r.width, height: h * r.height)
        let rect = CGRect(x: c.x - size.width / 2, y: c.y - size.height / 2, width: size.width, height: size.height)
        let base = Path(roundedRect: rect, cornerRadius: min(size.width, size.height) * 0.3)
        let t = CGAffineTransform(translationX: c.x, y: c.y)
            .rotated(by: degrees * .pi / 180)
            .translatedBy(x: -c.x, y: -c.y)
        return base.applying(t)
    }

    static func confettiPieces(_ r: CGRect) -> [Path] {
        [
            strip(r, cx: 0.24, cy: 0.3, w: 0.13, h: 0.34, degrees: 24),
            strip(r, cx: 0.74, cy: 0.26, w: 0.12, h: 0.3, degrees: -36),
            MotifShapes.circle(r, cx: 0.52, cy: 0.6, radius: 0.1),
            strip(r, cx: 0.28, cy: 0.8, w: 0.28, h: 0.11, degrees: -14),
            MotifShapes.sparkle(r, cx: 0.79, cy: 0.76, radius: 0.17),
            MotifShapes.circle(r, cx: 0.5, cy: 0.13, radius: 0.06)
        ]
    }

    static func confetti(_ r: CGRect) -> Path {
        var p = Path()
        for piece in confettiPieces(r) { p.addPath(piece) }
        return p
    }
}

enum FestiveDrawing {
    /// Во една боја (шара во позадина).
    static func silhouette(_ motif: Motif, in r: CGRect, context: GraphicsContext, cut: GraphicsContext, color: Color) {
        let shading = GraphicsContext.Shading.color(color)
        let hole = GraphicsContext.Shading.color(.black)
        switch motif {
        case .snowflakes:
            context.fill(FestiveShapes.snowflake(r), with: shading)
        case .ornaments:
            context.fill(FestiveShapes.baubleLoop(r), with: shading)
            context.fill(FestiveShapes.baubleCap(r), with: shading)
            context.fill(FestiveShapes.bauble(r), with: shading)
            cut.fill(FestiveShapes.baubleBand(r), with: hole)
        case .confetti:
            context.fill(FestiveShapes.confetti(r), with: shading)
        default:
            break
        }
    }

    /// Во боја (украсот на картата и мострата).
    static func colored(_ motif: Motif, in r: CGRect, context: GraphicsContext, palette: Palette) {
        func fill(_ path: Path, _ color: Color) { context.fill(path, with: .color(color)) }
        switch motif {
        case .snowflakes:
            fill(FestiveShapes.snowflake(r, cx: 0.44, cy: 0.56, radius: 0.42), palette.goldLight)
            fill(FestiveShapes.snowflake(r, cx: 0.85, cy: 0.16, radius: 0.15, weight: 0.05), palette.goldPale)
        case .ornaments:
            fill(FestiveShapes.baubleLoop(r), palette.gold)
            fill(FestiveShapes.bauble(r), palette.terracotta)
            fill(FestiveShapes.baubleBand(r), palette.goldLight)
            fill(FestiveShapes.baubleShine(r), Color.white.opacity(0.75))
            fill(FestiveShapes.baubleCap(r), palette.gold)
        case .confetti:
            let colors = [palette.goldLight, palette.terracotta, palette.gold, palette.goldPale, palette.goldLight, palette.terracotta]
            for (index, piece) in FestiveShapes.confettiPieces(r).enumerated() {
                fill(piece, colors[index % colors.count])
            }
        default:
            break
        }
    }
}
