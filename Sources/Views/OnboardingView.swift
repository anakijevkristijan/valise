import SwiftUI

struct OnboardingView: View {
    @AppStorage("userName") private var userName: String = ""
    @AppStorage(AppLanguage.storageKey) private var language: String = AppLanguage.mk.rawValue
    @State private var name: String = ""
    @State private var appeared = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("VALISE")
                            .font(.sans(12, .semibold))
                            .tracking(4)
                            .foregroundStyle(Theme.navy)
                        Spacer()
                        LanguageToggle(language: $language)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 36)

                    sampleTicket
                        .padding(.bottom, 36)

                    Text(L("Пакувај паметно.\nПатувај лесно.", "Pack smart.\nTravel light."))
                        .font(.serif(38))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(2)
                        .padding(.bottom, 14)

                    Text(L("Твој личен асистент што знае какво ќе е времето, колку собира торбата и што не смее да се заборави.",
                           "Your personal assistant that knows the weather, how much your bag holds, and what you mustn't forget."))
                        .font(.sans(16))
                        .foregroundStyle(Theme.inkSoft)
                        .lineSpacing(4)
                        .padding(.bottom, 30)

                    VStack(alignment: .leading, spacing: 16) {
                        feature("cloud.sun", L("Листа според прогнозата", "A list that follows the forecast"))
                        feature("ruler", L("Без казни за багаж на аеродром", "No baggage fees at the gate"))
                        feature("house", L("Мирен излез од дома", "Leave home with peace of mind"))
                    }
                    .padding(.bottom, 36)

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(L("Како да те викам?", "What should I call you?"))
                        TextField("", text: $name, prompt: Text(L("Твоето име", "Your name")).foregroundColor(Theme.muted.opacity(0.7)))
                            .font(.serif(26))
                            .foregroundStyle(Theme.ink)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($focused)
                            .onSubmit(start)
                        Rectangle()
                            .fill(focused ? Theme.navy : Theme.hairline)
                            .frame(height: 1)
                            .animation(.easeInOut, value: focused)
                    }
                    .padding(.bottom, 28)

                    Button(action: start) {
                        HStack(spacing: 10) {
                            Text(L("Започни", "Begin"))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(trimmed.isEmpty)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.horizontal)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }
        }
    }

    private var sampleTicket: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SKP").font(.codes(40))
                    Text(L("Дома", "Home")).font(.sans(11, .medium)).opacity(0.7)
                }
                Spacer()
                Image(systemName: "airplane")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Theme.goldLight)
                    .padding(.bottom, 26)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("???").font(.codes(40))
                    Text(L("Следно", "Next")).font(.sans(11, .medium)).opacity(0.7)
                }
            }
            .foregroundStyle(Theme.ticketText)
            .padding(22)
            .background(TicketHalf(side: .top).fill(Theme.navy))
            .overlay(alignment: .bottom) {
                DashedLine()
                    .stroke(Theme.goldLight.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
            }

            HStack {
                Text("VALISE")
                    .font(.sans(10, .semibold))
                    .tracking(3.2)
                    .foregroundStyle(Theme.goldLight)
                Spacer()
                BarcodeView(seed: "valise-onboarding")
                    .frame(width: 120, height: 26)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(TicketHalf(side: .bottom).fill(Theme.navy))
        }
        .compositingGroup()
        .shadow(color: Theme.navy.opacity(0.2), radius: 20, x: 0, y: 12)
    }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func start() {
        guard !trimmed.isEmpty else { return }
        focused = false
        userName = trimmed
    }

    private func feature(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Theme.gold)
                .frame(width: 22)
            Text(title)
                .font(.sans(15))
                .foregroundStyle(Theme.ink)
        }
    }
}

