import SwiftUI

// MARK: - Палета: хартија, морнарско, шампањ злато

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

enum Theme {
    // Основа
    static let paper = Color(hex: 0xF6F3EC)
    static let surface = Color(hex: 0xFFFFFF)
    static let stone = Color(hex: 0xEEE9DF)
    static let hairline = Color(hex: 0xE3DCCF)

    // Текст
    static let ink = Color(hex: 0x131B2B)
    static let inkSoft = Color(hex: 0x4F5666)
    static let muted = Color(hex: 0x958D7F)

    // Карта
    static let navy = Color(hex: 0x13213A)
    static let ticketText = Color(hex: 0xF4EDDF)
    static let gold = Color(hex: 0xA9874F)        // злато врз светло
    static let goldLight = Color(hex: 0xD8BE86)   // злато врз темно
    static let goldPale = Color(hex: 0xEFE6D2)

    // Сигнали
    static let sage = Color(hex: 0x6C8770)
    static let terracotta = Color(hex: 0xAE5A40)
    static let rain = Color(hex: 0x5B7891)

    /// Бои на картите: морнарско, смарагд, бордо, графит.
    static let ticketColors: [Color] = [
        Color(hex: 0x13213A),
        Color(hex: 0x173A31),
        Color(hex: 0x4A1A25),
        Color(hex: 0x25272D)
    ]

    static func ticket(_ index: Int) -> Color {
        ticketColors[abs(index) % ticketColors.count]
    }

    static let metallic = LinearGradient(
        colors: [Color(hex: 0xB8914F), Color(hex: 0xEAD6A4), Color(hex: 0xB8914F)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Стари имиња (компатибилност)
    static var ivory: Color { paper }
    static var sand: Color { stone }
    static var goldDeep: Color { gold }
}

extension Font {
    /// Наслови и зборови — New York (поддржува кирилица).
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Кодови и бројки на картата — Didot (само латиница и бројки).
    static func codes(_ size: CGFloat) -> Font {
        .custom("Didot", size: size)
    }

    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - Позадина

struct PaperBackground: View {
    var body: some View {
        Theme.paper.ignoresSafeArea()
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
                    .shadow(color: Theme.navy.opacity(0.04), radius: 14, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.75)
            )
    }
}

extension View {
    func luxCard(padding: CGFloat = 20, fill: Color = Theme.surface, radius: CGFloat = 18) -> some View {
        modifier(LuxCard(padding: padding, fill: fill, radius: radius))
    }
}

// MARK: - Типографија

struct Eyebrow: View {
    let text: String
    var color: Color

    init(_ text: String, color: Color = Theme.muted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.sans(11, .semibold))
            .tracking(2.2)
            .foregroundStyle(color)
    }
}

struct Hairline: View {
    var color: Color = Theme.hairline

    var body: some View {
        Rectangle()
            .fill(color)
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
                .font(.sans(13, .semibold))
                .tracking(1.8)
                .textCase(.uppercase)
                .foregroundStyle(isEnabled ? Theme.goldLight : Theme.ticketText.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule().fill(isEnabled ? Theme.navy : Theme.muted.opacity(0.45))
                )
                .shadow(color: Theme.navy.opacity(isEnabled ? 0.18 : 0), radius: 14, x: 0, y: 8)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sans(12, .semibold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Theme.navy)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().strokeBorder(Theme.navy.opacity(0.25), lineWidth: 0.75))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

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
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Theme.navy)
            .frame(width: 42, height: 42)
            .background(Circle().fill(Theme.surface))
            .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 0.75))
    }
}

// MARK: - Индикатори

struct ProgressRing: View {
    var progress: Double
    var size: CGFloat = 56
    var lineWidth: CGFloat = 2.5
    var track: Color = Theme.navy.opacity(0.08)
    var tint: Color = Theme.gold
    var labelColor: Color = Theme.ink

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((progress * 100).rounded()))%")
                .font(.codes(size * 0.3))
                .foregroundStyle(labelColor)
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.4), value: progress)
    }
}

struct GaugeBar: View {
    var ratio: Double
    var color: Color = Theme.navy
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.navy.opacity(0.08))
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
    var foreground: Color = Theme.navy
    var stroke: Color = Theme.navy.opacity(0.2)

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text.uppercased())
                .font(.sans(10, .semibold))
                .tracking(1.4)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .overlay(Capsule().strokeBorder(stroke, lineWidth: 0.75))
    }
}

// MARK: - Форматирање (според јазикот)

enum Fmt {
    private static var cache: [String: DateFormatter] = [:]

    private static func formatter(_ format: String) -> DateFormatter {
        let language = AppLanguage.current
        let key = language.rawValue + "|" + format
        if let cached = cache[key] { return cached }
        let f = DateFormatter()
        f.locale = language.locale
        f.dateFormat = format
        cache[key] = f
        return f
    }

    static func day(_ d: Date) -> String { formatter("d").string(from: d) }
    static func dayMonth(_ d: Date) -> String { formatter("d MMMM").string(from: d) }
    static func weekdayShort(_ d: Date) -> String {
        formatter("EEE").string(from: d).replacingOccurrences(of: ".", with: "")
    }
    static func weekdayLong(_ d: Date) -> String { formatter("EEEE, d MMMM").string(from: d) }

    /// 29.10 — за картата (само бројки, без кирилица во Didot).
    static func ticketDate(_ d: Date) -> String { formatter("dd.MM").string(from: d) }

    static func range(_ a: Date, _ b: Date) -> String {
        let cal = Calendar.current
        if cal.isDate(a, inSameDayAs: b) { return dayMonth(a) }
        if cal.component(.month, from: a) == cal.component(.month, from: b) {
            return "\(day(a)) – \(dayMonth(b))"
        }
        return "\(dayMonth(a)) – \(dayMonth(b))"
    }

    static func number(_ d: Double) -> String {
        if d.rounded() == d { return String(Int(d)) }
        return String(format: "%.1f", d)
    }

    static func days(_ n: Int) -> String {
        if AppLanguage.current == .mk { return n == 1 ? "1 ден" : "\(n) дена" }
        return n == 1 ? "1 day" : "\(n) days"
    }

    static func nights(_ n: Int) -> String {
        if AppLanguage.current == .mk { return n == 1 ? "1 ноќ" : "\(n) ноќи" }
        return n == 1 ? "1 night" : "\(n) nights"
    }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}
