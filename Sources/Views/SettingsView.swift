import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var premium: PremiumStore
    @EnvironmentObject private var account: AccountService
    @Environment(\.dismiss) private var dismiss
    @State private var showAccount = false
    @AppStorage(Theme.storageKey) private var themeID: String = Palette.classic.id
    @State private var showPremium = false
    @AppStorage("userName") private var userName: String = ""
    @AppStorage(AppLanguage.storageKey) private var language: String = AppLanguage.mk.rawValue

    @State private var draftName = ""
    @State private var confirmReset = false
    @State private var legalDoc: LegalDoc?

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Eyebrow(L("Профил", "Profile"), color: Theme.gold)
                        Spacer()
                        CircleIconButton(systemName: "xmark") { save(); dismiss() }
                    }

                    accountCard

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(L("Твоето име", "Your name"))
                        TextField("", text: $draftName)
                            .font(.serif(26))
                            .foregroundStyle(Theme.ink)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit(save)
                        Hairline()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(L("Јазик", "Language"))
                        HStack(spacing: 8) {
                            ForEach(AppLanguage.allCases) { lang in
                                ChipButton(title: lang.nativeName, isSelected: language == lang.rawValue, expand: true) {
                                    save()
                                    language = lang.rawValue
                                }
                            }
                        }
                    }

                    themesSection

                    VStack(alignment: .leading, spacing: 14) {
                        infoRow("suitcase", L("Патувања", "Trips"), "\(store.trips.count)")
                        Hairline()
                        infoRow("airplane", L("Авиокомпании во базата", "Airlines in the database"), "\(Airlines.all.count - 1)")
                        Hairline()
                        infoRow("clock", L("Мерки за багаж", "Baggage sizes"), Airlines.dataUpdated)
                        Hairline()
                        infoRow("cloud.sun", L("Прогноза", "Forecast"), AppConfig.weatherKitEnabled ? "Apple Weather" : "Open-Meteo")
                        Hairline()
                        infoRow("map", L("Пребарување места", "Place search"), "Apple Maps")
                        Hairline()
                        infoRow("photo", L("Фотографии", "Photos"), "Wikimedia Commons")
                        WeatherCreditView()
                    }
                    .luxCard(padding: 20)

                    legalSection

                    Text(L("Мерките за багаж се информативни. Авиокомпаниите ги менуваат често — пред лет секогаш провери на нивниот сајт.",
                           "Baggage sizes are a guide. Airlines change them often — always check their website before you fly."))
                        .font(.sans(13))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Text(L("Избриши ги сите патувања", "Delete all trips"))
                            .foregroundStyle(Theme.terracotta)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Text("VALISE 2.5")
                        .font(.sans(10, .semibold))
                        .tracking(3)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
                .padding(24)
                .containerRelativeFrame(.horizontal)
            }
        }
        .onAppear { draftName = userName }
        .onDisappear(perform: save)
        .sheet(isPresented: $showAccount) {
            AccountView(startWith: .signUp)
                .environmentObject(account)
        }
        .sheet(isPresented: $showPremium) {
            PremiumSheet()
                .environmentObject(premium)
        }
        .sheet(item: $legalDoc) { doc in
            LegalView(doc: doc)
        }
        .confirmationDialog(L("Да се избришат сите патувања?", "Delete all trips?"), isPresented: $confirmReset, titleVisibility: .visible) {
            Button(L("Избриши сè", "Delete everything"), role: .destructive) { store.deleteAll() }
        }
        .presentationCornerRadius(28)
    }

    // MARK: Правно

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(L("Приватност и услови", "Privacy & terms"))
            VStack(spacing: 0) {
                legalRow("hand.raised", L("Политика за приватност", "Privacy Policy")) { legalDoc = .privacy }
                Hairline().padding(.leading, 48)
                legalRow("doc.text", L("Услови за користење", "Terms of Use")) { legalDoc = .terms }
                if !LegalTexts.supportEmail.isEmpty, let url = URL(string: "mailto:\(LegalTexts.supportEmail)") {
                    Hairline().padding(.leading, 48)
                    Link(destination: url) {
                        legalLabel("envelope", L("Пиши ни", "Contact us"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .luxCard(padding: 0, radius: 16)
        }
    }

    private func legalRow(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            legalLabel(icon, title)
        }
        .buttonStyle(.plain)
    }

    private func legalLabel(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Theme.gold)
                .frame(width: 20)
            Text(title)
                .font(.sans(15))
                .foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: Акаунт

    private var accountCard: some View {
        Button { showAccount = true } label: {
            HStack(spacing: 14) {
                Image(systemName: account.isSignedIn ? "checkmark.icloud" : "icloud")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Theme.goldLight)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.navy))
                VStack(alignment: .leading, spacing: 3) {
                    Text(account.isSignedIn ? (account.profile?.email ?? "") : L("Создај акаунт или најави се", "Create an account or sign in"))
                        .font(.sans(15, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(account.isSignedIn
                         ? L("Синхронизирано · сопатници од контакти", "Synced · companions from contacts")
                         : L("Резервна копија и заеднички патувања", "Backup and shared trips"))
                        .font(.sans(12))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .luxCard(padding: 14, radius: 18)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Теми

    private var themesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(L("Тема", "Theme"))
                Spacer()
                if premium.isPremium {
                    Text("PREMIUM")
                        .font(.sans(9, .bold))
                        .tracking(1.6)
                        .foregroundStyle(Theme.gold)
                } else {
                    Button { showPremium = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                            Text(L("Отклучи ги сите", "Unlock all"))
                                .font(.sans(11, .semibold))
                        }
                        .foregroundStyle(Theme.gold)
                    }
                    .buttonStyle(.plain)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(Palette.all) { palette in
                    Button {
                        choose(palette)
                    } label: {
                        ThemeSwatch(palette: palette,
                                    isSelected: Theme.current.id == palette.id,
                                    isLocked: palette.isPremium && !premium.isPremium)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private func choose(_ palette: Palette) {
        if palette.isPremium && !premium.isPremium {
            showPremium = true
            return
        }
        save()
        themeID = palette.id
        dismiss()
    }

    private func save() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { userName = trimmed }
    }

    private func infoRow(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Theme.gold)
                .frame(width: 22)
            Text(title)
                .font(.sans(15))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(value)
                .font(.serif(15))
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

// MARK: - Мостра од тема (мала карта во боите на темата)

struct ThemeSwatch: View {
    let palette: Palette
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SKP")
                            .font(.codes(9))
                            .foregroundStyle(palette.ticketText.opacity(0.7))
                        Text("ROM")
                            .font(.codes(20))
                            .foregroundStyle(palette.ticketText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 9)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .background(TicketHalf(side: .top, cornerRadius: 9, notch: 4).fill(palette.tickets[0]))
                    .overlay(alignment: .bottom) {
                        DashedLine()
                            .stroke(palette.goldLight.opacity(0.5), style: StrokeStyle(lineWidth: 0.75, dash: [2, 2]))
                            .frame(height: 1)
                            .padding(.horizontal, 6)
                    }
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(palette.tickets[(i + 1) % palette.tickets.count])
                                .frame(width: 8, height: 8)
                        }
                        Spacer()
                        Capsule()
                            .fill(palette.goldLight)
                            .frame(width: 16, height: 4)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(TicketHalf(side: .bottom, cornerRadius: 9, notch: 4).fill(palette.tickets[0]))
                }
                .padding(8)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.paper)
                        MotifPattern(motif: palette.motif, color: palette.gold, opacity: 0.25, spacing: 22, size: 8)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                )
                .overlay(alignment: .top) {
                    switch palette.motif {
                    case .bows:
                        BowView(color: palette.goldLight, shade: palette.gold)
                            .frame(width: 22, height: 16)
                            .offset(y: 2)
                    case .pearls:
                        PearlStrand(color: palette.goldPale, count: 9)
                            .frame(width: 54, height: 12)
                            .offset(y: 3)
                    case .none:
                        EmptyView()
                    default:
                        MotifIcon(motif: palette.motif, palette: palette)
                            .frame(width: 17, height: 17)
                            .shadow(color: Color.black.opacity(0.12), radius: 1, x: 0, y: 1)
                            .offset(x: 26, y: 4)
                    }
                }

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(palette.goldLight)
                        .padding(5)
                        .background(Circle().fill(palette.primary))
                        .offset(x: -4, y: 4)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Theme.navy : Theme.hairline, lineWidth: isSelected ? 2 : 0.75)
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(palette.name)
                    .font(.sans(12, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(palette.isPremium ? "PREMIUM" : L("БЕСПЛАТНО", "FREE"))
                    .font(.sans(8, .bold))
                    .tracking(1.2)
                    .foregroundStyle(palette.isPremium ? Theme.gold : Theme.sage)
            }
        }
    }
}

