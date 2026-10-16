import Foundation
import StoreKit

/// Valise Premium — еднократно отклучување (StoreKit 2).
/// Без платена Apple Developer сметка производот не постои, па за тестирање
/// има „отклучи за тест“. ⚠️ Отстрани го `unlockForTesting` пред App Store.
@MainActor
final class PremiumStore: ObservableObject {
    static let productID = "com.valise.premium.lifetime"
    private static let storageKey = "premiumUnlocked"

    @Published private(set) var isPremium: Bool
    @Published private(set) var product: Product?
    @Published private(set) var isWorking = false
    @Published private(set) var didLoad = false

    private var updatesTask: Task<Void, Never>?

    init() {
        isPremium = UserDefaults.standard.bool(forKey: Self.storageKey)
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self?.apply(transaction)
                }
            }
        }
        Task { await load() }
    }

    /// Дали производот е достапен во App Store (не е при Sideloadly).
    var storeAvailable: Bool { product != nil }

    var priceText: String? { product?.displayPrice }

    func load() async {
        product = try? await Product.products(for: [Self.productID]).first
        await refreshEntitlements()
        didLoad = true
    }

    func purchase() async {
        guard let product else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    apply(transaction)
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            print("Valise: purchase failed — \(error)")
        }
    }

    func restore() async {
        isWorking = true
        defer { isWorking = false }
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    func unlockForTesting() {
        setPremium(true)
    }

    func lockForTesting() {
        setPremium(false)
    }

    private func refreshEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                apply(transaction)
            }
        }
    }

    private func apply(_ transaction: Transaction) {
        if transaction.productID == Self.productID && transaction.revocationDate == nil {
            setPremium(true)
        }
    }

    private func setPremium(_ value: Bool) {
        isPremium = value
        UserDefaults.standard.set(value, forKey: Self.storageKey)
    }
}
