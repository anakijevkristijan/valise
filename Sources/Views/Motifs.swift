import SwiftUI

/// Украсен мотив на темата.
enum Motif: String {
    case none, bows, flowers, hearts, sparkles, cherries, butterflies, pearls, daisies

    /// Украсот стои на средината горе (машна, ѓердан), а не во аголот.
    var ornamentOnTop: Bool { self == .bows || self == .pearls }
}

// MARK: - Машна

struct BowLoop: Shape {
    enum Side { case left, right }
    var side: Side

    func path(in r: CGRect) -> Path {
        let center = CGPoint(x: r.midX, y: r.minY + r.height * 0.42)
        let edge = side == .left ? r.minX : r.maxX
        let outer = edge + (edge - r.midX) * 0.15
        var p = Path()
        p.move(to: center)
        p.addCurve(to: center,
                   control1: CGPoint(x: outer, y: r.minY - r.height * 0.42),
                   control2: CGPoint(x: outer, y: r.minY + r.height * 1.02))
        p.closeSubpath()
        return p
    }
}

struct BowTail: Shape {
    enum Side { case left, right }
    var side: Side

    func path(in r: CGRect) -> Path {
        let s: CGFloat = side == .left ? -1 : 1
        let cx = r.midX
        let top = r.minY + r.height * 0.46
        var p = Path()
        p.move(to: CGPoint(x: cx + s * r.width * 0.03, y: top))
        p.addQuadCurve(to: CGPoint(x: cx + s * r.width * 0.30, y: r.maxY),
                       control: CGPoint(x: cx + s * r.width * 0.10, y: r.minY + r.height * 0.78))
        p.addLine(to: CGPoint(x: cx + s * r.width * 0.19, y: r.maxY - r.height * 0.07))
        p.addLine(to: CGPoint(x: cx + s * r.width * 0.12, y: r.maxY + r.height * 0.02))
        p.addQuadCurve(to: CGPoint(x: cx - s * r.width * 0.02, y: top + r.height * 0.06),
                       control: CGPoint(x: cx + s * r.width * 0.02, y: r.minY + r.height * 0.72))
        p.closeSubpath()
        return p
    }
}

struct BowKnot: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width * 0.17
        let h = r.height * 0.25
        return Path(roundedRect: CGRect(x: r.midX - w / 2, y: r.minY + r.height * 0.42 - h / 2, width: w, height: h),
                    cornerRadius: w * 0.45)
    }
}

/// Нацртана машничка.
struct BowView: View {
    var color: Color
    var shade: Color? = nil

    var body: some View {
        ZStack {
            BowTail(side: .left).fill(color)
            BowTail(side: .right).fill(color)
            BowLoop(side: .left).fill(color)
            BowLoop(side: .right).fill(color)
            BowLoop(side: .left).stroke((shade ?? color).opacity(0.35), lineWidth: 0.8)
            BowLoop(side: .right).stroke((shade ?? color).opacity(0.35), lineWidth: 0.8)
            BowKnot().fill(shade ?? color)
        }
    }
}

// MARK: - Цвет

enum FlowerPaths {
    static func petals(in r: CGRect, count: Int = 5) -> [Path] {
        let center = CGPoint(x: r.midX, y: r.midY)
        let d = min(r.width, r.height)
        let petal = CGRect(x: center.x - d * 0.2, y: center.y - d * 0.5, width: d * 0.4, height: d * 0.52)
        return (0..<count).map { i in
            let angle = CGFloat(i) / CGFloat(count) * .pi * 2
            let transform = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: angle)
                .translatedBy(x: -center.x, y: -center.y)
            return Path(ellipseIn: petal).applying(transform)
        }
    }

    static func center(in r: CGRect) -> Path {
        let d = min(r.width, r.height) * 0.3
        return Path(ellipseIn: CGRect(x: r.midX - d / 2, y: r.midY - d / 2, width: d, height: d))
    }
}

/// Нацртано цвеќе.
struct FlowerView: View {
    var petal: Color
    var center: Color

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            for path in FlowerPaths.petals(in: rect) {
                context.fill(path, with: .color(petal))
            }
            context.fill(FlowerPaths.center(in: rect), with: .color(center))
        }
    }
}

// MARK: - Нови мотиви (срца, ѕвездички, цреши, пеперутки, бисери, маргаритки)

