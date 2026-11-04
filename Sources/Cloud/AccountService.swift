import Foundation
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

/// Акаунт преку Firebase (Google или е-пошта и лозинка).
/// Најава со Apple доаѓа со платената Apple Developer сметка.
@MainActor
final class AccountService: ObservableObject {

    struct Profile: Equatable {
        let uid: String
        let email: String
        var name: String
    }

    @Published private(set) var profile: Profile?
    @Published private(set) var isWorking = false

    private var handle: NSObjectProtocol?
    private weak var store: TripStore?
    private weak var wardrobe: WardrobeStore?
    private var personal: PersonalCloud?
    private var currentUID: String?
    private let apple = AppleSignIn()

    var isSignedIn: Bool { profile != nil }

    /// Сè лично на телефонот. По одјава апликацијата почнува од почеток, како нова:
    /// јазик, возраст, име, телефон, тема, филтри. Остануваат само купениот Premium
    /// (врзан за Apple ID, не за акаунтот) и блокадата за возраст под 13 години.
    private static let personalKeys = [
        "userName", PhoneID.phoneStorageKey, "lastOrigin", PhoneStepView.askedKey,
        Theme.storageKey, "homeFilter", "accountStepDone",
        "languageChosen", AppLanguage.storageKey, AgeGateView.verifiedKey,
        PremiumOfferView.shownKey, TripReminders.enabledKey, TripReminders.askedKey,
        PushService.friendAlertsKey
    ]

    /// Најавен (и веднаш при старт, пред Firebase да јави) — за да нема трепкање на екранот за најава.
    var hasSession: Bool { profile != nil || Auth.auth().currentUser != nil }

    var phone: String {
        UserDefaults.standard.string(forKey: PhoneID.phoneStorageKey) ?? ""
    }

