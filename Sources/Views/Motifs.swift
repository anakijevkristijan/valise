import SwiftUI

/// Украсен мотив на темата.
enum Motif: String {
    case none, bows, flowers
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

// MARK: - Шара за позадина

/// Ситни машнички или цветчиња, распоредени рачно-изгледно.
struct MotifPattern: View {
    var motif: Motif
    var color: Color
    var spacing: CGFloat = 64
    var size: CGFloat = 16

    var body: some View {
        Canvas { context, canvasSize in
            guard motif != .none else { return }
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

                    var layer = context
                    layer.translateBy(x: rect.midX, y: rect.midY)
                    layer.rotate(by: angle)
                    layer.translateBy(x: -rect.midX, y: -rect.midY)

                    switch motif {
                    case .bows:
                        for path in [BowTail(side: .left).path(in: rect), BowTail(side: .right).path(in: rect),
                                     BowLoop(side: .left).path(in: rect), BowLoop(side: .right).path(in: rect),
                                     BowKnot().path(in: rect)] {
                            layer.fill(path, with: .color(color))
                        }
                    case .flowers:
                        for path in FlowerPaths.petals(in: rect) {
                            layer.fill(path, with: .color(color))
                        }
                        layer.fill(FlowerPaths.center(in: rect), with: .color(color.opacity(0.6)))
                    case .none:
                        break
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Украс на карта

/// Машна врз картата или китка цвеќиња во аголот.
struct TicketOrnament: View {
    var compact: Bool = false

    var body: some View {
        switch Theme.current.motif {
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
        case .none:
            EmptyView()
        }
    }
}
