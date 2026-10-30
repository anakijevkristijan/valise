import SwiftUI

/// Неутрално прашање за возраст пред регистрација (COPPA / GDPR).
/// Не кажува која возраст е потребна, ништо не е однапред избрано
/// и датумот никаде не се чува — само знак „проверено“ на уредот.
struct AgeGateView: View {
    static let verifiedKey = "ageVerified"
    static let blockedKey = "ageBlockedAt"
    static let minimumAge = 13
    /// Колку долго не може повторно да се проба по одбивање.
    static let blockSeconds: TimeInterval = 24 * 60 * 60

    @AppStorage(AgeGateView.verifiedKey) private var ageVerified: Bool = false
    @AppStorage(AgeGateView.blockedKey) private var blockedAt: Double = 0

    @State private var day: Int?
    @State private var month: Int?
    @State private var year: Int?
    @State private var invalid = false
    @State private var appeared = false

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = AppLanguage.current.locale
        return cal
    }

    private var isBlocked: Bool {
        blockedAt > 0 && Date().timeIntervalSince1970 - blockedAt < Self.blockSeconds
    }

    private var currentYear: Int { calendar.component(.year, from: Date()) }

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("TRIPDROBE")
                        .font(.sans(12, .semibold))
                        .tracking(4)
                        .foregroundStyle(Theme.navy)
                        .padding(.top, 20)
                        .padding(.bottom, 40)

                    if isBlocked {
                        blockedContent
                    } else {
                        askContent
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.horizontal)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }
        }
    }

    // MARK: Прашање

    private var askContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("Кога си роден/а?", "When were you born?"))
                .font(.serif(34))
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 12)

            Text(L("Го прашуваме секого пред да создаде акаунт. Датумот не го чуваме.",
                   "We ask everyone before creating an account. We don't keep the date."))
                .font(.sans(15))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 30)

            HStack(spacing: 10) {
                Menu {
                    ForEach(1...31, id: \.self) { value in
                        Button("\(value)") { day = value; invalid = false }
                    }
                } label: {
                    field(day.map { "\($0)" } ?? L("Ден", "Day"), filled: day != nil, width: 84)
                }

                Menu {
                    ForEach(1...12, id: \.self) { value in
                        Button(monthName(value)) { month = value; invalid = false }
                    }
                } label: {
                    field(month.map { monthName($0) } ?? L("Месец", "Month"), filled: month != nil, width: nil)
                }

                Menu {
                    ForEach(Array(stride(from: currentYear, through: currentYear - 110, by: -1)), id: \.self) { value in
                        Button(String(value)) { year = value; invalid = false }
                    }
                } label: {
                    field(year.map { String($0) } ?? L("Година", "Year"), filled: year != nil, width: 104)
                }
            }
            .padding(.bottom, 14)

            if invalid {
                Text(L("Провери го датумот.", "Please check the date."))
                    .font(.sans(13, .medium))
                    .foregroundStyle(Theme.terracotta)
                    .padding(.bottom, 10)
            }

            Button(action: confirm) {
                HStack(spacing: 10) {
                    Text(L("Продолжи", "Continue"))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(day == nil || month == nil || year == nil)
            .padding(.top, 10)
        }
    }

    /// Ден и година имаат фиксна ширина (секогаш читливи), месецот го зема останатото.
    private func field(_ text: String, filled: Bool, width: CGFloat?) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.sans(17, filled ? .semibold : .regular))
                .foregroundStyle(filled ? Theme.ink : Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(width == nil ? 0.75 : 1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private func monthName(_ value: Int) -> String {
        let names = calendar.standaloneMonthSymbols
        guard value >= 1, value <= names.count else { return "\(value)" }
        return names[value - 1].capitalized(with: AppLanguage.current.locale)
    }

    private func confirm() {
        guard let day, let month, let year else { return }
        let components = DateComponents(year: year, month: month, day: day)
        guard components.isValidDate(in: calendar),
              let birth = calendar.date(from: components),
              birth <= Date() else {
            invalid = true
            return
        }
        let age = calendar.dateComponents([.year], from: birth, to: Date()).year ?? 0

        // Ништо од внесеното не се чува — само дали е проверено.
        self.day = nil
        self.month = nil
        self.year = nil

        withAnimation(.easeInOut(duration: 0.3)) {
            if age >= Self.minimumAge {
                blockedAt = 0
                ageVerified = true
            } else {
                blockedAt = Date().timeIntervalSince1970
            }
        }
    }

    // MARK: Одбиено

    private var blockedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "suitcase")
                .font(.system(size: 30, weight: .ultraLight))
                .foregroundStyle(Theme.gold)
            Text(L("Tripdrobe засега не е достапна за тебе.", "Tripdrobe isn't available for you yet."))
                .font(.serif(30))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(L("Апликацијата не е наменета за твојата возраст, па не можеме да создадеме акаунт. Ништо од внесеното не е зачувано.",
                   "The app isn't meant for your age, so we can't create an account. Nothing you entered has been saved."))
                .font(.sans(15))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