// MARK: - Premium

struct PremiumSheet: View {
    @EnvironmentObject private var premium: PremiumStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Text("VALISE PREMIUM")
                            .font(.sans(11, .semibold))
                            .tracking(3)
                            .foregroundStyle(Theme.gold)
                        Spacer()
                        CircleIconButton(systemName: "xmark") { dismiss() }
                    }

                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(Palette.all.filter(\.isPremium)) { palette in
                                ThemeSwatch(palette: palette, isSelected: false, isLocked: false)
                                    .frame(width: 104)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("Направи го свое.", "Make it yours."))
                            .font(.serif(34))
                            .foregroundStyle(Theme.ink)
                        Text(L("Ексклузивни теми — од машнички и цвеќиња до Ноар. Секоја ги менува пасовите, целата апликација и Story сликите.",
                               "Exclusive themes — from bows and blossoms to Noir. Each one restyles your passes, the whole app and your Story images."))
                            .font(.sans(15))
                            .foregroundStyle(Theme.inkSoft)
                            .lineSpacing(3)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        benefit("paintpalette", L("\(Palette.all.filter { $0.isPremium }.count) премиум теми — Машнички, Балерина, Цреши, Ѕвездена ноќ…",
                                                  "\(Palette.all.filter { $0.isPremium }.count) premium themes — Coquette, Balletcore, Cherry, Celestial…"))
                        benefit("camera.aperture", L("Story во боите на темата", "Stories in your theme's colours"))
                        benefit("sparkles", L("Сите идни теми, без доплата", "All future themes included"))
                    }

                    if premium.isPremium {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal")
                                .font(.system(size: 18, weight: .light))
                            Text(L("Premium е отклучен", "Premium is unlocked"))
                                .font(.sans(15, .semibold))
                        }
                        .foregroundStyle(Theme.navy)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .overlay(Capsule().strokeBorder(Theme.navy.opacity(0.25), lineWidth: 0.75))

                        if premium.allowsTestUnlock {
                            Button(L("Заклучи повторно (тест)", "Lock again (test)")) {
                                premium.lockForTesting()
                            }
                            .font(.sans(12))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                        }
                    } else if premium.storeAvailable {
                        Button {
                            Task { await premium.purchase() }
                        } label: {
                            HStack(spacing: 10) {
                                if premium.isWorking { ProgressView().tint(Theme.goldLight) }
                                Text(L("Отклучи", "Unlock") + (premium.priceText.map { " · \($0)" } ?? ""))
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(premium.isWorking)

                        Button(L("Врати купување", "Restore purchase")) {
                            Task { await premium.restore() }
                        }
                        .font(.sans(13, .medium))
                        .foregroundStyle(Theme.navy)
                        .frame(maxWidth: .infinity)

                        Text(L("Еднократно плаќање. Без претплата.", "One-time purchase. No subscription."))
                            .font(.sans(12))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                    } else if !premium.allowsTestUnlock {
                        // App Store, но производот уште не се вчитал
                        VStack(spacing: 12) {
                            ProgressView().tint(Theme.navy)
                            Button(L("Обиди се повторно", "Try again")) {
                                Task { await premium.load() }
                            }
                            .font(.sans(13, .medium))
                            .foregroundStyle(Theme.navy)
                            Button(L("Врати купување", "Restore purchase")) {
                                Task { await premium.restore() }
                            }
                            .font(.sans(13, .medium))
                            .foregroundStyle(Theme.navy)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Button {
                            premium.unlockForTesting()
                        } label: {
                            Text(L("Отклучи за тестирање", "Unlock for testing"))
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Text(L("Плаќањето ќе работи кога апликацијата ќе биде на App Store. Додека тестираш, Premium е бесплатен.",
                               "Payments will work once the app is on the App Store. While testing, Premium is free."))
                            .font(.sans(12))
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(24)
                .containerRelativeFrame(.horizontal)
            }
        }
        .presentationCornerRadius(28)
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
