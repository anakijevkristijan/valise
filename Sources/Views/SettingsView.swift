import SwiftUI
import StoreKit
import UserNotifications

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
    @State private var confirmSignOut = false
    @State private var legalDoc: LegalDoc?
    @AppStorage(TripReminders.enabledKey) private var remindersOn = true
    @AppStorage(PushService.friendAlertsKey) private var friendAlertsOn = true
    @ObservedObject private var router = NotificationRouter.shared

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
                    premiumCard
                    if premium.isSandbox { testFreeSwitch }

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
                                    // Известувањата од пријателите на новиот јазик
                                    Task { await PushService.shared.upload() }
                                }
                            }
                        }
                    }

                    themesSection

                    remindersSection

                    VStack(alignment: .leading, spacing: 14) {
                        infoRow("suitcase", L("Патувања", "Trips"), "\(store.trips.count)")
                        Hairline()
                        infoRow("airplane", L("Авиокомпании во базата", "Airlines in the database"), "\(Airlines.all.count - 1)")
                    }
                    .luxCard(padding: 20)

                    legalSection

                    Text(L("Мерките за багаж се информативни. Авиокомпаниите ги менуваат често — пред лет секогаш провери на нивниот сајт.",
                           "Baggage sizes are a guide. Airlines change them often — always check their website before you fly."))
                        .font(.sans(13))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    if account.isSignedIn {
                        Button {
                            confirmSignOut = true
                        } label: {
                            Text(L("Одјави се", "Sign out"))
                                .foregroundStyle(Theme.navy)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    Text("TRIPDROBE 2.6")
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
        .onChange(of: userName) { _, latest in draftName = latest }   // пр. сменето во Акаунт
        .onDisappear(perform: save)
        .sheet(isPresented: $showAccount) {
            AccountView(startWith: .signUp, onDeleteAllTrips: { store.deleteAll() })
                .environmentObject(account)
        }
        .sheet(isPresented: $showPremium) {
            PremiumSheet()
                .environmentObject(premium)
        }
        .sheet(item: $legalDoc) { doc in
            LegalView(doc: doc)
        }
        .confirmationDialog(L("Да се одјавиш?", "Sign out?"), isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button(L("Одјави се", "Sign out"), role: .destructive) {
                save()
                account.signOut()
                dismiss()
            }
        } message: {
            Text(L("Патувањата и гардеробата остануваат на твојот акаунт и се враќаат кога ќе се најавиш повторно. На овој телефон апликацијата почнува од почеток.",
                   "Your trips and wardrobe stay in your account and come back when you sign in again. On this phone the app starts fresh."))
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

    // MARK: Premium

    // MARK: Потсетници

    /// Потсетници за пакување (локални известувања): вклучи/исклучи.
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $remindersOn) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Потсетници за патувања", "Trip reminders"))
                        .font(.sans(15, .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(L("3 дена и ден пред тргнување, и ден пред враќање",
                           "3 days and 1 day before you leave, and the day before you head home"))
                        .font(.sans(12))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Theme.navy)

            if account.isSignedIn {
                Hairline()
                Toggle(isOn: $friendAlertsOn) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("Известувања од пријателите", "Notifications from friends"))
                            .font(.sans(15, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(L("Кога некој те додава во патување или те означува да понесеш нешто",
                               "When someone adds you to a trip or asks you to bring something"))
                            .font(.sans(12))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Theme.navy)
            }

            if (remindersOn || friendAlertsOn) && router.authorization == .denied {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(L("Известувањата за Tripdrobe се исклучени на iPhone — вклучи ги во Поставки",
                           "Notifications for Tripdrobe are off on this iPhone — turn them on in Settings"))
                        .font(.sans(12, .medium))
                        .foregroundStyle(Theme.terracotta)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)
            }
        }
        .luxCard(padding: 18, radius: 18)
        .task { await router.refreshAuthorization() }
        .onChange(of: remindersOn) { _, on in
            Task {
                if on, router.authorization == .notDetermined {
                    await TripReminders.requestPermission()
                }
                await router.refreshAuthorization()
                await TripReminders.reschedule(trips: store.trips, premium: premium.isPremium)
            }
        }
        .onChange(of: friendAlertsOn) { _, on in
            Task {
                if on, router.authorization == .notDetermined {
                    await TripReminders.requestPermission()
                    await router.refreshAuthorization()
                }
                await PushService.shared.setFriendAlerts(on)
            }
        }
    }

    /// Втор ред во картичката: активно, откажано (до кога) или проблем со плаќањето.
    private var premiumCardDetail: String {
        guard premium.isPremium else {
            return L("Прогноза, авиокомпании, гардероба, пријатели", "Forecast, airlines, wardrobe, friends")
        }
        if premium.hasBillingIssue {
            return L("Плаќањето не помина · провери", "Payment issue · check it")
        }
        if !premium.willAutoRenew, let date = premium.expirationDate {
            return L("Откажано · трае до \(Fmt.dayMonth(date))", "Cancelled · until \(Fmt.dayMonth(date))")
        }
        return L("Активно · управувај со претплатата", "Active · manage your subscription")
    }

    /// Premium: купи, или (ако е купено) управувај со претплатата.
    private var premiumCard: some View {
        Button { showPremium = true } label: {
            HStack(spacing: 14) {
                Image(systemName: premium.isPremium ? "checkmark.seal" : "sparkles")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Theme.navy)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.goldPale))
                VStack(alignment: .leading, spacing: 3) {
                    Text(premium.isPremium ? "Tripdrobe Premium" : L("Пробај Premium", "Try Premium"))
                        .font(.sans(15, .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(premiumCardDetail)
                        .font(.sans(12))
                        .foregroundStyle(premium.isPremium && premium.hasBillingIssue ? Theme.terracotta : Theme.inkSoft)
                        .lineLimit(1)
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

    /// Само во TestFlight (тест-купување): да се види апликацијата без Premium.
    private var testFreeSwitch: some View {
        Toggle(isOn: Binding(get: { premium.simulatesFree },
                             set: { on in Task { await premium.setSimulatesFree(on) } })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Тест: бесплатна верзија", "Test: free version"))
                    .font(.sans(14, .medium))
                    .foregroundStyle(Theme.ink)
                Text(L("Само во TestFlight — да видиш како изгледа апликацијата без Premium.",
                       "TestFlight only — see the app without Premium."))
                    .font(.sans(11))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Theme.navy)
        .luxCard(padding: 14, radius: 18)
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

    /// Името се зачувува и на акаунтот, за да е исто насекаде.
    /// По одјава ништо не се запишува (инаку старото име би останало за следниот акаунт).
    private func save() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, account.hasSession, trimmed != userName else { return }
        userName = trimmed
        let phone = account.phone
        Task { await account.updateProfile(name: trimmed, phone: phone) }
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
    @State private var selectedID = PremiumStore.yearlyID
    /// Купено од овој прозорец — по отклучувањето сам се затвора.
    @State private var purchasedHere = false
    @State private var legalDoc: LegalDoc?
    @State private var manageSubscriptions = false

    private var selected: Product? { premium.product(selectedID) ?? premium.products.first }

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Text("TRIPDROBE PREMIUM")
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
                        Text(L("Целото патување,\nспакувано.", "Your whole trip,\nsorted."))
                            .font(.serif(34))
                            .foregroundStyle(Theme.ink)
                        Text(L("Бесплатно имаш листа за пакување за колку сакаш патувања. Premium го додава сè останато.",
                               "Free gives you a packing list for as many trips as you like. Premium adds everything else."))
                            .font(.sans(15))
                            .foregroundStyle(Theme.inkSoft)
                            .lineSpacing(3)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        benefit("cloud.sun", L("Прогноза за секој ден и колку од секое парче да спакуваш", "Day-by-day forecast and how many of each item to pack"))
                        benefit("airplane", L("Багаж за 140+ авиокомпании и дали сè ќе собере", "Baggage rules for 140+ airlines and whether it all fits"))
                        benefit("map", L("Повеќе градови во едно патување, со перална каде ја има", "Several cities in one trip, with laundry where you have it"))
                        benefit("hanger", L("Гардероба и аутфити по денови", "Your wardrobe and outfits for every day"))
                        benefit("person.2", L("Патувања со пријатели — кој што носи", "Trips with friends — who brings what"))
                        benefit("camera.aperture", L("Story за Instagram", "Stories for Instagram"))
                        benefit("house", L("„Пред излез“ — мирен излез од дома", "“Before you leave” checklist"))
                        benefit("paintpalette", L("\(Palette.all.filter { $0.isPremium }.count) премиум теми", "\(Palette.all.filter { $0.isPremium }.count) premium themes"))
                    }

                    if premium.isPremium {
                        activeSection
                    } else if premium.storeAvailable {
                        plansSection
                    } else if !premium.allowsTestUnlock {
                        // App Store / TestFlight, но производите уште не се вчитале
                        VStack(spacing: 12) {
                            if premium.isLoadingProducts || !premium.didLoad {
                                ProgressView().tint(Theme.navy)
                            } else {
                                Text(premium.canMakePayments
                                     ? L("Не можам да се поврзам со App Store. Провери дали имаш интернет и дали си најавен во App Store (Поставки → твоето име → Media & Purchases), па обиди се повторно.",
                                         "Couldn't reach the App Store. Check that you're online and signed in to the App Store (Settings → your name → Media & Purchases), then try again.")
                                     : L("Купувањата во апликации се исклучени на овој iPhone (Поставки → Screen Time → Content & Privacy Restrictions).",
                                         "In-app purchases are turned off on this iPhone (Settings → Screen Time → Content & Privacy Restrictions)."))
                                    .font(.sans(12))
                                    .foregroundStyle(Theme.muted)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
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

                        Text(L("Плаќањето работи во TestFlight и App Store. Додека тестираш со Sideloadly, Premium е бесплатен.",
                               "Payments work in TestFlight and the App Store. While testing with Sideloadly, Premium is free."))
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
        .sheet(item: $legalDoc) { doc in
            LegalView(doc: doc)
        }
        .manageSubscriptionsSheet(isPresented: $manageSubscriptions)
        .sensoryFeedback(.success, trigger: premium.isPremium)
        .onChange(of: premium.isPremium) { _, unlocked in
            // Штом е купено, прозорецот се затвора и сè е веднаш отклучено
            if unlocked && purchasedHere {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
            }
        }
        .presentationCornerRadius(28)
    }

    // MARK: Активно

    private var activeSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 18, weight: .light))
                Text(activeTitle)
                    .font(.sans(15, .semibold))
            }
            .foregroundStyle(Theme.navy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .overlay(Capsule().strokeBorder(Theme.navy.opacity(0.25), lineWidth: 0.75))

            if premium.hasSubscription {
                if premium.hasBillingIssue {
                    Text(L("Плаќањето не помина. Apple ќе се обиде повторно — провери го начинот на плаќање во App Store за Premium да не прекине.",
                           "The payment didn't go through. Apple will try again — check your payment method in the App Store so Premium isn't interrupted."))
                        .font(.sans(13))
                        .foregroundStyle(Theme.terracotta)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let date = premium.expirationDate {
                    Text(premium.willAutoRenew
                         ? L("Следно обновување: \(Fmt.longDate(date))", "Renews on \(Fmt.longDate(date))")
                         : L("Откажано · Premium трае до \(Fmt.longDate(date))", "Cancelled · Premium until \(Fmt.longDate(date))"))
                        .font(.sans(13))
                        .foregroundStyle(Theme.inkSoft)
                }
                if premium.isSandbox {
                    Text(L("Тест-верзија (TestFlight): претплатата се обновува забрзано, приближно еднаш дневно, и ништо не се наплаќа. Во App Store трае цел месец или година.",
                           "Test version (TestFlight): the subscription renews faster, about once a day, and nothing is charged. In the App Store it lasts a full month or year."))
                        .font(.sans(11))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(L("Управувај со претплатата", "Manage subscription")) {
                    manageSubscriptions = true
                }
                .font(.sans(14, .semibold))
                .foregroundStyle(Theme.navy)
            }

            if premium.allowsTestUnlock {
                Button(L("Заклучи повторно (тест)", "Lock again (test)")) {
                    premium.lockForTesting()
                }
                .font(.sans(12))
                .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var activeTitle: String {
        switch premium.activeProductID {
        case PremiumStore.yearlyID: return L("Premium · годишна претплата", "Premium · yearly")
        case PremiumStore.monthlyID: return L("Premium · месечна претплата", "Premium · monthly")
        default: return L("Premium е отклучен", "Premium is unlocked")
        }
    }

    // MARK: Планови

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(premium.products, id: \.id) { product in
                planCard(product)
            }

            if let product = selected {
                Button {
                    purchasedHere = true
                    Task { await premium.purchase(product) }
                } label: {
                    HStack(spacing: 10) {
                        if premium.isWorking { ProgressView().tint(Theme.goldLight) }
                        Text(ctaTitle(product))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(premium.isWorking)
                .padding(.top, 6)

                // Задолжително (Apple 3.1.2 и закони за автоматско обновување): јасно до копчето
                Text(disclosure(product))
                    .font(.sans(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = premium.errorMessage {
                Text(error)
                    .font(.sans(12, .medium))
                    .foregroundStyle(Theme.terracotta)
            }

            HStack(spacing: 16) {
                Button(L("Услови", "Terms")) { legalDoc = .terms }
                Button(L("Приватност", "Privacy")) { legalDoc = .privacy }
                Button(L("Врати купување", "Restore")) {
                    Task { await premium.restore() }
                }
            }
            .font(.sans(12, .semibold))
            .foregroundStyle(Theme.navy)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    private func planCard(_ product: Product) -> some View {
        let isSelected = selected?.id == product.id
        let isYearly = product.id == PremiumStore.yearlyID
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedID = product.id }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(isSelected ? Theme.navy : Theme.muted)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(planTitle(product))
                            .font(.sans(16, .semibold))
                            .foregroundStyle(Theme.ink)
                        if isYearly {
                            Text(L("НАЈИСПЛАТЛИВО", "BEST VALUE"))
                                .font(.sans(9, .bold))
                                .tracking(1)
                                .foregroundStyle(Theme.goldLight)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Theme.navy))
                        }
                    }
                    Text(planDetail(product))
                        .font(.sans(12))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.sans(16, .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(product.periodWord.map { "/ \($0)" } ?? L("еднаш", "once"))
                        .font(.sans(11))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Theme.navy : Theme.hairline, lineWidth: isSelected ? 1.5 : 0.75)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func planTitle(_ product: Product) -> String {
        product.id == PremiumStore.yearlyID ? L("Годишно", "Yearly") : L("Месечно", "Monthly")
    }

    private func planDetail(_ product: Product) -> String {
        var parts: [String] = []
        if let monthly = product.monthlyEquivalent { parts.append(L("\(monthly) месечно", "\(monthly) a month")) }
        if let trial = trialText(product) { parts.append(L("\(trial) бесплатно", "\(trial) free")) }
        if parts.isEmpty { parts.append(L("Откажи кога сакаш", "Cancel anytime")) }
        return parts.joined(separator: " · ")
    }

    /// Пробата се нуди само ако корисникот уште не ја искористил.
    private func trialText(_ product: Product) -> String? {
        guard product.id == PremiumStore.yearlyID, premium.trialEligible else { return nil }
        return product.freeTrialText
    }

    private func ctaTitle(_ product: Product) -> String {
        if let trial = trialText(product) { return L("Пробај \(trial) бесплатно", "Try \(trial) free") }
        return L("Претплати се · \(product.displayPrice)", "Subscribe · \(product.displayPrice)")
    }

    private func disclosure(_ product: Product) -> String {
        let period = product.periodWord ?? L("период", "period")
        let renew = L("Претплатата се обновува автоматски и се наплаќа \(product.displayPrice) на \(period) преку твојот Apple ID, сè додека не ја откажеш најмалку 24 часа пред крајот на периодот. Откажуваш кога сакаш во Поставки на iPhone → твоето име → Претплати.",
                      "The subscription renews automatically and \(product.displayPrice) per \(period) is charged to your Apple ID until you cancel at least 24 hours before the end of the period. Cancel anytime in iPhone Settings → your name → Subscriptions.")
        if let trial = trialText(product) {
            return L("\(trial) бесплатно, потоа \(product.displayPrice) на \(period). ", "\(trial) free, then \(product.displayPrice) per \(period). ") + renew
        }
        return renew
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