/// MK | EN прекинувач.
struct LanguageToggle: View {
    @Binding var language: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppLanguage.allCases) { lang in
                Button {
                    language = lang.rawValue
                } label: {
                    Text(lang.shortName)
                        .font(.sans(11, .semibold))
                        .tracking(1.4)
                        .foregroundStyle(language == lang.rawValue ? Theme.goldLight : Theme.navy)
                        .frame(width: 40, height: 28)
                        .background(Capsule().fill(language == lang.rawValue ? Theme.navy : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .overlay(Capsule().strokeBorder(Theme.navy.opacity(0.25), lineWidth: 0.75))
    }
}

/// Прв екран: избор на јазик пред сè друго.
struct LanguagePickerView: View {
    @AppStorage(AppLanguage.storageKey) private var language: String = AppLanguage.mk.rawValue
    @AppStorage("languageChosen") private var languageChosen: Bool = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(alignment: .leading, spacing: 0) {
                Text("VALISE")
                    .font(.sans(12, .semibold))
                    .tracking(4)
                    .foregroundStyle(Theme.navy)
                    .padding(.top, 20)

                Spacer()

                Text("Добредојде.")
                    .font(.serif(40))
                    .foregroundStyle(Theme.ink)
                Text("Welcome.")
                    .font(.serif(40))
                    .foregroundStyle(Theme.muted)
                    .padding(.bottom, 14)

                Text("Избери јазик · Choose your language")
                    .font(.sans(14))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.bottom, 30)

                VStack(spacing: 12) {
                    option(.mk, code: "MK", subtitle: "Северна Македонија")
                    option(.en, code: "EN", subtitle: "International")
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 26)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }
        }
    }

    private func option(_ lang: AppLanguage, code: String, subtitle: String) -> some View {
        Button {
            language = lang.rawValue
            languageChosen = true
        } label: {
            HStack(spacing: 18) {
                Text(code)
                    .font(.codes(30))
                    .foregroundStyle(Theme.goldLight)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Theme.navy))
                VStack(alignment: .leading, spacing: 4) {
                    Text(lang.nativeName)
                        .font(.serif(24))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle.uppercased())
                        .font(.sans(10, .semibold))
                        .tracking(1.8)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Theme.navy)
            }
            .padding(16)
            .luxCard(padding: 0, radius: 20)
        }
        .buttonStyle(PressableStyle())
    }
}


/// Трет чекор: акаунт (по избор).
struct AccountChoiceView: View {
    @EnvironmentObject private var account: AccountService
    @AppStorage("accountStepDone") private var accountStepDone: Bool = false
    @AppStorage("userName") private var userName: String = ""

    @State private var sheetMode: AccountView.Mode?
    @State private var error: String?
    @State private var appeared = false

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("VALISE")
                        .font(.sans(12, .semibold))
                        .tracking(4)
                        .foregroundStyle(Theme.navy)
                        .padding(.top, 20)
                        .padding(.bottom, 40)

                    Eyebrow(L("Последен чекор", "One last step"), color: Theme.gold)
                        .padding(.bottom, 12)

                    Text(L("\(firstName), најави се\nза да почнеш", "\(firstName), sign in\nto get started"))
                        .font(.serif(34))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(2)
                        .padding(.bottom, 24)

                    VStack(alignment: .leading, spacing: 16) {
                        benefit("icloud", L("Резервна копија — ништо не се губи", "Backed up — nothing gets lost"))
                        benefit("ipad.and.iphone", L("Истите патувања на секој уред", "The same trips on every device"))
                        benefit("hanger", L("Гардероба и аутфити — секогаш со тебе", "Wardrobe and outfits — always with you"))
                        benefit("person.2", L("Патувај со пријатели — заедничка листа", "Travel with friends — a shared list"))
                    }
                    .padding(.bottom, 36)

                    VStack(spacing: 12) {
                        Button {
                            Task {
                                error = await account.signInWithGoogle()
                                if account.isSignedIn { accountStepDone = true }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if account.isWorking { ProgressView().tint(Theme.goldLight) }
                                Text(L("Продолжи со Google", "Continue with Google"))
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(account.isWorking)

                        Button {
                            sheetMode = .signUp
                        } label: {
                            Text(L("Создај акаунт со е-пошта", "Create an account with email"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Button {
                            sheetMode = .signIn
                        } label: {
                            Text(L("Веќе имам акаунт — најави се", "I already have an account — sign in"))
                                .font(.sans(14, .medium))
                                .foregroundStyle(Theme.navy)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }

                    if let error {
                        Text(error)
                            .font(.sans(13, .medium))
                            .foregroundStyle(Theme.terracotta)
                            .padding(.top, 12)
                    }

                    Text(L("Акаунтот е задолжителен: патувањата, гардеробата и аутфитите се чуваат на него — ништо не се губи, а при одјава ништо не останува на телефонот.",
                           "An account is required: your trips, wardrobe and outfits live in it — nothing gets lost, and nothing stays on the phone after you sign out."))
                        .font(.sans(12))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 24)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.horizontal)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }
        }
        .sheet(item: $sheetMode) { mode in
            AccountView(startWith: mode)
                .environmentObject(account)
        }
        .onChange(of: account.isSignedIn) { _, signedIn in
            if signedIn { accountStepDone = true }
        }
    }

    private var firstName: String {
        userName.split(separator: " ").first.map(String.init) ?? userName
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(Theme.gold)
                .frame(width: 24)
            Text(text)
                .font(.sans(15))
                .foregroundStyle(Theme.ink)
        }
    }
}
