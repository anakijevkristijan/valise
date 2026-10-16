import SwiftUI

// MARK: - Теми

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

/// Палета на една тема.
struct Palette: Identifiable, Equatable {
    let id: String
    let isPremium: Bool
    let nameMK: String
    let nameEN: String
    let moodMK: String
    let moodEN: String

    let paper: Color
    let stone: Color
    let hairline: Color
    let ink: Color
    let inkSoft: Color
    let muted: Color
    let primary: Color
    let ticketText: Color
    let gold: Color
    let goldLight: Color
    let goldPale: Color
    let sage: Color
    let terracotta: Color
    let rain: Color
    let tickets: [Color]
    var motif: Motif = .none

    var name: String { L(nameMK, nameEN) }
    var mood: String { L(moodMK, moodEN) }

    static func == (a: Palette, b: Palette) -> Bool { a.id == b.id }
}

extension Palette {
    static let classic = Palette(
        id: "classic", isPremium: false,
        nameMK: "Класична", nameEN: "Classic",
        moodMK: "Морнарско и шампањ злато", moodEN: "Navy and champagne gold",
        paper: Color(hex: 0xF6F3EC), stone: Color(hex: 0xEEE9DF), hairline: Color(hex: 0xE3DCCF),
        ink: Color(hex: 0x131B2B), inkSoft: Color(hex: 0x4F5666), muted: Color(hex: 0x958D7F),
        primary: Color(hex: 0x13213A), ticketText: Color(hex: 0xF4EDDF),
        gold: Color(hex: 0xA9874F), goldLight: Color(hex: 0xD8BE86), goldPale: Color(hex: 0xEFE6D2),
        sage: Color(hex: 0x6C8770), terracotta: Color(hex: 0xAE5A40), rain: Color(hex: 0x5B7891),
        tickets: [Color(hex: 0x13213A), Color(hex: 0x173A31), Color(hex: 0x4A1A25), Color(hex: 0x25272D)]
    )

    static let rose = Palette(
        id: "rose", isPremium: true,
        nameMK: "Ривиера роза", nameEN: "Riviera Rose",
        moodMK: "Пудра, малина и розово злато", moodEN: "Blush, raspberry and rose gold",
        paper: Color(hex: 0xFBF4F2), stone: Color(hex: 0xF4E6E3), hairline: Color(hex: 0xEDD9D5),
        ink: Color(hex: 0x3A2228), inkSoft: Color(hex: 0x6E5258), muted: Color(hex: 0xA88E92),
        primary: Color(hex: 0x8E3B55), ticketText: Color(hex: 0xFFF1EE),
        gold: Color(hex: 0xB5787A), goldLight: Color(hex: 0xF3CFC4), goldPale: Color(hex: 0xF8E4DF),
        sage: Color(hex: 0x7E9077), terracotta: Color(hex: 0xB4533F), rain: Color(hex: 0x7A8DA6),
        tickets: [Color(hex: 0x8E3B55), Color(hex: 0xA4566C), Color(hex: 0x6F3A5E), Color(hex: 0x9A5B5F)]
    )

    static let lavender = Palette(
        id: "lavender", isPremium: true,
        nameMK: "Лаванда", nameEN: "Lavender",
        moodMK: "Јоргован и сребрена магла", moodEN: "Lilac and silver haze",
        paper: Color(hex: 0xF7F5FB), stone: Color(hex: 0xECE7F5), hairline: Color(hex: 0xE2DCEF),
        ink: Color(hex: 0x251E38), inkSoft: Color(hex: 0x5A5272), muted: Color(hex: 0x9890AE),
        primary: Color(hex: 0x4E3F7E), ticketText: Color(hex: 0xF6F1FF),
        gold: Color(hex: 0x8F78B8), goldLight: Color(hex: 0xE3D6F7), goldPale: Color(hex: 0xEEE6FA),
        sage: Color(hex: 0x6F8A7D), terracotta: Color(hex: 0xB0584A), rain: Color(hex: 0x6680A3),
        tickets: [Color(hex: 0x4E3F7E), Color(hex: 0x6A4C8C), Color(hex: 0x3E4A7A), Color(hex: 0x7B5A87)]
    )

    static let emerald = Palette(
        id: "emerald", isPremium: true,
        nameMK: "Смарагд", nameEN: "Emerald Club",
        moodMK: "Зелено кадифе и месинг", moodEN: "Green velvet and brass",
        paper: Color(hex: 0xF4F4EE), stone: Color(hex: 0xE8E9E0), hairline: Color(hex: 0xDCDFD3),
        ink: Color(hex: 0x13221D), inkSoft: Color(hex: 0x4A5853), muted: Color(hex: 0x8E978F),
        primary: Color(hex: 0x173A31), ticketText: Color(hex: 0xF2EEDF),
        gold: Color(hex: 0xA9874F), goldLight: Color(hex: 0xD8BE86), goldPale: Color(hex: 0xECE6D2),
        sage: Color(hex: 0x5E7F68), terracotta: Color(hex: 0xAE5A40), rain: Color(hex: 0x5B7891),
        tickets: [Color(hex: 0x173A31), Color(hex: 0x1F4A3F), Color(hex: 0x2E3B2F), Color(hex: 0x13302A)]
    )

    static let noir = Palette(
        id: "noir", isPremium: true,
        nameMK: "Ноар", nameEN: "Noir",
        moodMK: "Црно, крем и злато", moodEN: "Black, cream and gold",
        paper: Color(hex: 0xF5F4F1), stone: Color(hex: 0xEAE8E3), hairline: Color(hex: 0xDFDCD5),
        ink: Color(hex: 0x111111), inkSoft: Color(hex: 0x4A4845), muted: Color(hex: 0x908C85),
        primary: Color(hex: 0x141414), ticketText: Color(hex: 0xF3EFE6),
        gold: Color(hex: 0xA8874E), goldLight: Color(hex: 0xD9C08B), goldPale: Color(hex: 0xEDE6D6),
        sage: Color(hex: 0x6C8770), terracotta: Color(hex: 0xAE5A40), rain: Color(hex: 0x5B7891),
        tickets: [Color(hex: 0x141414), Color(hex: 0x2A2A2A), Color(hex: 0x1E1B18), Color(hex: 0x33302C)]
    )

