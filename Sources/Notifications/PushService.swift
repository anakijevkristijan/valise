import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

/// Известувања од пријателите (push): „Ана те додаде во патувањето“, „Ана те означи да носиш: Чадор“…
/// Ги праќа функцијата во Firebase (functions/index.js); апликацијата само го чува токенот на уредот
/// во `users/{uid}.fcmTokens`, заедно со јазикот и дали ги сака известувањата.
@MainActor
final class PushService: NSObject, MessagingDelegate {
    static let shared = PushService()
    nonisolated static let friendAlertsKey = "friendAlerts"

    private(set) var token: String?

    /// Еднаш при старт (по FirebaseApp.configure).
    func start() {
        Messaging.messaging().delegate = self
    }

    /// Се вика кога известувањата се дозволени - iOS го дава токенот од Apple, Firebase го претвора во свој.
    func registerWithApple() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func setAPNSToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            self.token = fcmToken
            await self.upload()
        }
    }

    /// Токенот и јазикот во профилот (по најава, при нов токен, при смена на јазикот).
    func upload() async {
        guard let token, let uid = Auth.auth().currentUser?.uid else { return }
        let allowed = UserDefaults.standard.object(forKey: Self.friendAlertsKey) as? Bool ?? true
        try? await Firestore.firestore().collection("users").document(uid).setData([
            "fcmTokens": FieldValue.arrayUnion([token]),
            "lang": AppLanguage.current.rawValue,
            "friendAlerts": allowed
        ], merge: true)
    }

    /// Пред одјава: овој телефон повеќе не добива известувања за тој акаунт.
    func removeToken() async {
        guard let token, let uid = Auth.auth().currentUser?.uid else { return }
        try? await Firestore.firestore().collection("users").document(uid).setData([
            "fcmTokens": FieldValue.arrayRemove([token])
        ], merge: true)
    }

    /// Прекинувачот во Профил.
    func setFriendAlerts(_ on: Bool) async {
        UserDefaults.standard.set(on, forKey: Self.friendAlertsKey)
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await Firestore.firestore().collection("users").document(uid).setData([
            "friendAlerts": on
        ], merge: true)
    }
}
