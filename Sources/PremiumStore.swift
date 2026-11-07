import Foundation
import StoreKit

/// Tripdrobe Premium (StoreKit 2): годишна претплата (со бесплатна проба) и месечна претплата,
/// во групата „Tripdrobe Premium“ во App Store Connect.
/// Бесплатно: неограничени патувања со листа за пакување. Premium: прогноза, авиокомпании и багаж,
/// гардероба и аутфити, пријатели, Story, „Пред излез“ и теми.
/// „Отклучи за тест“ постои само кога апликацијата НЕ е од App Store / TestFlight (пр. Sideloadly).
@MainActor
final class PremiumStore: ObservableObject {
    static let yearlyID = "com.valise.premium.yearly"
    static let monthlyID = "com.valise.premium.monthly"
    static let allIDs = [yearlyID, monthlyID]
    private static let storageKey = "premiumUnlocked"

    /// Последната позната состојба — за код надвор од екраните (пр. освежување на прогнозата).
    nonisolated static var cachedIsPremium: Bool {
        UserDefaults.standard.bool(forKey: "premiumUnlocked")
    }

    @Published private(set) var isPremium: Bool
    /// Производите по редослед: годишна, месечна, засекогаш (само тие што постојат во App Store Connect).
    @Published private(set) var products: [Product] = []
    @Published private(set) var isWorking = false
    @Published private(set) var didLoad = false
    /// Производите се вчитуваат токму сега (за знакот за вчитување).
    @Published private(set) var isLoadingProducts = false
    /// false = купувањата се исклучени на телефонот (Screen Time / родителска контрола).
    @Published private(set) var canMakePayments = true
    /// Инсталирано од App Store или TestFlight (потпишано од Apple).
    @Published private(set) var isStoreInstall = false
    /// Активниот план (ID на производот) и кога истекува претплатата.
    @Published private(set) var activeProductID: String?
    @Published private(set) var expirationDate: Date?
    /// Купено во тест-околина (TestFlight/sandbox): обновувањата се забрзани и бесплатни.
    @Published private(set) var isSandbox = false
    /// Само за тестирање во TestFlight: апликацијата се однесува како бесплатна иако Premium е купен.
    /// Во App Store (вистинско купување) нема ефект.
    /// Тест-прекинувачот е тргнат за App Store — секогаш false (стара поставка се брише при старт).
    @Published private(set) var simulatesFree = false
    /// Дали корисникот може да ја добие бесплатната проба (само еднаш по Apple ID).
    @Published private(set) var trialEligible = false
    /// false = претплатата е откажана и Premium трае само до `expirationDate`.
    @Published private(set) var willAutoRenew = true
    /// Плаќањето не поминало и Apple се обидува повторно (grace period / billing retry).
    @Published private(set) var hasBillingIssue = false
    @Published var errorMessage: String?

    /// Тест-отклучување е дозволено само надвор од App Store.
    var allowsTestUnlock: Bool { didLoad && !isStoreInstall }

    private var updatesTask: Task<Void, Never>?
    /// Проверка точно кога истекува претплатата, ако апликацијата е отворена во тој момент.
    private var expiryTask: Task<Void, Never>?