    static let azur = Palette(
        id: "azur", isPremium: true,
        nameMK: "Азурна обала", nameEN: "Côte d'Azur",
        moodMK: "Медитеран, небо и песок", moodEN: "Mediterranean, sky and sand",
        paper: Color(hex: 0xF3F6F7), stone: Color(hex: 0xE4EBEE), hairline: Color(hex: 0xD8E2E6),
        ink: Color(hex: 0x14263A), inkSoft: Color(hex: 0x4A5C6E), muted: Color(hex: 0x8A9AA6),
        primary: Color(hex: 0x1F4E79), ticketText: Color(hex: 0xF7F0E2),
        gold: Color(hex: 0xB08A4E), goldLight: Color(hex: 0xF0D9A8), goldPale: Color(hex: 0xF1E8D6),
        sage: Color(hex: 0x5F8A7C), terracotta: Color(hex: 0xB4573F), rain: Color(hex: 0x3F6E8C),
        tickets: [Color(hex: 0x1F4E79), Color(hex: 0x2C6E8F), Color(hex: 0x17405F), Color(hex: 0x3B5F7A)]
    )

    static let coquette = Palette(
        id: "coquette", isPremium: true,
        nameMK: "Машнички", nameEN: "Coquette",
        moodMK: "Розеви машнички и бисер", moodEN: "Pink bows and pearls",
        paper: Color(hex: 0xFFF4F7), stone: Color(hex: 0xFBE4EC), hairline: Color(hex: 0xF5D3DF),
        ink: Color(hex: 0x4A2534), inkSoft: Color(hex: 0x7A5162), muted: Color(hex: 0xB48A9B),
        primary: Color(hex: 0xC2477A), ticketText: Color(hex: 0xFFF6F9),
        gold: Color(hex: 0xD98AAE), goldLight: Color(hex: 0xFFD9E8), goldPale: Color(hex: 0xFFE9F1),
        sage: Color(hex: 0x8DAA91), terracotta: Color(hex: 0xC4533F), rain: Color(hex: 0x8C9BC4),
        tickets: [Color(hex: 0xD35C8E), Color(hex: 0xB83E74), Color(hex: 0xC9668F), Color(hex: 0xA34A7E)],
        motif: .bows
    )

    static let blossom = Palette(
        id: "blossom", isPremium: true,
        nameMK: "Цветна", nameEN: "Blossom",
        moodMK: "Пастелни цвеќиња и праска", moodEN: "Pastel blooms and peach",
        paper: Color(hex: 0xFFF8F3), stone: Color(hex: 0xFDEBE3), hairline: Color(hex: 0xF6DCD0),
        ink: Color(hex: 0x4A2C2A), inkSoft: Color(hex: 0x7B5A55), muted: Color(hex: 0xB39189),
        primary: Color(hex: 0xD9667A), ticketText: Color(hex: 0xFFF8F5),
        gold: Color(hex: 0xE39A86), goldLight: Color(hex: 0xFFE1D6), goldPale: Color(hex: 0xFFEDE5),
        sage: Color(hex: 0x8FB39A), terracotta: Color(hex: 0xC4533F), rain: Color(hex: 0x8EA3C9),
        tickets: [Color(hex: 0xD9667A), Color(hex: 0xC65D86), Color(hex: 0xD98468), Color(hex: 0xA86FA6)],
        motif: .flowers
    )

    static let all: [Palette] = [.classic, .coquette, .blossom, .rose, .lavender, .emerald, .noir, .azur]

    static func find(_ id: String?) -> Palette {
        all.first { $0.id == id } ?? .classic
    }
}

enum Theme {
    static let storageKey = "appTheme"

    /// Тековна палета. Се поставува од RootView пред секое исцртување.
    private(set) static var current: Palette = Palette.find(UserDefaults.standard.string(forKey: storageKey))

    /// Премиум темите важат само ако е отклучено.
    static func select(_ id: String, premium: Bool) {
        let palette = Palette.find(id)
        current = (palette.isPremium && !premium) ? .classic : palette
    }

    // Основа
    static var paper: Color { current.paper }
    static var surface: Color { Color(hex: 0xFFFFFF) }
    static var stone: Color { current.stone }
    static var hairline: Color { current.hairline }

    // Текст
    static var ink: Color { current.ink }
    static var inkSoft: Color { current.inkSoft }
    static var muted: Color { current.muted }

    // Карта
    static var navy: Color { current.primary }
    static var ticketText: Color { current.ticketText }
    static var gold: Color { current.gold }
    static var goldLight: Color { current.goldLight }
    static var goldPale: Color { current.goldPale }

    // Сигнали
    static var sage: Color { current.sage }
    static var terracotta: Color { current.terracotta }
    static var rain: Color { current.rain }

    static var ticketColors: [Color] { current.tickets }

    static func ticket(_ index: Int) -> Color {
        let colors = current.tickets
        return colors[abs(index) % colors.count]
    }

    static var metallic: LinearGradient {
        LinearGradient(colors: [current.gold, current.goldLight, current.gold],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

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
        ZStack {
            Theme.paper
            if Theme.current.motif != .none {
                MotifPattern(motif: Theme.current.motif, color: Theme.gold.opacity(0.14), spacing: 66, size: 17)
            }
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
