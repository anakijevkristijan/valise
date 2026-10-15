import SwiftUI

// MARK: - Палета

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

enum Theme {
    // Основа — слонова коска и топол песок
    static let ivory = Color(hex: 0xF7F2EA)
    static let surface = Color(hex: 0xFFFCF7)
    static let sand = Color(hex: 0xEFE6D8)
    static let hairline = Color(hex: 0xE6DCCD)

    // Текст — еспресо тонови
    static let ink = Color(hex: 0x1F1A15)
    static let inkSoft = Color(hex: 0x5C5248)
    static let muted = Color(hex: 0x9C9184)

    // Акцент — шампањ злато
    static let gold = Color(hex: 0xB08D57)
    static let goldDeep = Color(hex: 0x8A6A3B)
    static let goldLight = Color(hex: 0xEADFC9)

    // Сигнали
    static let sage = Color(hex: 0x7D8C6E)
    static let terracotta = Color(hex: 0xB5654A)

    // Нежни тонови за картичките на патувањата
    static let tints: [Color] = [
        Color(hex: 0xEADFC9), // шампањ
        Color(hex: 0xEED9D0), // пудра
        Color(hex: 0xDCE2D3), // жалфија
        Color(hex: 0xD9E1E6), // магла
        Color(hex: 0xE7DEEA)  // лаванда
    ]

    static func tint(_ index: Int) -> Color {
        tints[abs(index) % tints.count]
    }
}

extension Font {
    /// Серифен фонт (New York) за наслови — дава луксузен, уреднички тон.
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - Позадина

struct LuxBackground: View {
    var body: some View {
        ZStack {
            Theme.ivory
            RadialGradient(
                colors: [Theme.goldLight.opacity(0.65), Theme.ivory.opacity(0)],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 460
            )
            RadialGradient(
                colors: [Color(hex: 0xEED9D0).opacity(0.4), Theme.ivory.opacity(0)],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Картичка

struct LuxCard: ViewModifier {
    var padding: CGFloat
    var fill: Color
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .shadow(color: Theme.ink.opacity(0.05), radius: 22, x: 0, y: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.75)
            )
    }
}

extension View {
    func luxCard(padding: CGFloat = 20, fill: Color = Theme.surface, radius: CGFloat = 24) -> some View {
        modifier(LuxCard(padding: padding, fill: fill, radius: radius))
    }
}

// MARK: - Типографски елементи

struct Eyebrow: View {
    let text: String
    var color: Color

    init(_ text: String, color: Color = Theme.gold) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.sans(11, .semibold))
            .tracking(1.8)
            .foregroundStyle(color)
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 0.75)
    }
}

// MARK: - Копчиња

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonLabel(configuration: configuration)
    }

    private struct PrimaryButtonLabel: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.sans(16, .semibold))
                .foregroundStyle(Theme.ivory)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule().fill(isEnabled ? Theme.ink : Theme.muted.opacity(0.45))
                )
                .shadow(color: Theme.ink.opacity(isEnabled ? 0.18 : 0), radius: 16, x: 0, y: 8)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sans(15, .medium))
            .foregroundStyle(Theme.ink)
            .padding(.vertical, 13)
            .padding(.horizontal, 20)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Нежно „притискање“ за картички.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

struct CircleIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleIcon(systemName: systemName)
        }
        .buttonStyle(PressableStyle())
    }
}

struct CircleIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Theme.ink)
            .frame(width: 42, height: 42)
            .background(Circle().fill(Theme.surface.opacity(0.92)))
            .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 0.75))
            .shadow(color: Theme.ink.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Индикатори

struct ProgressRing: View {
    var progress: Double
    var size: CGFloat = 56
    var lineWidth: CGFloat = 3.5
    var showLabel: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.ink.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(Theme.gold, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showLabel {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.serif(size * 0.27, .medium))
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.4), value: progress)
    }
}

struct GaugeBar: View {
    var ratio: Double
    var color: Color = Theme.gold
    var height: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ink.opacity(0.07))
                Capsule()
                    .fill(color)
                    .frame(width: max(height, geo.size.width * min(max(ratio, 0), 1)))
                    .opacity(ratio <= 0 ? 0 : 1)
            }
        }
        .frame(height: height)
        .animation(.easeInOut(duration: 0.4), value: ratio)
    }
}

struct Pill: View {
    let text: String
    var icon: String?
    var fill: Color = Theme.surface.opacity(0.85)
    var foreground: Color = Theme.ink

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .font(.sans(12, .semibold))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Capsule().fill(fill))
        .overlay(Capsule().strokeBorder(Theme.hairline.opacity(0.8), lineWidth: 0.5))
    }
}

// MARK: - Форматирање

enum Fmt {
    static let mk = Locale(identifier: "mk_MK")

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = mk
        f.dateFormat = format
        return f
    }

    private static let dayF = formatter("d")
    private static let dayMonthF = formatter("d MMMM")
    private static let dayMonthShortF = formatter("d MMM")
    private static let weekdayShortF = formatter("EEE")
    private static let weekdayLongF = formatter("EEEE, d MMMM")

    static func day(_ d: Date) -> String { dayF.string(from: d) }
    static func dayMonth(_ d: Date) -> String { dayMonthF.string(from: d) }
    static func weekdayShort(_ d: Date) -> String { weekdayShortF.string(from: d) }
    static func weekdayLong(_ d: Date) -> String { weekdayLongF.string(from: d) }

    static func range(_ a: Date, _ b: Date) -> String {
        let cal = Calendar.current
        if cal.isDate(a, inSameDayAs: b) { return dayMonth(a) }
        if cal.component(.month, from: a) == cal.component(.month, from: b) {
            return "\(day(a)) – \(dayMonth(b))"
        }
        return "\(dayMonthShortF.string(from: a)) – \(dayMonthShortF.string(from: b))"
    }

    static func number(_ d: Double) -> String {
        if d.rounded() == d { return String(Int(d)) }
        return String(format: "%.1f", d)
    }

    static func days(_ n: Int) -> String {
        n == 1 ? "1 ден" : "\(n) дена"
    }

    static func nights(_ n: Int) -> String {
        n == 1 ? "1 ноќ" : "\(n) ноќи"
    }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}
