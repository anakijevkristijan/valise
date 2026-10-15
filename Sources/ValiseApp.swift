import SwiftUI
import UIKit

@main
struct ValiseApp: App {
    @StateObject private var store = TripStore()
    @AppStorage("userName") private var userName: String = ""

    var body: some Scene {
        WindowGroup {
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
            .environmentObject(store)
            .preferredColorScheme(.light)
            .tint(Theme.gold)
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
