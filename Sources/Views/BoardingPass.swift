import SwiftUI

// MARK: - Облик на карта (половини со засеци за перфорација)

struct TicketHalf: Shape {
    enum Side { case top, bottom }

    var side: Side
    var cornerRadius: CGFloat = 22
    var notch: CGFloat = 11

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let r = min(cornerRadius, min(w, h) / 2)
        let n = min(notch, h / 2)
        let k: CGFloat = 0.5523

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x, y: rect.minY + y)
        }

        var p = Path()
        switch side {
        case .top:
            p.move(to: pt(0, h - n))
            p.addArc(tangent1End: pt(0, 0), tangent2End: pt(w, 0), radius: r)
            p.addArc(tangent1End: pt(w, 0), tangent2End: pt(w, h), radius: r)
            p.addLine(to: pt(w, h - n))
            p.addCurve(to: pt(w - n, h), control1: pt(w - k * n, h - n), control2: pt(w - n, h - k * n))
            p.addLine(to: pt(n, h))
            p.addCurve(to: pt(0, h - n), control1: pt(n, h - k * n), control2: pt(k * n, h - n))
            p.closeSubpath()
        case .bottom:
            p.move(to: pt(n, 0))
            p.addLine(to: pt(w - n, 0))
            p.addCurve(to: pt(w, n), control1: pt(w - n, k * n), control2: pt(w - k * n, n))
            p.addArc(tangent1End: pt(w, h), tangent2End: pt(0, h), radius: r)
            p.addArc(tangent1End: pt(0, h), tangent2End: pt(0, 0), radius: r)
            p.addLine(to: pt(0, n))
            p.addCurve(to: pt(n, 0), control1: pt(k * n, n), control2: pt(n, k * n))
            p.closeSubpath()
        }
        return p
    }
}

struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: - Бар-код

struct BarcodeView: View {
    let seed: String
    var color: Color = Theme.ticketText

    var body: some View {
        Canvas { context, size in
            var bytes = Array(seed.utf8)
            if bytes.isEmpty { bytes = [7, 3, 11] }
            var x: CGFloat = 0
            var i = 0
            while x < size.width {
                let b = Int(bytes[i % bytes.count]) &+ i * 7
                let barWidth = CGFloat(b % 3 + 1)
                let gap = CGFloat((b / 3) % 3 + 1)
                let rect = CGRect(x: x, y: 0, width: min(barWidth, size.width - x), height: size.height)
                context.fill(Path(rect), with: .color(color))
                x += barWidth + gap
                i += 1
            }
        }
        .opacity(0.85)
    }
}

// MARK: - Авионска карта за прва класа

struct BoardingPassCard: View {
    let trip: Trip
    var compact: Bool = false

    private var color: Color { Theme.ticket(trip.tint) }
    private var codeSize: CGFloat { compact ? 36 : 44 }
    private var pad: CGFloat { compact ? 18 : 22 }

    var body: some View {
        VStack(spacing: 0) {
            topHalf
                .background(TicketHalf(side: .top).fill(color))
                .overlay(alignment: .bottom) {
                    DashedLine()
                        .stroke(Theme.goldLight.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }
            bottomHalf
                .background(TicketHalf(side: .bottom).fill(color))
        }
        .compositingGroup()
        .shadow(color: Theme.navy.opacity(0.22), radius: 22, x: 0, y: 14)
    }

    private var topHalf: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("VALISE")
                    .font(.sans(10, .semibold))
                    .tracking(3.2)
                Spacer()
                Text(L("ПРВА КЛАСА", "FIRST CLASS"))
                    .font(.sans(10, .semibold))
                    .tracking(2.4)
            }
            .foregroundStyle(Theme.goldLight)

            HStack(alignment: .bottom, spacing: 8) {
                cityBlock(code: trip.originCode, name: trip.origin?.name ?? "—", alignment: .leading)
                Spacer(minLength: 4)
                VStack(spacing: 6) {
                    Image(systemName: trip.transport.icon)
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(Theme.goldLight)
                    DashedLine()
                        .stroke(Theme.goldLight.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .frame(width: compact ? 44 : 60, height: 1)
                }
                .padding(.bottom, 26)
                Spacer(minLength: 4)
                cityBlock(code: trip.destinationCode, name: trip.destination.name, alignment: .trailing)
            }
            .padding(.top, compact ? 16 : 22)
        }
        .padding(.horizontal, pad)
        .padding(.top, pad)
        .padding(.bottom, compact ? 20 : 24)
    }

    private func cityBlock(code: String, name: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(code)
                .font(.codes(codeSize))
                .foregroundStyle(Theme.ticketText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(name)
                .font(.sans(11, .medium))
                .foregroundStyle(Theme.ticketText.opacity(0.7))
                .lineLimit(1)
        }
    }

    private var bottomHalf: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 18) {
            HStack(alignment: .top, spacing: 8) {
                field(L("Поаѓање", "Depart"), Fmt.ticketDate(trip.startDate))
                field(L("Враќање", "Return"), Fmt.ticketDate(trip.endDate))
                field(L("Денови", "Days"), "\(trip.dayCount)")
            }
            HStack(alignment: .top, spacing: 8) {
                field(L("Багаж", "Bag"), "\(Int((trip.fillRatio * 100).rounded()))%")
                field(L("Спакувано", "Packed"), "\(Int((trip.progress * 100).rounded()))%")
                field(L("Време", "Weather"), trip.weatherSummary.shortText ?? "—")
            }
            HStack(alignment: .center, spacing: 14) {
                BarcodeView(seed: trip.id.uuidString)
                    .frame(height: compact ? 28 : 34)
                Text(trip.countdownText.uppercased())
                    .font(.sans(10, .semibold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.goldLight)
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
            }
        }
        .padding(.horizontal, pad)
        .padding(.top, compact ? 18 : 22)
        .padding(.bottom, pad)
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.sans(9, .semibold))
                .tracking(1.6)
                .foregroundStyle(Theme.ticketText.opacity(0.55))
            Text(value)
                .font(.codes(compact ? 17 : 20))
                .foregroundStyle(Theme.ticketText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Мала карта во листа

struct TicketRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(Theme.ticket(trip.tint))
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(trip.originCode)
                        .font(.codes(22))
                    Image(systemName: trip.transport.icon)
                        .font(.system(size: 10, weight: .light))
                        .foregroundStyle(Theme.gold)
                    Text(trip.destinationCode)
                        .font(.codes(22))
                }
                .foregroundStyle(Theme.ink)
                Text("\(trip.destination.name) · \(Fmt.ticketDate(trip.startDate)) — \(Fmt.ticketDate(trip.endDate))")
                    .font(.sans(12))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
            }
            .padding(.vertical, 14)

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int((trip.progress * 100).rounded()))%")
                    .font(.codes(20))
                    .foregroundStyle(Theme.ink)
                Text(trip.countdownText.uppercased())
                    .font(.sans(9, .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.gold)
            }
            .padding(.trailing, 16)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 0.75)
        )
    }
}
