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
    @AppStorage(AppLanguage.storageKey) private var language: String = AppLanguage.mk.rawValue

    var body: some View {
        ZStack {
            if userName.isEmpty {
                OnboardingView()
                    .transition(.opacity)
            } else {
                HomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: userName.isEmpty)
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
