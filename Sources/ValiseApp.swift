import SwiftUI
import UIKit

@main
struct ValiseApp: App {
    @StateObject private var store = TripStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("languageChosen") private var languageChosen: Bool = false
    @AppStorage(AppLanguage.storageKey) private var language: String = AppLanguage.mk.rawValue

    /// 0 = јазик, 1 = име, 2 = почетна
    private var stage: Int {
        if !userName.isEmpty { return 2 }
        return languageChosen ? 1 : 0
    }

    var body: some View {
        ZStack {
            switch stage {
            case 0:
                LanguagePickerView()
                    .transition(.opacity)
            case 1:
                OnboardingView()
                    .transition(.opacity)
            default:
                HomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: stage)
        .id(language)
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
