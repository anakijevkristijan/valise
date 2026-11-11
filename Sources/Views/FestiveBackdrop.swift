import SwiftUI

// MARK: - Празнична позадина: ламбички, конфети и снег што паѓа

extension Palette {
    /// Новогодишните теми имаат раскошна позадина (гирланда + нешто што паѓа).
    var isFestive: Bool { id == "newyear" || id == "christmas" || id == "snowfall" }
}

/// Слој над хартијата, под содржината. Не фаќа допири; со „Намали движење“ стои мирно.
struct FestiveBackdrop: View {
    let palette: Palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Canvas { context, size in
                FestiveBackdrop.drawTop(palette, context: context, size: size)
            }
            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { timeline in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    FestiveBackdrop.drawFalling(palette, context: context, size: size, time: time)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Горе: гирланда

    /// Жица со ламбички (Божиќна), златни ѕвезди на конец (Новогодишна ноќ), мраз и снегулки (Снегулка).
    static func drawTop(_ palette: Palette, context: GraphicsContext, size: CGSize) {
        let top: CGFloat = 54
        let swags = max(3, Int(size.width / 130))
        let step = size.width / CGFloat(swags)
        let drop: CGFloat = palette.id == "snowfall" ? 0 : 26

        // Жицата: лакови од едниот до другиот крај
        var wire = Path()
        wire.move(to: CGPoint(x: 0, y: top))
        for index in 0..<swags {
            let x0 = CGFloat(index) * step
            wire.addQuadCurve(to: CGPoint(x: x0 + step, y: top),
                              control: CGPoint(x: x0 + step / 2, y: top + drop * 2))
        }

        switch palette.id {
        case "christmas":
            context.stroke(wire, with: .color(palette.primary.opacity(0.55)), lineWidth: 1.2)
            let colors = [palette.terracotta, palette.gold, palette.sage, palette.goldLight]
            let perSwag = 5
            for index in 0..<(swags * perSwag) {
                let point = pointOnSwag(index: index, perSwag: perSwag, step: step, top: top, drop: drop)
                let color = colors[index % colors.count]
                let bulb = CGRect(x: point.x - 4.5, y: point.y + 2, width: 9, height: 13)
                context.fill(Path(ellipseIn: bulb.insetBy(dx: -5, dy: -5)), with: .color(color.opacity(0.16)))
                context.fill(Path(ellipseIn: bulb), with: .color(color.opacity(0.9)))
                context.fill(Path(CGRect(x: point.x - 2, y: point.y - 1, width: 4, height: 4)),
                             with: .color(palette.primary.opacity(0.6)))
            }
        case "newyear":
            context.stroke(wire, with: .color(palette.gold.opacity(0.5)), lineWidth: 1)
            let perSwag = 4
            for index in 0..<(swags * perSwag) {
                let point = pointOnSwag(index: index, perSwag: perSwag, step: step, top: top, drop: drop)
                let hang = CGFloat(10 + (index * 7) % 16)
                var thread = Path()
                thread.move(to: point)
                thread.addLine(to: CGPoint(x: point.x, y: point.y + hang))
                context.stroke(thread, with: .color(palette.gold.opacity(0.4)), lineWidth: 0.6)
                let radius: CGFloat = index % 3 == 0 ? 8 : 5.5
                let color = index % 2 == 0 ? palette.gold : palette.goldLight
                context.fill(star(center: CGPoint(x: point.x, y: point.y + hang + radius), radius: radius),
                             with: .color(color.opacity(0.85)))
            }
        default:
            // Снегулка: мраз по горниот раб и големи снегулки во ќошињата
            let frost = Gradient(colors: [palette.goldLight.opacity(0.75), palette.goldLight.opacity(0)])
            context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: 150)),
                         with: .linearGradient(frost, startPoint: .zero, endPoint: CGPoint(x: 0, y: 150)))
            let big: [(x: CGFloat, y: CGFloat, s: CGFloat)] = [(0.1, 78, 64), (0.9, 96, 84), (0.55, 60, 34), (0.3, 118, 26)]
            for flake in big {
                let rect = CGRect(x: size.width * flake.x - flake.s / 2, y: flake.y - flake.s / 2, width: flake.s, height: flake.s)
                context.fill(FestiveShapes.snowflake(rect), with: .color(palette.gold.opacity(0.22)))
            }
        }
    }

    private static func pointOnSwag(index: Int, perSwag: Int, step: CGFloat, top: CGFloat, drop: CGFloat) -> CGPoint {
        let swag = index / perSwag
        let t = (CGFloat(index % perSwag) + 0.5) / CGFloat(perSwag)
        let x = (CGFloat(swag) + t) * step
        // Квадратна крива: y = top + 4·drop·t·(1−t)
        let y = top + 4 * drop * t * (1 - t)
        return CGPoint(x: x, y: y)
    }

    /// Ѕвезда со четири крака (искра).
    static func star(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let inner = radius * 0.32
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4 - .pi / 2
            let r = index % 2 == 0 ? radius : inner
            let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    // MARK: Она што паѓа

    static let particleCount = 34

    /// Каде е честичката во даден момент (исто секогаш за ист `time` - без случајност).
    static func particle(_ index: Int, size: CGSize, time: Double) -> (point: CGPoint, scale: CGFloat, spin: Double) {
        let seed = Double((index &* 7919) % 1000) / 1000
        let seed2 = Double((index &* 104_729) % 1000) / 1000
        let speed = 16 + seed2 * 26
        let height = Double(size.height) + 60
        let y = (seed * height + time * speed).truncatingRemainder(dividingBy: height) - 30
        let sway = sin(time * (0.5 + seed) + seed2 * 6.28) * (10 + seed * 14)
        let x = seed2 * Double(size.width) + sway
        return (CGPoint(x: x, y: y), CGFloat(0.6 + seed * 0.9), time * (0.6 + seed2) + seed * 6.28)
    }

    static func drawFalling(_ palette: Palette, context: GraphicsContext, size: CGSize, time: Double) {
        guard size.width > 0, size.height > 0 else { return }
        let confetti = [palette.gold, palette.terracotta, palette.goldLight, palette.primary]
        for index in 0..<particleCount {
            let item = particle(index, size: size, time: time)
            switch palette.id {
            case "newyear":
                // Конфети: ленти што се вртат
                var piece = context
                piece.translateBy(x: item.point.x, y: item.point.y)
                piece.rotate(by: .radians(item.spin))
                let width = 9 * item.scale
                let rect = CGRect(x: -width / 2, y: -1.6, width: width, height: 3.2 * CGFloat(abs(cos(item.spin * 1.7)) * 0.8 + 0.2))
                piece.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(confetti[index % confetti.count].opacity(0.55)))
            case "christmas":
                // Снег, а секоја петта - златна искра
                if index % 5 == 0 {
                    context.fill(star(center: item.point, radius: 5 * item.scale), with: .color(palette.gold.opacity(0.5)))
                } else {
                    let r = 2.4 * item.scale
                    context.fill(Path(ellipseIn: CGRect(x: item.point.x - r, y: item.point.y - r, width: r * 2, height: r * 2)),
                                 with: .color(palette.muted.opacity(0.32)))
                }
            default:
                // Снегулки: секоја трета е вистинска снегулка, другите пахулки
                if index % 3 == 0 {
                    let s = 15 * item.scale
                    var flake = context
                    flake.translateBy(x: item.point.x, y: item.point.y)
                    flake.rotate(by: .radians(item.spin * 0.4))
                    flake.fill(FestiveShapes.snowflake(CGRect(x: -s / 2, y: -s / 2, width: s, height: s)),
                               with: .color(palette.gold.opacity(0.42)))
                } else {
                    let r = 2.8 * item.scale
                    context.fill(Path(ellipseIn: CGRect(x: item.point.x - r, y: item.point.y - r, width: r * 2, height: r * 2)),
                                 with: .color(palette.primary.opacity(0.2)))
                }
            }
        }
    }
}
