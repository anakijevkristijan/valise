import Foundation
import UIKit
import AuthenticationServices
import CryptoKit

/// Поставки што се менуваат при објавување на App Store.
enum AppConfig {
    /// „Најава со Apple“ бара платена Apple Developer сметка и капацитет „Sign in with Apple“.
    /// Вклучено во TestFlight/App Store изградбата (VALISE_STORE_BUILD = YES).
    static var appleSignInEnabled: Bool { flag("ValiseSignInWithApple") }

    /// Вредностите доаѓаат од поставката VALISE_STORE_BUILD (YES/NO) при изградба.
    private static func flag(_ key: String) -> Bool {
        let value = Bundle.main.object(forInfoDictionaryKey: key)
        if let bool = value as? Bool { return bool }
        if let text = value as? String { return ["yes", "true", "1"].contains(text.lowercased()) }
        return false
    }

    /// Прогноза од Apple Weather (WeatherKit) — бесплатно до 500.000 барања месечно со платената сметка.
    /// Бара капацитет „WeatherKit“ на App ID. Вклучено во TestFlight/App Store изградбата (VALISE_STORE_BUILD = YES).
    /// Исклучено (тест-верзии со Sideloadly) = Open-Meteo, кое е бесплатно само за некомерцијална употреба.
    static var weatherKitEnabled: Bool { flag("ValiseWeatherKit") }
}

/// Резултат од Apple — само она што ни треба за Firebase.
struct AppleIDResult: Sendable {
    let idToken: String
    let authorizationCode: String?
    let fullName: PersonNameComponents?
    let nonce: String
}

/// Најава со Apple преку системскиот прозорец (со nonce за Firebase).
final class AppleSignIn: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    private var continuation: CheckedContinuation<AppleIDResult?, Error>?
    private var nonce = ""
    private var anchor: ASPresentationAnchor?

    /// nil = корисникот откажа.
    @MainActor
    func request() async throws -> AppleIDResult? {
        nonce = Self.randomNonce()
        anchor = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation?.resume(returning: nil)
            self.continuation = continuation
            controller.performRequests()
        }
    }

    // MARK: ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            finish(.success(nil))
            return
        }
        let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        finish(.success(AppleIDResult(idToken: token, authorizationCode: code,
                                      fullName: credential.fullName, nonce: nonce)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            finish(.success(nil))
        } else {
            finish(.failure(error))
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchor ?? ASPresentationAnchor()
    }

    private func finish(_ result: Result<AppleIDResult?, Error>) {
        let pending = continuation
        continuation = nil
        switch result {
        case .success(let value): pending?.resume(returning: value)
        case .failure(let error): pending?.resume(throwing: error)
        }
    }

    // MARK: Nonce

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<length {
            result.append(charset[Int(generator.next() % UInt64(charset.count))])
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