enum MotifShapes {
    private static func pt(_ r: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height)
    }

    /// Елипса со центар, големина и агол (во степени, во насока на стрелките).
    static func ellipse(_ r: CGRect, cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat, degrees: CGFloat = 0) -> Path {
        let c = pt(r, cx, cy)
        let size = CGSize(width: w * r.width, height: h * r.height)
        let base = Path(ellipseIn: CGRect(x: c.x - size.width / 2, y: c.y - size.height / 2, width: size.width, height: size.height))
        guard degrees != 0 else { return base }
        let t = CGAffineTransform(translationX: c.x, y: c.y)
            .rotated(by: degrees * .pi / 180)
            .translatedBy(x: -c.x, y: -c.y)
        return base.applying(t)
    }

    static func circle(_ r: CGRect, cx: CGFloat, cy: CGFloat, radius: CGFloat) -> Path {
        ellipse(r, cx: cx, cy: cy, w: radius * 2, h: radius * 2)
    }

    // Срце
    static func heart(_ r: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(r, 0.5, 0.92))
        p.addCurve(to: pt(r, 0.04, 0.34), control1: pt(r, 0.38, 0.82), control2: pt(r, 0.04, 0.62))
        p.addCurve(to: pt(r, 0.31, 0.04), control1: pt(r, 0.04, 0.14), control2: pt(r, 0.18, 0.04))
        p.addCurve(to: pt(r, 0.5, 0.19), control1: pt(r, 0.40, 0.04), control2: pt(r, 0.47, 0.10))
        p.addCurve(to: pt(r, 0.69, 0.04), control1: pt(r, 0.53, 0.10), control2: pt(r, 0.60, 0.04))
        p.addCurve(to: pt(r, 0.96, 0.34), control1: pt(r, 0.82, 0.04), control2: pt(r, 0.96, 0.14))
        p.addCurve(to: pt(r, 0.5, 0.92), control1: pt(r, 0.96, 0.62), control2: pt(r, 0.62, 0.82))
        p.closeSubpath()
        return p
    }

    // Ѕвездичка (четири краци)
    static func sparkle(_ r: CGRect, cx: CGFloat, cy: CGFloat, radius: CGFloat) -> Path {
        let k: CGFloat = 0.07
        var p = Path()
        p.move(to: pt(r, cx, cy - radius))
        p.addQuadCurve(to: pt(r, cx + radius, cy), control: pt(r, cx + radius * k, cy - radius * k))
        p.addQuadCurve(to: pt(r, cx, cy + radius), control: pt(r, cx + radius * k, cy + radius * k))
        p.addQuadCurve(to: pt(r, cx - radius, cy), control: pt(r, cx - radius * k, cy + radius * k))
        p.addQuadCurve(to: pt(r, cx, cy - radius), control: pt(r, cx - radius * k, cy - radius * k))
        p.closeSubpath()
        return p
    }

    // Цреши
    static func cherryBalls(_ r: CGRect) -> Path {
        var p = circle(r, cx: 0.29, cy: 0.75, radius: 0.20)
        p.addPath(circle(r, cx: 0.71, cy: 0.80, radius: 0.18))
        return p
    }

    static func cherryShine(_ r: CGRect) -> Path {
        var p = circle(r, cx: 0.23, cy: 0.69, radius: 0.05)
        p.addPath(circle(r, cx: 0.66, cy: 0.74, radius: 0.045))
        return p
    }

    static func cherryStems(_ r: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(r, 0.31, 0.60))
        p.addQuadCurve(to: pt(r, 0.63, 0.10), control: pt(r, 0.38, 0.28))
        p.move(to: pt(r, 0.70, 0.66))
        p.addQuadCurve(to: pt(r, 0.63, 0.10), control: pt(r, 0.67, 0.36))
        return p.strokedPath(StrokeStyle(lineWidth: r.width * 0.06, lineCap: .round))
    }

    static func cherryLeaf(_ r: CGRect) -> Path {
        ellipse(r, cx: 0.77, cy: 0.12, w: 0.30, h: 0.13, degrees: -28)
    }

    // Пеперутка
    static func wings(_ r: CGRect) -> Path {
        var p = Path()
        p.addPath(ellipse(r, cx: 0.29, cy: 0.36, w: 0.42, h: 0.38, degrees: 30))
        p.addPath(ellipse(r, cx: 0.71, cy: 0.36, w: 0.42, h: 0.38, degrees: -30))
        p.addPath(ellipse(r, cx: 0.33, cy: 0.69, w: 0.28, h: 0.30, degrees: -25))
        p.addPath(ellipse(r, cx: 0.67, cy: 0.69, w: 0.28, h: 0.30, degrees: 25))
        return p
    }

    static func butterflyBody(_ r: CGRect, gap: Bool = false) -> Path {
        let w: CGFloat = gap ? 0.11 : 0.06
        let top: CGFloat = gap ? 0.24 : 0.27
        let h: CGFloat = gap ? 0.58 : 0.52
        let rect = CGRect(x: r.minX + (0.5 - w / 2) * r.width, y: r.minY + top * r.height,
                          width: w * r.width, height: h * r.height)
        return Path(roundedRect: rect, cornerRadius: rect.width / 2)
    }

    static func antennae(_ r: CGRect) -> Path {
        var p = Path()
        for s in [CGFloat(-1), 1] {
            p.move(to: pt(r, 0.5 + s * 0.01, 0.28))
            p.addQuadCurve(to: pt(r, 0.5 + s * 0.13, 0.06), control: pt(r, 0.5 + s * 0.03, 0.12))
        }
        return p.strokedPath(StrokeStyle(lineWidth: r.width * 0.03, lineCap: .round))
    }

    // Бисер
    static func pearl(_ r: CGRect) -> Path { circle(r, cx: 0.5, cy: 0.5, radius: 0.4) }
    static func pearlShine(_ r: CGRect) -> Path { circle(r, cx: 0.38, cy: 0.37, radius: 0.11) }

    // Маргаритка
    static func daisyPetals(_ r: CGRect, count: Int = 8) -> Path {
        var p = Path()
        for i in 0..<count {
            let angle = CGFloat(i) / CGFloat(count) * 360
            let petal = ellipse(r, cx: 0.5, cy: 0.22, w: 0.17, h: 0.44)
            let c = pt(r, 0.5, 0.5)
            let t = CGAffineTransform(translationX: c.x, y: c.y)
                .rotated(by: angle * .pi / 180)
                .translatedBy(x: -c.x, y: -c.y)
            p.addPath(petal.applying(t))
        }
        return p
    }

    static func daisyCenter(_ r: CGRect, radius: CGFloat = 0.11) -> Path {
        circle(r, cx: 0.5, cy: 0.5, radius: radius)
    }
}

