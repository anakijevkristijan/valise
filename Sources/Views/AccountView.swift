import SwiftUI
import UIKit

/// Најава, регистрација и профил.
struct AccountView: View {
    @EnvironmentObject private var account: AccountService
    @Environment(\.dismiss) private var dismiss

    enum Mode: String, Identifiable {
        case signIn, signUp
        var id: String { rawValue }
    }

    @State private var mode: Mode
    @State private var name = UserDefaults.standard.string(forKey: "userName") ?? ""
    @State private var email = ""
    @State private var password = ""
    @State private var phone = ""
    @State private var error: String?
    @State private var info: String?
    @State private var confirmDelete = false

    init(startWith mode: Mode = .signUp) {
        _mode = State(initialValue: mode)
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Eyebrow(account.isSignedIn ? L("Акаунт", "Account") : "VALISE", color: Theme.gold)
                        Spacer()
                        CircleIconButton(systemName: "xmark") { dismiss() }
                    }

                    if account.isSignedIn {
                        signedIn
                    } else {
                        signedOut
                    }
                }
                .padding(24)
                .containerRelativeFrame(.horizontal)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationCornerRadius(28)
        .onAppear {
            if phone.isEmpty, let stored = UserDefaults.standard.string(forKey: PhoneID.phoneStorageKey) {
                phone = stored
            }
        }
        .confirmationDialog(L("Да се избрише акаунтот?", "Delete your account?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L("Избриши трајно", "Delete permanently"), role: .destructive) {
                Task {
                    error = await account.deleteAccount()
                    if error == nil { dismiss() }
                }
            }
        } message: {
            Text(L("Твоите заеднички патувања ќе се избришат од облакот, а од туѓите ќе излезеш. Ова не може да се врати.",
                   "Your shared trips will be removed from the cloud and you'll leave other people's trips. This can't be undone."))
        }
    }

    // MARK: Не е најавен

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text(mode == .signUp ? L("Твоите патувања,\nна секој уред.", "Your trips,\non every device.")
                                     : L("Добредојде\nназад.", "Welcome\nback."))
                    .font(.serif(32))
                    .foregroundStyle(Theme.ink)
                Text(mode == .signUp
                     ? L("Со акаунт патувањата се чуваат безбедно, а сопатниците ги гледаат и штиклираат заедно со тебе.",
                         "With an account your trips are backed up, and companions can see and tick them off with you.")
                     : L("Најави се за да ги вратиш твоите патувања.", "Sign in to bring back your trips."))
                    .font(.sans(15))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(3)
            }

            Button {
                Task {
                    error = nil
                    if let failure = await account.signInWithGoogle() {
                        error = failure
                    } else if account.isSignedIn {
                        dismiss()
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Text("G")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.navy)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().strokeBorder(Theme.navy.opacity(0.25), lineWidth: 0.75))
                    Text(L("Продолжи со Google", "Continue with Google"))
                        .font(.sans(15, .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    if account.isWorking { ProgressView().tint(Theme.navy) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Capsule().fill(Theme.surface))
                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .disabled(account.isWorking)

            HStack(spacing: 12) {
                Rectangle().fill(Theme.hairline).frame(height: 0.75)
                Text(L("или со е-пошта", "or with email").uppercased())
                    .font(.sans(9, .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.muted)
                    .fixedSize()
                Rectangle().fill(Theme.hairline).frame(height: 0.75)
            }

            HStack(spacing: 8) {
                ChipButton(title: L("Нов акаунт", "New account"), isSelected: mode == .signUp, expand: true) { mode = .signUp; error = nil }
                ChipButton(title: L("Најава", "Sign in"), isSelected: mode == .signIn, expand: true) { mode = .signIn; error = nil }
            }

            VStack(spacing: 0) {
                if mode == .signUp {
                    field(L("Име", "Name"), text: $name, content: .name)
                    Hairline().padding(.leading, 18)
                }
                field(L("Е-пошта", "Email"), text: $email, content: .emailAddress, keyboard: .emailAddress)
                Hairline().padding(.leading, 18)
                secureField
                if mode == .signUp {
                    Hairline().padding(.leading, 18)
                    field(L("Телефон (по избор)", "Phone (optional)"), text: $phone, content: .telephoneNumber, keyboard: .phonePad)
                }
            }
            .luxCard(padding: 0)

            if mode == .signUp {
                note(L("Со бројот пријателите те наоѓаат од нивните контакти. Се чува само шифриран отпечаток, не самиот број.",
                       "Your number lets friends find you from their contacts. Only an encrypted fingerprint is stored, never the number itself."))
            }

            if let error { message(error, color: Theme.terracotta) }
            if let info { message(info, color: Theme.sage) }

            Button {
                Task { await submit() }
            } label: {
                HStack(spacing: 10) {
                    if account.isWorking { ProgressView().tint(Theme.goldLight) }
                    Text(mode == .signUp ? L("Создај акаунт", "Create account") : L("Најави се", "Sign in"))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSubmit || account.isWorking)

            if mode == .signIn {
                Button(L("Заборавена лозинка?", "Forgot password?")) {
                    Task {
                        if let failure = await account.resetPassword(email: email) {
                            error = failure
                        } else {
                            error = nil
                            info = L("Ти испративме линк за нова лозинка.", "We've sent you a link to reset your password.")
                        }
                    }
                }
                .font(.sans(13, .medium))
                .foregroundStyle(Theme.navy)
                .frame(maxWidth: .infinity)
                .disabled(email.isEmpty)
            }

            note(L("Најава со Apple ќе се појави кога апликацијата ќе оди на App Store.",
                   "Sign in with Apple will appear once the app is on the App Store."))
        }
    }

    private var canSubmit: Bool {
        let base = email.contains("@") && password.count >= 6
        return mode == .signUp ? base && !name.trimmingCharacters(in: .whitespaces).isEmpty : base
    }

    private func submit() async {
        error = nil
        info = nil
        let failure: String?
        if mode == .signUp {
            failure = await account.signUp(name: name, email: email, password: password, phone: phone)
        } else {
            failure = await account.signIn(email: email, password: password)
        }
        if let failure {
            error = failure
        } else {
            dismiss()
        }
    }

    // MARK: Најавен

    private var signedIn: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text(account.profile?.name ?? "")
                    .font(.serif(32))
                    .foregroundStyle(Theme.ink)
                Text(account.profile?.email ?? "")
                    .font(.sans(14))
                    .foregroundStyle(Theme.inkSoft)
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.icloud")
                        .font(.system(size: 12))
                    Text(L("Патувањата се синхронизираат", "Your trips are syncing"))
                        .font(.sans(12, .medium))
                }
                .foregroundStyle(Theme.sage)
                .padding(.top, 4)
            }

            VStack(spacing: 0) {
                field(L("Име", "Name"), text: $name, content: .name)
                Hairline().padding(.leading, 18)
                field(L("Телефон", "Phone"), text: $phone, content: .telephoneNumber, keyboard: .phonePad)
            }
            .luxCard(padding: 0)

            note(L("Со бројот пријателите те наоѓаат од нивните контакти. Потврда со SMS ќе додадеме пред објавување.",
                   "Your number lets friends find you from their contacts. SMS verification comes before launch."))

            if let info { message(info, color: Theme.sage) }
            if let error { message(error, color: Theme.terracotta) }

            Button {
                Task {
                    await account.updateProfile(name: name, phone: phone)
                    info = L("Зачувано.", "Saved.")
                }
            } label: {
                Text(L("Зачувај", "Save"))
            }
            .buttonStyle(PrimaryButtonStyle())

            HStack(spacing: 10) {
                Button {
                    account.signOut()
                    dismiss()
                } label: {
                    Text(L("Одјави се", "Sign out")).frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    confirmDelete = true
                } label: {
                    Text(L("Избриши акаунт", "Delete account"))
                        .foregroundStyle(Theme.terracotta)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .onAppear {
            if let current = account.profile?.name, !current.isEmpty { name = current }
        }
    }

    // MARK: Делови

    private func field(_ label: String, text: Binding<String>, content: UITextContentType, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.sans(9, .semibold))
                .tracking(1.6)
                .foregroundStyle(Theme.muted)
            TextField("", text: text)
                .font(.serif(19))
                .foregroundStyle(Theme.ink)
                .textContentType(content)
                .keyboardType(keyboard)
                .textInputAutocapitalization(content == .name ? .words : .never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var secureField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("Лозинка", "Password").uppercased())
                .font(.sans(9, .semibold))
                .tracking(1.6)
                .foregroundStyle(Theme.muted)
            SecureField("", text: $password)
                .font(.serif(19))
                .foregroundStyle(Theme.ink)
                .textContentType(mode == .signUp ? .newPassword : .password)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.sans(12))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func message(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.sans(13, .medium))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
