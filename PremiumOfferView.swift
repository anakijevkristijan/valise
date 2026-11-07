import SwiftUI
import StoreKit

/// Целоекранска понуда за Premium - се појавува еднаш, веднаш по најавата (по името и телефонот).
/// Со X или „Продолжи со бесплатната верзија“ се затвора и повеќе не се појавува сама;
/// Premium после се отвора од заклучените функции и од Поставки.
/// Одјавата го брише `shownKey`, па при најава со друг акаунт понудата се покажува уште еднаш.
struct PremiumOfferView: View {
    static let shownKey = "premiumOfferShown"

    @EnvironmentObject private var premium: PremiumStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = PremiumStore.yearlyID
    @State private var legalDoc: LegalDoc?

    private let maxWidth: CGFloat = 520

    private var selected: Product? { premium.product(selectedID) ?? premium.products.first }

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        samplePass

                        Text(headline)
                            .font(.serif(32))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 24)

                        Group {
                            if let product = selected, let trial = trialText(product) {
                                timeline(product, trial: trial)
                            } else {
                                benefits
                            }
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                    .frame(maxWidth: maxWidth)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                bottomPanel
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedID)
        .sheet(item: $legalDoc) { doc in
            LegalView(doc: doc)
        }
        .sensoryFeedback(.success, trigger: premium.isPremium)
        .onChange(of: premium.isPremium) { _, unlocked in
            // Купено или вратено - прозорецот се затвора, сè е веднаш отклучено
            if unlocked {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
            }
        }
    }

    // MARK: Горе

    private var topBar: some View {
        HStack {
            Text("TRIPDROBE PREMIUM")
                .font(.sans(11, .semibold))
                .tracking(3)
                .foregroundStyle(Theme.gold)
            Spacer()
            CircleIconButton(systemName: "xmark") { dismiss() }
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .frame(maxWidth: maxWidth)
        .frame(maxWidth: .infinity)
    }

    private var headline: String {
        if let product = selected, let trial = trialText(product) {
            return L("Пробај Premium\n\(trial) бесплатно.", "Try Premium\n\(trial) free.")
        }
        return L("Целото патување,\nспакувано.", "Your whole trip,\nsorted.")
    }

    // MARK: Пример-карта

    private var samplePass: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("ПАРИЗ", "PARIS"))
                Spacer()
                Text(L("6 ДЕНА", "6 DAYS"))
            }
            .font(.sans(10, .semibold))
            .tracking(2)
            .foregroundStyle(Theme.goldLight)

            HStack(spacing: 10) {
                Text(AppLanguage.current == .mk ? "SKP" : "JFK")
                    .lineLimit(1)
                    .fixedSize()
                dashes(Theme.goldLight.opacity(0.55))
                Image(systemName: "airplane")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Theme.goldLight)
                dashes(Theme.goldLight.opacity(0.55))
                Text("CDG")
                    .lineLimit(1)
                    .fixedSize()
            }
            .font(.codes(32))
            .foregroundStyle(Theme.ticketText)

            // Перфорација со полукругови на рабовите, како кај картата
            dashes(Theme.ticketText.opacity(0.22))
                .padding(.horizontal, -18)
                .overlay(alignment: .leading) {
                    Circle().fill(Theme.paper).frame(width: 18, height: 18).offset(x: -9)
                }
                .overlay(alignment: .trailing) {
                    Circle().fill(Theme.paper).frame(width: 18, height: 18).offset(x: 9)
                }
                .padding(.vertical, 2)

            HStack(alignment: .top, spacing: 8) {
                passCell(L("ВРЕМЕ", "WEATHER"), "15° / 9°")
                passCell(L("БАГАЖ", "BAGGAGE"), L("17,4 / 23 kg", "17.4 / 23 kg"))
                passCell(L("АУТФИТИ", "OUTFITS"), L("6 спремни", "6 ready"))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(Theme.navy)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Пример: карта за Париз со времето, багажот и аутфитите",
                              "Example: a Paris pass with the weather, baggage and outfits"))
    }

    private func passCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.sans(9, .semibold))
                .tracking(1.6)
                .foregroundStyle(Theme.ticketText.opacity(0.72))
            Text(value)
                .font(.sans(15, .medium))
                .foregroundStyle(Theme.ticketText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dashes(_ color: Color) -> some View {
        DashLine()
            .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
    }

    // MARK: Проба - чекори

    private func timeline(_ product: Product, trial: String) -> some View {
        let days = product.freeTrialDays ?? 7
        let period = product.periodWord ?? L("година", "year")
        return VStack(alignment: .leading, spacing: 0) {
            step(icon: "lock.open", filled: true,
                 label: L("ДЕНЕС", "TODAY"),
                 title: L("Сè е отклучено", "Everything is unlocked"),
                 detail: L("Прогноза, авиокомпании, повеќе градови, гардероба, пријатели и теми.",
                           "Forecast, airlines, multi-city trips, wardrobe, friends and themes."),
                 isLast: false)
            step(icon: "calendar.badge.checkmark", filled: false,
                 label: L("ДЕН \(days)", "DAY \(days)"),
                 title: L("Почнува претплатата", "Your subscription starts"),
                 detail: L("\(product.displayPrice) на \(period). Откажи пред тоа и не плаќаш ништо.",
                           "\(product.displayPrice) per \(period). Cancel before then and you pay nothing."),
                 isLast: true)
        }
    }

    private func step(icon: String, filled: Bool, label: String, title: String, detail: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(filled ? Theme.navy : Color.clear)
                Circle().strokeBorder(filled ? Color.clear : Theme.gold, lineWidth: 1.5)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(filled ? Theme.goldLight : Theme.gold)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.sans(10, .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.gold)
                Text(title)
                    .font(.sans(16, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.sans(13))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 20)
        }
        // Линијата меѓу двата чекори
        .background(alignment: .topLeading) {
            if !isLast {
                Rectangle()
                    .fill(Theme.gold.opacity(0.45))
                    .frame(width: 1.5)
                    .padding(.top, 40)
                    .padding(.bottom, 4)
                    .padding(.leading, 17.25)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Без проба - придобивки

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 13) {
            benefit("cloud.sun", L("Прогноза и колку од секое парче", "Forecast and how many of each item"))
            benefit("airplane", L("Багаж за 140+ авиокомпании", "Baggage rules for 140+ airlines"))
            benefit("map", L("Повеќе градови во едно патување", "Several cities in one trip"))
            benefit("hanger", L("Гардероба и аутфити по денови", "Wardrobe and outfits for every day"))
            benefit("person.2", L("Пријатели, Story и премиум теми", "Friends, Stories and premium themes"))
        }
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Theme.gold)
                .frame(width: 24)
            Text(text)
                .font(.sans(15))
                .foregroundStyle(Theme.ink)
        }
    }

    // MARK: Долу - планови и копче

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            if let product = selected {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(premium.products, id: \.id) { plan in
                        planCard(plan)
                    }
                }
                .padding(.top, 14)

                Button {
                    Task { await premium.purchase(product) }
                } label: {
                    HStack(spacing: 10) {
                        if premium.isWorking { ProgressView().tint(Theme.goldLight) }
                        Text(ctaTitle(product))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(premium.isWorking)
                .padding(.top, 16)

                Button {
                    dismiss()
                } label: {
                    Text(L("Продолжи со бесплатната верзија", "Continue with the free version"))
                        .font(.sans(14, .medium))
                        .foregroundStyle(Theme.navy)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                if let error = premium.errorMessage {
                    Text(error)
                        .font(.sans(12, .medium))
                        .foregroundStyle(Theme.terracotta)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 6)
                }

                // Задолжително (Apple 3.1.2): цена, период и автоматско обновување јасно до копчето
                Text(disclosure(product))
                    .font(.sans(11))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 18) {
                    Button(L("Услови", "Terms")) { legalDoc = .terms }
                    Button(L("Приватност", "Privacy")) { legalDoc = .privacy }
                    Button(L("Врати купување", "Restore")) {
                        Task { await premium.restore() }
                    }
                }
                .font(.sans(12, .semibold))
                .foregroundStyle(Theme.navy)
                .buttonStyle(.plain)
                .padding(.top, 10)
            } else {
                ProgressView()
                    .tint(Theme.navy)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
        .frame(maxWidth: maxWidth)
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: selectedID)
    }

    private func planCard(_ product: Product) -> some View {
        let isSelected = selected?.id == product.id
        let isYearly = product.id == PremiumStore.yearlyID
        let trial = trialText(product)
        let priceLine: String
        if isYearly {
            priceLine = product.monthlyEquivalent.map { L("\($0) месечно", "\($0) a month") } ?? L("еднаш годишно", "once a year")
        } else {
            priceLine = L("секој месец", "every month")
        }
        let noteLine: String
        if let trial {
            noteLine = L("\(trial) бесплатно", "\(trial) free")
        } else {
            noteLine = isYearly ? L("Откажи кога сакаш", "Cancel anytime") : L("Без обврска", "No commitment")
        }
        return Button {
            selectedID = product.id
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(isYearly ? L("ГОДИШНО", "YEARLY") : L("МЕСЕЧНО", "MONTHLY"))
                    .font(.sans(11, .semibold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.inkSoft)
                Text(product.displayPrice)
                    .font(.serif(26))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(priceLine)
                    .font(.sans(12.5))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(noteLine)
                    .font(.sans(12.5, .semibold))
                    .foregroundStyle(trial != nil ? Theme.gold : Theme.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Theme.surface : Theme.surface.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Theme.navy : Theme.hairline, lineWidth: 1.5)
            )
            .shadow(color: Theme.navy.opacity(isSelected ? 0.10 : 0), radius: 9, x: 0, y: 6)
            .overlay(alignment: .topLeading) {
                if isYearly, let savings = savingsPercent {
                    Text(L("ЗАШТЕДИ \(savings)%", "SAVE \(savings)%"))
                        .font(.sans(9.5, .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.navy)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.goldLight))
                        .offset(x: 12, y: -10)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Колку се заштедува со годишната во однос на 12 месечни (пр. 58%). Без значка ако е под 10%.
    private var savingsPercent: Int? {
        guard let yearly = premium.product(PremiumStore.yearlyID),
              let monthly = premium.product(PremiumStore.monthlyID) else { return nil }
        let yearPrice = NSDecimalNumber(decimal: yearly.price).doubleValue
        let twelveMonths = NSDecimalNumber(decimal: monthly.price).doubleValue * 12
        guard twelveMonths > 0 else { return nil }
        let percent = Int(((1 - yearPrice / twelveMonths) * 100).rounded(.down))
        return percent >= 10 ? percent : nil
    }

    /// Пробата се нуди само ако корисникот уште не ја искористил (еднаш по Apple ID).
    private func trialText(_ product: Product) -> String? {
        guard product.id == PremiumStore.yearlyID, premium.trialEligible else { return nil }
        return product.freeTrialText
    }

    private func ctaTitle(_ product: Product) -> String {
        if let trial = trialText(product) { return L("Пробај \(trial) бесплатно", "Try \(trial) free") }
        return L("Претплати се · \(product.displayPrice)", "Subscribe · \(product.displayPrice)")
    }

    private func disclosure(_ product: Product) -> String {
        let period = product.periodWord ?? L("период", "period")
        let renew = L("Се обновува автоматски преку твојот Apple ID додека не откажеш најмалку 24 часа пред крајот на периодот. Откажи кога сакаш во Поставки → твоето име → Претплати.",
                      "Renews automatically through your Apple ID until you cancel at least 24 hours before the period ends. Cancel anytime in Settings → your name → Subscriptions.")
        if let trial = trialText(product) {
            return L("\(trial) бесплатно, потоа \(product.displayPrice) на \(period). ",
                     "\(trial) free, then \(product.displayPrice) per \(period). ") + renew
        }
        return L("\(product.displayPrice) на \(period). ", "\(product.displayPrice) per \(period). ") + renew
    }
}

/// Хоризонтална линија по средината (за испрекинатите линии на картата).
private struct DashLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
