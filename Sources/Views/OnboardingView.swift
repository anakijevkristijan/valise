import SwiftUI

struct OnboardingView: View {
    @AppStorage("userName") private var userName: String = ""
    @AppStorage(AppLanguage.storageKey) private var language: String = AppLanguage.en.rawValue
    @State private var name: String = ""
    @State private var appeared = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("TRIPDROBE")
                            .font(.sans(12, .semibold))
                            .tracking(4)
                            .foregroundStyle(Theme.navy)
                        Spacer()
                        LanguageButton(language: $language)
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
                Text("TRIPDROBE")
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

/// Мало копче за јазикот (горе десно): отвора избор на сите јазици.
struct LanguageButton: View {
    @Binding var language: String
    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 12, weight: .light))
                Text((AppLanguage(rawValue: language) ?? .en).shortName)
                    .font(.sans(11, .semibold))
                    .tracking(1.4)
            }
            .foregroundStyle(Theme.navy)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .overlay(Capsule().strokeBorder(Theme.navy.opacity(0.25), lineWidth: 0.75))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("Јазик", "Language"))
        .sheet(isPresented: $showPicker) {
            LanguageSheet(language: $language)
        }
    }
}

/// Мрежа со сите јазици - без лизгање, 3 колони, последниот ред на средина.
struct LanguageGrid: View {
    @Binding var language: String
    var rowHeight: CGFloat = 58
    var onSelect: (AppLanguage) -> Void = { _ in }

    private let spacing: CGFloat = 10
    private let columns = 3

    private var rows: [[AppLanguage]] {
        stride(from: 0, to: AppLanguage.allCases.count, by: columns).map {
            Array(AppLanguage.allCases[$0..<min($0 + columns, AppLanguage.allCases.count)])
        }
    }

    var body: some View {
        GeometryReader { geo in
            let width = (geo.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            VStack(spacing: spacing) {
                ForEach(rows, id: \.first) { row in
                    HStack(spacing: spacing) {
                        ForEach(row) { lang in
                            tile(lang, width: width)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: CGFloat(rows.count) * rowHeight + CGFloat(rows.count - 1) * spacing)
    }

    private func tile(_ lang: AppLanguage, width: CGFloat) -> some View {
        let selected = language == lang.rawValue
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { language = lang.rawValue }
            onSelect(lang)
        } label: {
            VStack(spacing: 3) {
                Text(lang.nativeName)
                    .font(.serif(rowHeight > 52 ? 18 : 16))
                    .foregroundStyle(selected ? Theme.goldLight : Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(lang.englishName.uppercased())
                    .font(.sans(8, .semibold))
                    .tracking(1.3)
                    .foregroundStyle(selected ? Theme.goldLight.opacity(0.75) : Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 6)
            .frame(width: width, height: rowHeight)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Theme.navy : Theme.surface)
                    .shadow(color: Theme.navy.opacity(selected ? 0.22 : 0.05), radius: selected ? 10 : 4, y: selected ? 5 : 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Theme.gold.opacity(0.7) : Theme.hairline, lineWidth: selected ? 1 : 0.75)
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Избор на јазик во лист (од Профил или од почетниот екран).
/// Изборот се применува кога листот ќе се затвори - апликацијата се преисцртува на новиот јазик
/// по затворањето, наместо листот да исчезне под прстот.
struct LanguageSheet: View {
    @Binding var language: String
    var onSelect: (AppLanguage) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @State private var pending: String?

    private var selection: Binding<String> {
        Binding(get: { pending ?? language }, set: { pending = $0 })
    }

    private func commit() {
        guard let pending, pending != language, let chosen = AppLanguage(rawValue: pending) else { return }
        language = pending
        onSelect(chosen)
    }

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Eyebrow(L("Јазик", "Language"), color: Theme.gold)
                    Spacer()
                    CircleIconButton(systemName: "xmark") { dismiss() }
                }
                Text(L("Избери јазик", "Choose your language"))
                    .font(.serif(30))
                    .foregroundStyle(Theme.ink)
                LanguageGrid(language: selection, rowHeight: 58)
                Button { dismiss() } label: {
                    Text(L("Готово", "Done"))
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 6)
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .onDisappear(perform: commit)
    }
}

/// Прв екран: избор на јазик пред сè друго. Сè е на еден екран, без лизгање.
struct LanguagePickerView: View {
    @AppStorage(AppLanguage.storageKey) private var language: String = AppLanguage.en.rawValue
    @AppStorage("languageChosen") private var languageChosen: Bool = false
    /// Секој избор на јазик го преисцртува екранот - влезната анимација само првиот пат.
    private static var introPlayed = false
    @State private var appeared = LanguagePickerView.introPlayed

    var body: some View {
        ZStack {
            PaperBackground()

            GeometryReader { geo in
                let logo = min(max(geo.size.height * 0.15, 72), 140)
                let fixed = logo + 190 + 56 + 40
                let rowHeight = min(max((geo.size.height - fixed - 4 * 10) / 5, 44), 64)
                VStack(spacing: 0) {
                    Image("BrandMark")
                        .resizable()
                        .scaledToFit()
                        .frame(height: logo)
                        .shadow(color: Theme.navy.opacity(0.18), radius: 14, y: 8)
                        .padding(.top, 8)

                    Text("TRIPDROBE")
                        .font(.sans(11, .semibold))
                        .tracking(5)
                        .foregroundStyle(Theme.navy)
                        .padding(.top, 14)

                    Text(L("Добредојде.", "Welcome."))
                        .font(.serif(36))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 10)
                        .contentTransition(.opacity)

                    Text(L("Избери јазик", "Choose your language"))
                        .font(.sans(14))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.top, 4)

                    Spacer(minLength: 14)

                    LanguageGrid(language: $language, rowHeight: rowHeight)

                    Spacer(minLength: 14)

                    Button {
                        languageChosen = true
                    } label: {
                        HStack(spacing: 10) {
                            Text(L("Продолжи", "Continue"))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .regular))
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .frame(height: geo.size.height)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
        .onAppear {
            guard !appeared else { return }
            Self.introPlayed = true
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }
        }
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
                    Text("TRIPDROBE")
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
                        benefit("icloud", L("Резервна копија - ништо не се губи", "Backed up - nothing gets lost"))
                        benefit("ipad.and.iphone", L("Истите патувања на секој уред", "The same trips on every device"))
                        benefit("hanger", L("Гардероба и аутфити - секогаш со тебе", "Wardrobe and outfits - always with you"))
                        benefit("person.2", L("Патувај со пријатели - заедничка листа", "Travel with friends - a shared list"))
                    }
                    .padding(.bottom, 36)

                    VStack(spacing: 12) {
                        if AppConfig.appleSignInEnabled {
                            ContinueWithAppleButton(isWorking: account.isWorking) {
                                Task { error = await account.signInWithApple() }
                            }
                        }

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
                            Text(L("Веќе имам акаунт - најави се", "I already have an account - sign in"))
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

                    Text(L("Акаунтот е задолжителен: патувањата, гардеробата и аутфитите се чуваат на него - ништо не се губи, а при одјава ништо не останува на телефонот.",
                           "An account is required: your trips, wardrobe and outfits live in it - nothing gets lost, and nothing stays on the phone after you sign out."))
                        .font(.sans(12))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 24)

                    LegalConsentNote()
                        .padding(.top, 14)

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
