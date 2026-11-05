import SwiftUI
import UIKit
import Combine
import UserNotifications
import FirebaseCore
import GoogleSignIn

/// Ориентација според големината на прозорецот:
/// мал екран (обичен iPhone, затворен iPhone Duo) → само исправено;
/// голем (отворен iPhone Duo, iPad) → сите насоки, како iPad.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Потсетниците: прикажи ги и кога апликацијата е отворена, допир → отвори го патувањето
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let raw = response.notification.request.content.userInfo["tripID"] as? String
        if let raw, let id = UUID(uuidString: raw) {
            Task { @MainActor in NotificationRouter.shared.open(id) }
        }
        completionHandler()
    }

    // Известувања од пријателите: токенот од Apple оди во Firebase Messaging
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushService.shared.setAPNSToken(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Tripdrobe: push registration failed — \(error)")
    }

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad { return .all }
        guard let window else { return .portrait }
        let size = window.bounds.size
        return min(size.width, size.height) >= 600 ? .allButUpsideDown : .portrait
    }
}

@main
struct ValiseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = TripStore()
    @StateObject private var premium = PremiumStore()
    @StateObject private var account = AccountService()
    @StateObject private var wardrobe = WardrobeStore()

    init() {
        FirebaseApp.configure()
        PushService.shared.start()
        // Само за сликите за App Store (Debug во симулатор) — во TestFlight/App Store isOn е false.
        if ScreenshotMode.isOn {
            ScreenshotMode.prepareDefaults()
            let trips = TripStore()
            let closet = WardrobeStore()
            ScreenshotMode.seed(trips: trips, wardrobe: closet)
            _store = StateObject(wrappedValue: trips)
            _wardrobe = StateObject(wrappedValue: closet)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(premium)
                .environmentObject(account)
                .environmentObject(wardrobe)
                .onAppear { account.bind(store, wardrobe: wardrobe) }
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var premium: PremiumStore
    @EnvironmentObject private var account: AccountService
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("accountStepDone") private var accountStepDone: Bool = false
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("languageChosen") private var languageChosen: Bool = false
    @AppStorage(AppLanguage.storageKey) private var language: String = AppLanguage.mk.rawValue
    @AppStorage(Theme.storageKey) private var themeID: String = Palette.classic.id
    @AppStorage(AgeGateView.verifiedKey) private var ageVerified: Bool = false
    @AppStorage(PhoneStepView.askedKey) private var phoneAsked: Bool = false
    @AppStorage(PhoneID.phoneStorageKey) private var storedPhone: String = ""
    @AppStorage(PremiumOfferView.shownKey) private var offerShown: Bool = false
    @State private var showOffer = false

    /// Понудата за Premium: еднаш по најавата, кога почетната е отворена и App Store ги вратил цените.
    /// Не се покажува ако Premium е веќе активен или ако продавницата не одговара (без интернет).
    private var offerReady: Bool {
        stage == 3 && !ScreenshotMode.isOn && !offerShown
            && premium.didLoad && premium.storeAvailable && !premium.isPremium
    }

    /// 0 = јазик, 4 = возраст (пред да се внесе било што), 1 = име, 2 = акаунт (задолжителен),
    /// 5 = телефон (по најавата, може да се прескокне), 3 = почетна
    private var stage: Int {
        if ScreenshotMode.isOn { return 3 }
        if !languageChosen { return 0 }
        if account.hasSession {
            if userName.isEmpty { return 1 }
            if !phoneAsked && storedPhone.isEmpty { return 5 }
            return 3
        }
        if !ageVerified { return 4 }
        if userName.isEmpty { return 1 }
        return 2
    }

    var body: some View {
        let _ = Theme.select(themeID, premium: premium.isPremium)
        ZStack {
            switch stage {
            case 0:
                LanguagePickerView()
                    .transition(.opacity)
            case 1:
                OnboardingView()
                    .transition(.opacity)
            case 2:
                AccountChoiceView()
                    .transition(.opacity)
            case 4:
                AgeGateView()
                    .transition(.opacity)
            case 5:
                PhoneStepView()
                    .transition(.opacity)
            default:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: stage)
        .id("\(language)-\(Theme.current.id)")
        .environment(\.locale, AppLanguage.current.locale)
        .preferredColorScheme(.light)
        .tint(Theme.navy)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    // Избришан/блокиран акаунт → одјава веднаш
                    await account.verifySession()
                    // Прво дали Premium е уште активен (истечена или откажана претплата), па прогнозата
                    await premium.refreshEntitlements()
                    await store.refreshAllUpcoming()
                    await NotificationRouter.shared.refreshAuthorization()
                    await TripReminders.reschedule(trips: store.trips, premium: premium.isPremium)
                }
            }
        }
        .task { await NotificationRouter.shared.refreshAuthorization() }
        // Потсетниците се закажуваат одново по секоја промена (бројките „уште N работи“ да се точни)
        .onReceive(store.$trips.debounce(for: .seconds(1.5), scheduler: RunLoop.main)) { trips in
            Task { await TripReminders.reschedule(trips: trips, premium: premium.isPremium) }
        }
        .onChange(of: premium.isPremium) { _, unlocked in
            // Штом е купен Premium: паметни бројки и прогноза за сите патувања
            Task { await TripReminders.reschedule(trips: store.trips, premium: unlocked) }
            guard unlocked else { return }
            store.applySmartQuantities()
            Task { await store.refreshAllUpcoming() }
        }
        .onChange(of: offerReady, initial: true) { _, ready in
            guard ready else { return }
            Task {
                // Почетната прво да се појави, па понудата
                try? await Task.sleep(for: .milliseconds(700))
                guard offerReady else { return }
                offerShown = true
                showOffer = true
            }
        }
        .fullScreenCover(isPresented: $showOffer) {
            PremiumOfferView()
                .environmentObject(premium)
                .preferredColorScheme(.light)
                .tint(Theme.navy)
        }
    }
}

// Го враќа гестот „повлечи за назад“ и кога навигациската лента е скриена.
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