    /// Се повикува еднаш при старт.
    func bind(_ store: TripStore, wardrobe: WardrobeStore) {
        self.store = store
        self.wardrobe = wardrobe
        guard handle == nil else { return }
        if let user = Auth.auth().currentUser { update(user) }
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.update(user) }
        }
    }

    private func update(_ user: User?) {
        if let user {
            guard currentUID != user.uid else { return }
            currentUID = user.uid
            Session.uid = user.uid
            let storedName = UserDefaults.standard.string(forKey: "userName") ?? ""
            // Едно име насекаде: внесеното на телефонот, а ако го нема — тоа од акаунтот.
            let name = storedName.isEmpty ? (user.displayName ?? "") : storedName
            profile = Profile(uid: user.uid, email: user.email ?? "", name: name)
            if storedName.isEmpty, !name.isEmpty {
                UserDefaults.standard.set(name, forKey: "userName")
            }
            store?.startSync(uid: user.uid)
            personal?.stop()
            if let store, let wardrobe {
                let cloud = PersonalCloud(uid: user.uid, wardrobe: wardrobe, trips: store)
                personal = cloud
                cloud.start()
            }
            Task { await afterSignIn() }
        } else {
            let previous = currentUID
            currentUID = nil
            Session.uid = nil
            profile = nil
            // Прво се исклучува облакот (за бришењето да не се прати горе), па сè се брише од телефонот.
            // Сè е зачувано на акаунтот и се враќа при следна најава.
            personal?.stop()
            personal = nil
            store?.stopSync(previousUID: previous)
            if previous != nil {
                store?.wipeLocal()
                wardrobe?.wipeLocal()
                for key in Self.personalKeys {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
    }

    // MARK: Регистрација и најава

    /// Враќа порака за грешка или nil ако успеало.
    func signUp(name: String, email: String, password: String, phone: String) async -> String? {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await Auth.auth().createUser(withEmail: email.trimmingCharacters(in: .whitespaces), password: password)
            let change = result.user.createProfileChangeRequest()
            change.displayName = name
            try? await change.commitChanges()
            UserDefaults.standard.set(name, forKey: "userName")
            // Бројот се зачувува само ако не е веќе во друг акаунт; инаку го покажува чекорот за телефон
            if let normalized = PhoneID.normalize(phone) {
                switch await checkPhone(normalized) {
                case .free, .mine:
                    savePhone(phone)
                case .taken:
                    pendingPhoneProblem = PhoneProblem(number: phone, message: Self.phoneTakenMessage)
                case .offline:
                    pendingPhoneProblem = PhoneProblem(number: phone, message: Self.phoneOfflineMessage)
                }
            }
            profile = Profile(uid: result.user.uid, email: result.user.email ?? email, name: name)
            await afterSignIn()
            return nil
        } catch {
            return Self.message(for: error)
        }
    }

    func signIn(email: String, password: String) async -> String? {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await Auth.auth().signIn(withEmail: email.trimmingCharacters(in: .whitespaces), password: password)
            return nil
        } catch {
            return Self.message(for: error)
        }
    }

    /// Најава со Google. nil = успех или откажано.
    func signInWithGoogle() async -> String? {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            return L("Google најавата не е поставена.", "Google sign-in isn't configured.")
        }
        guard let presenter = UIApplication.topViewController else { return nil }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                return L("Google не врати најава. Обиди се повторно.", "Google didn't return a sign-in. Try again.")
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: result.user.accessToken.tokenString)
            let auth = try await Auth.auth().signIn(with: credential)
            let googleName = result.user.profile?.name ?? auth.user.displayName ?? ""
            let stored = UserDefaults.standard.string(forKey: "userName") ?? ""
            if stored.isEmpty, !googleName.isEmpty {
                UserDefaults.standard.set(googleName, forKey: "userName")
            }
            return nil
        } catch {
            let nsError = error as NSError
            if nsError.code == -5 && nsError.domain.contains("GIDSignIn") { return nil } // откажано
            return Self.message(for: error)
        }
    }

    /// Најава со Apple (кога е вклучена во AppConfig). nil = успешно или откажано.
    func signInWithApple() async -> String? {
        isWorking = true
        defer { isWorking = false }
        do {
            guard let result = try await apple.request() else { return nil }
            let credential = OAuthProvider.appleCredential(withIDToken: result.idToken,
                                                           rawNonce: result.nonce,
                                                           fullName: result.fullName)
            let auth = try await Auth.auth().signIn(with: credential)
            // Apple го дава името само при првата најава
            if let components = result.fullName {
                let name = PersonNameComponentsFormatter().string(from: components)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    if (auth.user.displayName ?? "").isEmpty {
                        let change = auth.user.createProfileChangeRequest()
                        change.displayName = name
                        try? await change.commitChanges()
                    }
                    if (UserDefaults.standard.string(forKey: "userName") ?? "").isEmpty {
                        UserDefaults.standard.set(name, forKey: "userName")
                    }
                }
            }
            return nil
        } catch {
            return Self.message(for: error)
        }
    }

    func resetPassword(email: String) async -> String? {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email.trimmingCharacters(in: .whitespaces))
            return nil
        } catch {
            return Self.message(for: error)
        }
    }

    /// Одјава: прво се чека сè да се качи (најмногу неколку секунди), па се брише од телефонот.
    func signOut() {
        isWorking = true
        Task {
            // Овој телефон повеќе не добива известувања за овој акаунт
            await PushService.shared.removeToken()
            await Self.waitForUploads(timeout: 5)
            GIDSignIn.sharedInstance.signOut()
            try? Auth.auth().signOut()
            isWorking = false
        }
    }

    private static func waitForUploads(timeout: Double) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let once = Once()
            Firestore.firestore().waitForPendingWrites { _ in
                once.run { continuation.resume() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                once.run { continuation.resume() }
            }
        }
    }

    /// Бришење акаунт (Apple го бара ова во самата апликација).
    func deleteAccount() async -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        isWorking = true
        defer { isWorking = false }

        // Apple бара: при бришење на акаунт, пристапот од „Најава со Apple“ се повлекува.
        if AppConfig.appleSignInEnabled, user.providerData.contains(where: { $0.providerID == "apple.com" }) {
            do {
                guard let result = try await apple.request() else { return nil } // откажано
                let credential = OAuthProvider.appleCredential(withIDToken: result.idToken,
                                                               rawNonce: result.nonce,
                                                               fullName: nil)
                _ = try await user.reauthenticate(with: credential)
                if let code = result.authorizationCode {
                    try? await Auth.auth().revokeToken(withAuthorizationCode: code)
                }
            } catch {
                return Self.message(for: error)
            }
        }

        if let store {
            for trip in store.trips where trip.isCloud {
                await store.cloud?.removeOrLeave(trip)
            }
        }
        await personal?.deleteEverything()
        // Профилот и клучевите за пребарување (шифриран број/е-пошта)
        if let cloud = store?.cloud {
            let phoneKey = PhoneID.normalize(phone).map { PhoneID.phoneKey($0) }
            let emailKey = (user.email ?? "").isEmpty ? nil : PhoneID.emailKey(user.email ?? "")
            await cloud.deleteProfile(keys: [phoneKey, emailKey].compactMap { $0 })
        }
        do {
            try await user.delete()
            UserDefaults.standard.removeObject(forKey: PhoneID.phoneStorageKey)
            return nil
        } catch {
            return Self.message(for: error)
        }
    }

    // MARK: Профил

    /// Име и телефон. Враќа порака ако бројот не може да се зачува
    /// (веќе е додаден во друг акаунт, или нема интернет за да се провери).
    @discardableResult
    func updateProfile(name: String, phone: String) async -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            UserDefaults.standard.set(trimmed, forKey: "userName")
            if let user = Auth.auth().currentUser {
                let change = user.createProfileChangeRequest()
                change.displayName = trimmed
                try? await change.commitChanges()
            }
            profile?.name = trimmed
        }

        // Нов број: прво дали е веќе во друг акаунт
        let typed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalized = PhoneID.normalize(typed), normalized != self.phone {
            switch await checkPhone(normalized) {
            case .taken: return Self.phoneTakenMessage
            case .offline: return Self.phoneOfflineMessage
            case .free, .mine: break
            }
        }

        let hadPhone = !self.phone.isEmpty
        savePhone(phone)
        if hadPhone && self.phone.isEmpty {
            await store?.cloud?.removePhone()
        }
        await afterSignIn()
        return nil
    }

    // MARK: Еден број — еден акаунт

    enum PhoneCheck { case free, mine, taken, offline }

    /// Број при регистрација што не можеше да се зачува — го покажува чекорот за телефон.
    struct PhoneProblem: Equatable {
        let number: String
        let message: String
    }

    @Published var pendingPhoneProblem: PhoneProblem?

    /// Дали бројот е веќе додаден во друг акаунт (по шифрираниот клуч, истиот што го користат пријателите).
    func checkPhone(_ normalized: String) async -> PhoneCheck {
        guard let uid = Auth.auth().currentUser?.uid else { return .offline }
        let key = PhoneID.phoneKey(normalized)
        do {
            let snapshot = try await Firestore.firestore().collection("lookup").document(key).getDocument(source: .server)
            guard snapshot.exists, let owner = snapshot.data()?["uid"] as? String else { return .free }
            return owner == uid ? .mine : .taken
        } catch {
            return .offline
        }
    }

    static var phoneTakenMessage: String {
        let mail = LegalTexts.supportEmail
        if mail.isEmpty {
            return L("Овој број веќе е додаден во друг акаунт. Ако е твој, најави се во тој акаунт.",
                     "This number is already added to another account. If it's yours, sign in to that account.")
        }
        return L("Овој број веќе е додаден во друг акаунт. Ако е твој, најави се во тој акаунт или пиши ни на \(mail).",
                 "This number is already added to another account. If it's yours, sign in to that account or write to us at \(mail).")
    }

    static var phoneOfflineMessage: String {
        L("Не можам да го проверам бројот — провери дали имаш интернет и обиди се повторно.",
          "Couldn't check the number — make sure you're online and try again.")
    }

    private func savePhone(_ phone: String) {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: PhoneID.phoneStorageKey)
        } else if let normalized = PhoneID.normalize(trimmed) {
            UserDefaults.standard.set(normalized, forKey: PhoneID.phoneStorageKey)
        }
    }

    /// Ги регистрира моите клучеви и ги прифаќа поканите што ме чекаат.
    private func afterSignIn() async {
        guard let cloud = store?.cloud, let profile else { return }
        let phoneKey = PhoneID.normalize(phone).map { PhoneID.phoneKey($0) }
        let emailKey = profile.email.isEmpty ? nil : PhoneID.emailKey(profile.email)
        let name = UserDefaults.standard.string(forKey: "userName") ?? profile.name
        let mine = await cloud.registerProfile(name: name, phoneKey: phoneKey, emailKey: emailKey)
        // Поканите само за мојот број (не за број што е на друг акаунт)
        let keys = [phoneKey, emailKey].compactMap { $0 }.filter { mine.contains($0) }
        await cloud.joinPendingInvites(myKeys: keys, myName: name)
        // Известувањата од пријателите доаѓаат на овој телефон
        await PushService.shared.upload()
    }

    // MARK: Пораки за грешки

    private static func message(for error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case 17007: return L("Оваа е-пошта веќе има акаунт. Најави се.", "This email already has an account. Sign in instead.")
        case 17008: return L("Е-поштата не е валидна.", "That email address isn't valid.")
        case 17009, 17004: return L("Погрешна е-пошта или лозинка.", "Wrong email or password.")
        case 17011: return L("Нема акаунт со оваа е-пошта.", "No account with this email.")
        case 17026: return L("Лозинката треба да има барем 6 знаци.", "The password needs at least 6 characters.")
        case 17020: return L("Нема интернет. Обиди се повторно.", "No connection. Try again.")
        case 17010: return L("Премногу обиди. Почекај малку.", "Too many attempts. Wait a moment.")
        case 17014: return L("Од безбедносни причини, одјави се и најави се повторно, па пробај пак.", "For security, sign out and back in, then try again.")
        default: return L("Нешто не успеа. Обиди се повторно.", "Something went wrong. Try again.")
        }
    }
}

/// Повикува нешто само еднаш (прв што ќе стигне: качувањето или истекот на времето).
private final class Once {
    private let lock = NSLock()
    private var done = false

    func run(_ action: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        action()
    }
}