    /// App Store и TestFlight немаат embedded.mobileprovision (Apple го трга при потпишување).
    /// Sideloadly и Xcode на телефон секогаш го имаат. Во симулатор е тест.
    private static var isSideloaded: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil
        #endif
    }

    init() {
        isPremium = UserDefaults.standard.bool(forKey: Self.storageKey)
        UserDefaults.standard.removeObject(forKey: "testSimulateFree")
        // Веднаш при старт, а не дури кога ќе се вчитаат производите — за тест-отклучувањето
        // никогаш да не се појави во App Store/TestFlight (пр. без интернет или пред да се направат претплатите).
        isStoreInstall = !Self.isSideloaded
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task { await load() }
    }

    /// Дали производите се достапни (не се при Sideloadly).
    var storeAvailable: Bool { !products.isEmpty }

    var hasSubscription: Bool { activeProductID != nil }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    func load() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        canMakePayments = AppStore.canMakePayments
        let loaded = (try? await Product.products(for: Self.allIDs)) ?? []
        products = Self.allIDs.compactMap { id in loaded.first { $0.id == id } }
        // App Store и TestFlight имаат потврда (receipt) од Apple; Sideloadly нема.
        let hasReceipt = Bundle.main.appStoreReceiptURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        isStoreInstall = !Self.isSideloaded || hasReceipt || !products.isEmpty
        if let subscription = product(Self.yearlyID)?.subscription {
            trialEligible = await subscription.isEligibleForIntroOffer
        }
        await refreshEntitlements()
        didLoad = true
    }

    func purchase(_ product: Product) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    // Веднаш отклучено — без да се чека на целата листа од App Store
                    activeProductID = transaction.productID
                    expirationDate = transaction.expirationDate
                    isSandbox = transaction.environment == .sandbox
                    simulatesFree = false
                    UserDefaults.standard.set(false, forKey: "testSimulateFree")
                    setPremium(true)
                    await transaction.finish()
                }
                // Проверката со App Store продолжува во позадина
                Task { await refreshEntitlements() }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = L("Купувањето не успеа. Обиди се повторно.", "The purchase didn't go through. Please try again.")
        }
    }

    func restore() async {
        isWorking = true
        defer { isWorking = false }
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    func unlockForTesting() {
        guard allowsTestUnlock else { return }
        setPremium(true)
    }

    func lockForTesting() {
        guard allowsTestUnlock else { return }
        setPremium(false)
    }

    /// Активно право: претплата што не е истечена или откажана со враќање пари.
    /// Истечена важи само ако е во „grace period“ (плаќањето не поминало, а Apple се обидува
    /// повторно) — тогаш корисникот го задржува Premium (App Store Connect → Billing Grace Period).
    func refreshEntitlements() async {
        var best: Transaction?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.allIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate, expiry < Date() {
                guard let status = await renewalStatus(for: transaction),
                      status.state == .inGracePeriod else { continue }
            }
            if best == nil || (transaction.expirationDate ?? .distantPast) > (best?.expirationDate ?? .distantPast) {
                best = transaction
            }
        }
        activeProductID = best?.productID
        expirationDate = best?.expirationDate
        isSandbox = best?.environment == .sandbox

        willAutoRenew = true
        hasBillingIssue = false
        if let best, let status = await renewalStatus(for: best) {
            if case .verified(let renewal) = status.renewalInfo {
                willAutoRenew = renewal.willAutoRenew
            }
            hasBillingIssue = status.state == .inGracePeriod || status.state == .inBillingRetryPeriod
        }

        if best != nil {
            setPremium(!(simulatesFree && isSandbox))
        } else if isStoreInstall {
            // Во App Store верзијата важи само вистинско купување
            setPremium(false)
        }
        scheduleExpiryCheck()
    }

    /// Состојбата на претплатата од Apple (обновување, откажана, проблем со плаќање).
    private func renewalStatus(for transaction: Transaction) async -> Product.SubscriptionInfo.Status? {
        guard let statuses = try? await product(transaction.productID)?.subscription?.status else { return nil }
        return statuses.first { status in
            guard case .verified(let latest) = status.transaction else { return false }
            return latest.originalID == transaction.originalID
        }
    }

    /// Ако апликацијата е отворена кога истекува претплатата, Premium се проверува тогаш, а не дури при следно палење.
    private func scheduleExpiryCheck() {
        expiryTask?.cancel()
        expiryTask = nil
        guard let date = expirationDate else { return }
        let delay = date.timeIntervalSinceNow + 5
        // Само за блиски датуми (месечна, TestFlight); годишната се проверува при отворање на апликацијата
        guard delay > 0, delay < 60 * 60 * 24 * 40 else { return }
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.refreshEntitlements()
        }
    }

    /// TestFlight: вклучи/исклучи „бесплатна верзија“ за тестирање.
    func setSimulatesFree(_ on: Bool) async {
        simulatesFree = on
        UserDefaults.standard.set(on, forKey: "testSimulateFree")
        await refreshEntitlements()
    }

    private func setPremium(_ value: Bool) {
        isPremium = value
        UserDefaults.standard.set(value, forKey: Self.storageKey)
    }
}

// MARK: - Текстови за плановите

extension Product {
    /// „година“ / „месец“ за претплатите.
    var periodWord: String? {
        guard let period = subscription?.subscriptionPeriod else { return nil }
        switch period.unit {
        case .year: return period.value == 1 ? L("година", "year") : L("\(period.value) години", "\(period.value) years")
        case .month: return period.value == 1 ? L("месец", "month") : L("\(period.value) месеци", "\(period.value) months")
        case .week: return period.value == 1 ? L("недела", "week") : L("\(period.value) недели", "\(period.value) weeks")
        case .day: return period.value == 1 ? L("ден", "day") : L("\(period.value) дена", "\(period.value) days")
        default: return nil
        }
    }

    /// Бесплатната проба, ако постои: „7 дена“.
    var freeTrialText: String? {
        guard let offer = subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let value = offer.period.value
        switch offer.period.unit {
        case .day: return value == 7 ? L("7 дена", "7 days") : L("\(value) дена", "\(value) days")
        case .week: return value == 1 ? L("7 дена", "7 days") : L("\(value * 7) дена", "\(value * 7) days")
        case .month: return value == 1 ? L("1 месец", "1 month") : L("\(value) месеци", "\(value) months")
        case .year: return L("\(value) година", "\(value) year")
        default: return nil
        }
    }

    /// Колку дена трае бесплатната проба (за „Ден 7“ во понудата).
    var freeTrialDays: Int? {
        guard let offer = subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let value = offer.period.value
        switch offer.period.unit {
        case .day: return value
        case .week: return value * 7
        case .month: return value * 30
        case .year: return value * 365
        default: return nil
        }
    }

    /// Месечна цена за годишниот план: „$1.67 месечно“.
    var monthlyEquivalent: String? {
        guard let period = subscription?.subscriptionPeriod, period.unit == .year, period.value == 1 else { return nil }
        return (price / 12).formatted(priceFormatStyle)
    }
}