enum MotifDrawing {
    /// Во една боја (за шарата во позадина). Ситните делови се „издлабуваат“ за да се гледа обликот.
    static func silhouette(_ motif: Motif, in r: CGRect, context: GraphicsContext, color: Color) {
        let shading = GraphicsContext.Shading.color(color)
        var cut = context
        cut.blendMode = .clear
        let hole = GraphicsContext.Shading.color(.black)

        switch motif {
        case .none:
            break
        case .bows:
            for path in [BowTail(side: .left).path(in: r), BowTail(side: .right).path(in: r),
                         BowLoop(side: .left).path(in: r), BowLoop(side: .right).path(in: r),
                         BowKnot().path(in: r)] {
                context.fill(path, with: shading)
            }
        case .flowers:
            for path in FlowerPaths.petals(in: r) {
                context.fill(path, with: shading)
            }
            cut.fill(MotifShapes.daisyCenter(r, radius: 0.17), with: hole)
            context.fill(MotifShapes.daisyCenter(r, radius: 0.11), with: shading)
        case .hearts:
            context.fill(MotifShapes.heart(r), with: shading)
        case .sparkles:
            context.fill(MotifShapes.sparkle(r, cx: 0.44, cy: 0.56, radius: 0.44), with: shading)
            context.fill(MotifShapes.sparkle(r, cx: 0.86, cy: 0.16, radius: 0.14), with: shading)
        case .cherries:
            context.fill(MotifShapes.cherryStems(r), with: shading)
            context.fill(MotifShapes.cherryLeaf(r), with: shading)
            context.fill(MotifShapes.cherryBalls(r), with: shading)
            cut.fill(MotifShapes.cherryShine(r), with: hole)
        case .butterflies:
            context.fill(MotifShapes.wings(r), with: shading)
            cut.fill(MotifShapes.butterflyBody(r, gap: true), with: hole)
            context.fill(MotifShapes.butterflyBody(r), with: shading)
            context.fill(MotifShapes.antennae(r), with: shading)
        case .pearls:
            context.fill(MotifShapes.pearl(r), with: shading)
            cut.fill(MotifShapes.pearlShine(r), with: hole)
        case .daisies:
            context.fill(MotifShapes.daisyPetals(r), with: shading)
            cut.fill(MotifShapes.daisyCenter(r, radius: 0.17), with: hole)
            context.fill(MotifShapes.daisyCenter(r), with: shading)
        }
    }

