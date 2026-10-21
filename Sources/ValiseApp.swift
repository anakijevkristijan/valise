import SwiftUI
import UIKit
import FirebaseCore
import GoogleSignIn

/// Ориентација според големината на прозорецот:
/// мал екран (обичен iPhone, затворен iPhone Duo) → само исправено;
/// голем (отворен iPhone Duo, iPad) → сите насоки, како iPad.
final class AppDelegate: NSObject, UIApplicationDelegate {
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

    /// 0 = јазик, 1 = име, 2 = акаунт (задолжителен), 3 = почетна
    private var stage: Int {
        if !languageChosen { return 0 }
        if account.hasSession {
            return userName.isEmpty ? 1 : 3
        }
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
                Task { await store.refreshAllUpcoming() }
            }
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