    /// Во боја (за украсот на картата и мострата).
    static func colored(_ motif: Motif, in r: CGRect, context: GraphicsContext, palette: Palette) {
        func fill(_ path: Path, _ color: Color) { context.fill(path, with: .color(color)) }
        let daisyYellow = Color(hex: 0xE8C35A)

        switch motif {
        case .none:
            break
        case .bows:
            for path in [BowTail(side: .left).path(in: r), BowTail(side: .right).path(in: r),
                         BowLoop(side: .left).path(in: r), BowLoop(side: .right).path(in: r)] {
                fill(path, palette.goldLight)
            }
            fill(BowKnot().path(in: r), palette.gold)
        case .flowers:
            for path in FlowerPaths.petals(in: r) { fill(path, palette.goldLight) }
            fill(FlowerPaths.center(in: r), palette.gold)
        case .hearts:
            fill(MotifShapes.heart(r), palette.goldLight)
        case .sparkles:
            fill(MotifShapes.sparkle(r, cx: 0.44, cy: 0.56, radius: 0.44), palette.goldLight)
            fill(MotifShapes.sparkle(r, cx: 0.86, cy: 0.16, radius: 0.14), palette.gold)
        case .cherries:
            fill(MotifShapes.cherryStems(r), palette.sage)
            fill(MotifShapes.cherryLeaf(r), palette.sage)
            fill(MotifShapes.cherryBalls(r), palette.gold)
            fill(MotifShapes.cherryShine(r), Color.white.opacity(0.85))
        case .butterflies:
            fill(MotifShapes.wings(r), palette.goldLight)
            fill(MotifShapes.butterflyBody(r), palette.gold)
            fill(MotifShapes.antennae(r), palette.gold)
        case .pearls:
            fill(MotifShapes.pearl(r), palette.goldPale)
            fill(MotifShapes.pearlShine(r), Color.white.opacity(0.85))
        case .daisies:
            fill(MotifShapes.daisyPetals(r), Color.white)
            fill(MotifShapes.daisyCenter(r, radius: 0.13), daisyYellow)
        }
    }
}

/// Еден мотив во боите на темата.
struct MotifIcon: View {
    let motif: Motif
    var palette: Palette = Theme.current

    var body: some View {
        Canvas { context, size in
            MotifDrawing.colored(motif, in: CGRect(origin: .zero, size: size), context: context, palette: palette)
        }
    }
}

/// Ѓердан од бисери.
struct PearlStrand: View {
    var color: Color
    var count: Int = 11

    var body: some View {
        Canvas { context, size in
            for i in 0..<count {
                let t = CGFloat(i) / CGFloat(max(count - 1, 1))
                let x = size.width * (0.04 + 0.92 * t)
                let sag = 4 * t * (1 - t)
                let radius = size.height * 0.2 * (0.8 + 0.35 * sin(.pi * t))
                let y = size.height * 0.25 + size.height * 0.5 * sag
                context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                             with: .color(color))
                context.fill(Path(ellipseIn: CGRect(x: x - radius * 0.55, y: y - radius * 0.6, width: radius * 0.6, height: radius * 0.6)),
                             with: .color(Color.white.opacity(0.8)))
            }
        }
    }
}

// MARK: - Шара за позадина

/// Ситни мотиви, распоредени рачно-изгледно. Сè е еден слој, па деловите не се преклопуваат потемно.
struct MotifPattern: View {
    var motif: Motif
    var color: Color
    var opacity: Double = 1
    var spacing: CGFloat = 64
    var size: CGFloat = 16

    var body: some View {
        Canvas { context, canvasSize in
            guard motif != .none else { return }
            context.opacity = opacity
            context.drawLayer { layer in
                let columns = Int(canvasSize.width / spacing) + 2
                let rows = Int(canvasSize.height / spacing) + 2
                for row in 0..<rows {
                    for column in 0..<columns {
                        let seed = (UInt64(row) &* 73_856_093) ^ (UInt64(column) &* 19_349_663)
                        let jitterX = CGFloat(seed % 23) - 11
                        let jitterY = CGFloat((seed / 23) % 19) - 9
                        let offset: CGFloat = row % 2 == 0 ? 0 : spacing / 2
                        let x = CGFloat(column) * spacing + offset + jitterX
                        let y = CGFloat(row) * spacing + jitterY
                        let scale = 0.75 + CGFloat(seed % 5) * 0.1
                        let s = size * scale
                        let rect = CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s * (motif == .bows ? 0.75 : 1))
                        let angle = Angle.degrees(Double(seed % 40) - 20)

                        var item = layer
                        item.translateBy(x: rect.midX, y: rect.midY)
                        item.rotate(by: angle)
                        item.translateBy(x: -rect.midX, y: -rect.midY)
                        MotifDrawing.silhouette(motif, in: rect, context: item, color: color)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Украс на карта

/// Машна, ѓердан, срце, цреши… врз картата.
struct TicketOrnament: View {
    var compact: Bool = false

    var body: some View {
        let motif = Theme.current.motif
        switch motif {
        case .bows:
            BowView(color: Theme.goldLight, shade: Theme.gold)
                .frame(width: compact ? 34 : 54, height: compact ? 26 : 40)
                .shadow(color: Theme.navy.opacity(0.18), radius: 3, x: 0, y: 2)
                .offset(y: compact ? -11 : -16)
        case .flowers:
            ZStack {
                FlowerView(petal: Theme.goldLight, center: Theme.gold)
                    .frame(width: compact ? 22 : 34, height: compact ? 22 : 34)
                FlowerView(petal: Theme.goldPale, center: Theme.gold)
                    .frame(width: compact ? 14 : 20, height: compact ? 14 : 20)
                    .offset(x: compact ? -18 : -27, y: compact ? 10 : 15)
                FlowerView(petal: Theme.goldLight.opacity(0.85), center: Theme.gold)
                    .frame(width: compact ? 10 : 14, height: compact ? 10 : 14)
                    .offset(x: compact ? 4 : 6, y: compact ? 18 : 26)
            }
            .shadow(color: Theme.navy.opacity(0.15), radius: 2, x: 0, y: 1)
            .offset(x: compact ? -6 : -10, y: compact ? -8 : -12)
        case .daisies:
            ZStack {
                MotifIcon(motif: .daisies)
                    .frame(width: compact ? 24 : 36, height: compact ? 24 : 36)
                MotifIcon(motif: .daisies)
                    .frame(width: compact ? 15 : 22, height: compact ? 15 : 22)
                    .offset(x: compact ? -19 : -28, y: compact ? 11 : 16)
                MotifIcon(motif: .daisies)
                    .frame(width: compact ? 11 : 15, height: compact ? 11 : 15)
                    .offset(x: compact ? 4 : 6, y: compact ? 19 : 27)
            }
            .shadow(color: Theme.navy.opacity(0.18), radius: 2, x: 0, y: 1)
            .offset(x: compact ? -6 : -10, y: compact ? -8 : -12)
        case .pearls:
            PearlStrand(color: Theme.goldPale)
                .frame(width: compact ? 96 : 150, height: compact ? 22 : 32)
                .shadow(color: Theme.navy.opacity(0.18), radius: 2, x: 0, y: 1)
                .offset(y: compact ? -9 : -13)
        case .hearts, .sparkles, .cherries, .butterflies:
            ZStack {
                MotifIcon(motif: motif)
                    .frame(width: compact ? 26 : 40, height: compact ? 26 : 40)
                    .rotationEffect(.degrees(motif == .hearts ? 12 : 0))
                if motif == .hearts {
                    MotifIcon(motif: .hearts)
                        .frame(width: compact ? 13 : 19, height: compact ? 13 : 19)
                        .rotationEffect(.degrees(-14))
                        .offset(x: compact ? -18 : -27, y: compact ? 12 : 18)
                }
            }
            .shadow(color: Theme.navy.opacity(0.18), radius: 2, x: 0, y: 1)
            .offset(x: compact ? -6 : -10, y: compact ? -10 : -14)
        case .none:
            EmptyView()
        }
    }
}
