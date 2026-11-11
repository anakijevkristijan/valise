import SwiftUI

struct TripDetailView: View {
    let tripID: UUID

    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var account: AccountService
    @EnvironmentObject private var wardrobe: WardrobeStore
    @EnvironmentObject private var premium: PremiumStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("userName") private var userName: String = ""

    enum Tab: String, CaseIterable { case packing, plan, exit }

    @State private var tab: Tab = .packing
    @State private var addItemCategory: ItemCategory?
    @State private var addTogether = false
    @State private var showAddExit = false
    @State private var newExitTitle = ""
    @State private var confirmDelete = false
    @State private var confirmRegenerate = false
    @State private var isRefreshing = false
    @State private var showStory = false
    @State private var showEdit = false
    /// Од кој чекор се отвора уредувањето (2 = превоз и багаж).
    @State private var editStartStep = 0
    @State private var showAddCompanion = false
    @State private var newCompanionName = ""
    @State private var showAccount = false
    @State private var isInviting = false
    @State private var inviteResult: InviteResult?
    @State private var showPaywall = false

    struct InviteResult: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let shareMessage: String?
    }

    var body: some View {
        Group {
            if let trip = store.trip(tripID) {
                content(trip)
            } else {
                PaperBackground()
                    .onAppear { dismiss() }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await refreshWeather(force: false) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshWeather(force: false) }
            }
        }
    }

    /// Слики за App Store (само Debug): лизни до бараниот дел или отвори Story.
    private func showScreenshot(_ proxy: ScrollViewProxy) async {
        guard ScreenshotMode.isOn else { return }
        try? await Task.sleep(nanoseconds: 700_000_000)
        if let anchor = ScreenshotMode.anchor {
            proxy.scrollTo(anchor, anchor: .top)
        }
        switch ScreenshotMode.screen {
        case "story": showStory = true
        case "exit": tab = .exit
        case "plan": tab = .plan
        case "dates":
            editStartStep = 1
            showEdit = true
        case "edit-bags":
            editStartStep = 2
            showEdit = true
        default: break
        }
    }

    // MARK: Распоред

    private func content(_ trip: Trip) -> some View {
        ZStack {
            PaperBackground()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        topBar(trip)
                        titleBlock(trip)
                        BoardingPassCard(trip: trip)
                        if trip.isCloud && !trip.isMine && !trip.isPast && needsMemberSetup(trip) {
                            memberSetupCard(trip)
                        }
                        if !trip.isPast {
                            ReminderOfferCard()
                        }
                        if premium.isPremium {
                            companionsSection(trip)
                                .id("shot-friends")
                            weatherSection(trip)
                                .id("shot-weather")
                            TripOutfitsSection(trip: trip)
                                .id("shot-outfits")
                            BagFitCard(trip: trip)
                                .id("shot-bags")
                        } else {
                            // Бесплатно: само листата за пакување. Поканет во туѓо патување - ги гледа сопатниците.
                            if !trip.travelers.isEmpty { companionsSection(trip) }
                            PremiumTeaserCard()
                        }
                        tabPicker(trip)
                            .id("shot-packing")

                        tabContent(trip)
                            .transition(.opacity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 60)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.horizontal)
                }
                .scrollIndicators(.hidden)
                .refreshable { await refreshWeather(force: true) }
                .task { await showScreenshot(proxy) }
            }
        }
        .task(priority: .background) { await PhotoService.prefetchStory(for: trip.destination) }
        .sensoryFeedback(.selection, trigger: trip.packedCount)
        .sensoryFeedback(.success, trigger: trip.totalCount > 0 && trip.packedCount == trip.totalCount)
        .sheet(item: $addItemCategory) { category in
            AddItemSheet(initialCategory: category, isShared: addTogether) { item in
                let shared = addTogether
                store.mutate(tripID) { t in
                    if shared {
                        var copy = item
                        copy.assignee = t.isCloud ? t.myCompanionID : nil
                        var list = t.together ?? []
                        list.append(copy)
                        t.together = list
                    } else {
                        t.items.append(item)
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(28)
        }
        .fullScreenCover(isPresented: $showEdit) {
            TripWizardView(editing: trip, startStep: editStartStep) { _ in }
                .environmentObject(store)
                .environmentObject(premium)
        }
        .sheet(isPresented: $showStory) {
            StorySheet(trip: trip)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showPaywall) {
            PremiumSheet().environmentObject(premium)
        }
        .onChange(of: premium.isPremium) { _, unlocked in
            if unlocked { Task { await refreshWeather(force: true) } }
        }
        .onChange(of: wardrobe.outfitRowSignature(for: trip), initial: true) { _, _ in
            syncOutfitRows()
        }
        .sheet(isPresented: $showAccount) {
            AccountView(startWith: .signUp)
                .environmentObject(account)
        }
        .sheet(item: $inviteResult) { result in
            InviteResultSheet(result: result)
                .presentationDetents([.medium])
                .presentationCornerRadius(28)
        }
        .alert(L("Сопатник", "Travel companion"), isPresented: $showAddCompanion) {
            TextField(L("Име", "Name"), text: $newCompanionName)
                .textInputAutocapitalization(.words)
            Button(L("Додај", "Add")) {
                let name = newCompanionName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    store.mutate(tripID) { t in
                        var list = t.companions ?? []
                        list.append(Companion(name: name))
                        t.companions = list
                        PackingEngine.ensureTogether(&t)
                    }
                }
                newCompanionName = ""
            }
            Button(L("Откажи", "Cancel"), role: .cancel) { newCompanionName = "" }
        }
        .alert(L("Нова ставка", "New item"), isPresented: $showAddExit) {
            TextField(L("пр. Исклучен рутер", "e.g. Router switched off"), text: $newExitTitle)
            Button(L("Додај", "Add")) {
                let title = newExitTitle.trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    store.mutate(tripID) { $0.exitChecklist.append(ChecklistItem(title: title, icon: "checkmark.circle")) }
                }
                newExitTitle = ""
            }
            Button(L("Откажи", "Cancel"), role: .cancel) { newExitTitle = "" }
        }
        .confirmationDialog(trip.isMine ? L("Да се избрише патувањето?", "Delete this trip?") : L("Да излезеш од патувањето?", "Leave this trip?"),
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(trip.isMine ? L("Избриши", "Delete") : L("Излези", "Leave"), role: .destructive) {
                store.delete(tripID)
                dismiss()
            }
        } message: {
            Text(trip.isMine
                 ? (trip.travelers.contains(where: \.hasAccount)
                    ? L("Патувањето ќе се избрише и кај сопатниците.", "The trip will be deleted for your companions too.")
                    : L("Листата и сите белешки ќе се изгубат.", "The list and all notes will be lost."))
                 : L("Патувањето ќе остане кај другите.", "The trip stays for everyone else."))
        }
        .confirmationDialog(L("Нова листа?", "Rebuild the list?"), isPresented: $confirmRegenerate, titleVisibility: .visible) {
            Button(L("Состави повторно", "Rebuild")) {
                withAnimation {
                    store.mutate(tripID) {
                        PackingEngine.rebuild(&$0)
                        $0.dismissedSuggestions = []
                    }
                }
            }
        } message: {
            Text(L("Листата ќе се состави одново според последната прогноза. Спакуваното и рачно додаденото остануваат.",
                   "The list is rebuilt from the latest forecast. Packed and custom items stay."))
        }
    }

    private func topBar(_ trip: Trip) -> some View {
        HStack(spacing: 10) {
            CircleIconButton(systemName: "chevron.left") { dismiss() }
            Spacer()
            Button {
                if premium.isPremium { showStory = true } else { showPaywall = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: premium.isPremium ? "camera.aperture" : "lock.fill")
                        .font(.system(size: 13, weight: .regular))
                    Text("STORY")
                        .font(.sans(11, .semibold))
                        .tracking(1.6)
                }
                .foregroundStyle(Theme.goldLight)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(Capsule().fill(Theme.navy))
            }
            .buttonStyle(PressableStyle())
            ShareLink(item: trip.shareText) {
                CircleIcon(systemName: "square.and.arrow.up")
            }
            Menu {
                Button(L("Уреди патување", "Edit trip"), systemImage: "pencil") {
                    editStartStep = 0
                    showEdit = true
                }
                if trip.isCloud && !trip.isMine {
                    // Член: свои датуми (доаѓа подоцна, си оди порано…) - важат само за него
                    Button(L("Смени датуми", "Change dates"), systemImage: "calendar") {
                        editStartStep = 1
                        showEdit = true
                    }
                }
                if premium.isPremium {
                    Button(L("Освежи прогноза", "Refresh forecast"), systemImage: "arrow.clockwise") {
                        Task { await refreshWeather(force: true) }
                    }
                }
                Button(L("Состави ја листата одново", "Rebuild the list"), systemImage: "wand.and.stars") {
                    confirmRegenerate = true
                }
                Divider()
                Button(trip.isMine ? L("Избриши патување", "Delete trip") : L("Излези од патувањето", "Leave trip"),
                       systemImage: trip.isMine ? "trash" : "rectangle.portrait.and.arrow.right",
                       role: .destructive) {
                    confirmDelete = true
                }
            } label: {
                CircleIcon(systemName: "ellipsis")
            }
            .accessibilityLabel(CircleIcon.label(for: "ellipsis"))
        }
        .padding(.top, 8)
    }

    private func titleBlock(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Eyebrow(headerEyebrow(trip), color: Theme.gold)
                Spacer()
                Pill(text: trip.countdownText, icon: "calendar")
            }
            Text(trip.title)
                .font(.serif(44))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
            Text(heroDetail(trip))
                .font(.sans(14))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    /// „🇫🇷  France“; повеќе градови - знамињата и државите.
    private func headerEyebrow(_ trip: Trip) -> String {
        guard trip.isMultiStop else { return "\(trip.destination.flag)  \(trip.destination.country)" }
        var flags: [String] = []
        for stop in trip.allStops where !flags.contains(stop.place.flag) { flags.append(stop.place.flag) }
        return flags.joined(separator: " ") + "  " + Trip.joined(trip.countryNames)
    }

    private func heroDetail(_ trip: Trip) -> String {
        var parts = [Fmt.range(trip.startDate, trip.endDate), Fmt.nights(trip.nightCount), trip.transport.title]
        if trip.isMultiStop { parts.insert(trip.stopsText, at: 0) }
        if let airline = trip.airline, airline.id != "other" { parts.append(airline.name) }
        return parts.joined(separator: " · ")
    }

    // MARK: Сопатници

    private func companionsSection(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(L("Сопатници", "Travel companions"))
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(trip.travelers) { companion in
                        Menu {
                            if !companion.hasAccount && companion.inviteKey != nil {
                                ShareLink(item: TripStore.inviteMessage(friend: companion.name, trip: trip, me: userName)) {
                                    Label(L("Испрати покана за Tripdrobe", "Send a Tripdrobe invite"), systemImage: "envelope")
                                }
                            }
                            ShareLink(item: trip.shareText(for: companion, from: userName)) {
                                Label(L("Испрати му/ѝ листа", "Send them the list"), systemImage: "paperplane")
                            }
                            if trip.isMine {
                                Button(L("Отстрани", "Remove"), systemImage: "trash", role: .destructive) {
                                    withAnimation {
                                        store.mutate(tripID) { t in
                                            t.companions = (t.companions ?? []).filter { $0.id != companion.id }
                                            if let uid = companion.uid {
                                                t.memberUIDs = (t.memberUIDs ?? []).filter { $0 != uid }
                                                t.dropFamilyShares(with: uid)
                                            }
                                            if var together = t.together {
                                                for i in together.indices where together[i].assignee == companion.id {
                                                    together[i].assignee = nil
                                                }
                                                t.together = together
                                            }
                                            PackingEngine.dissolveTogether(&t)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(String(companion.firstName.prefix(1)).uppercased())
                                    .font(.serif(13))
                                    .foregroundStyle(Theme.goldLight)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Theme.navy))
                                Text(companion.firstName)
                                    .font(.sans(14, .medium))
                                    .foregroundStyle(Theme.ink)
                                if companion.hasAccount {
                                    Image(systemName: "checkmark.icloud")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.sage)
                                } else if companion.inviteKey != nil {
                                    Image(systemName: "clock")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.muted)
                                }
                                let count = trip.items.filter { $0.assignee == companion.id }.count
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.codes(14))
                                        .foregroundStyle(Theme.gold)
                                }
                            }
                            .padding(.leading, 6)
                            .padding(.trailing, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Theme.surface))
                            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 0.75))
                        }
                    }

                    Menu {
                        if premium.isPremium {
                            Button(L("Од контакти", "From contacts"), systemImage: "person.crop.circle.badge.plus") {
                                pickContact()
                            }
                            Button(L("Само име", "Just a name"), systemImage: "character.cursor.ibeam") {
                                showAddCompanion = true
                            }
                        } else {
                            Button(L("Пријатели - Premium", "Friends - Premium"), systemImage: "lock.fill") {
                                showPaywall = true
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isInviting {
                                ProgressView().controlSize(.small).tint(Theme.navy)
                            } else {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 13, weight: .light))
                            }
                            Text(L("Додај пријател", "Add a friend"))
                                .font(.sans(13, .medium))
                        }
                        .foregroundStyle(Theme.navy)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .overlay(Capsule().strokeBorder(Theme.navy.opacity(0.3), style: StrokeStyle(lineWidth: 0.75, dash: [3, 3])))
                    }
                    .disabled(isInviting)
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
            companionPlans(trip)

            if !trip.travelers.isEmpty {
                Text(L("Секој ја гледа само својата листа. Заедничките работи се во „Заедно“ - таму избирате кој што носи.",
                       "Everyone sees only their own list. Shared things live in “Together” - that's where you pick who brings what."))
                    .font(.sans(12))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func pickContact() {
        guard account.isSignedIn, store.isSignedIn else {
            showAccount = true
            return
        }
        ContactPickerPresenter.shared.present { contact in
            guard let contact else { return }
            Task { await invite(contact) }
        }
    }

    @MainActor
    private func invite(_ contact: PickedContact) async {
        isInviting = true
        let outcome = await store.invite(name: contact.name, phones: contact.phones, emails: contact.emails, to: tripID)
        isInviting = false
        let first = contact.name.split(separator: " ").first.map(String.init) ?? contact.name
        switch outcome {
        case .joined:
            inviteResult = InviteResult(
                title: L("\(first) е на Tripdrobe ✓", "\(first) is on Tripdrobe ✓"),
                detail: L("Додаден/а е во патувањето. Кај неа/него веќе се гледа истата листа - штиклирањето се синхронизира.",
                          "They've been added to the trip and already see the same list - ticks sync both ways."),
                shareMessage: nil)
        case .alreadyIn:
            inviteResult = InviteResult(
                title: L("\(first) веќе патува со тебе", "\(first) is already on this trip"),
                detail: "", shareMessage: nil)
        case .invited(_, let message):
            inviteResult = InviteResult(
                title: L("\(first) уште нема Tripdrobe", "\(first) isn't on Tripdrobe yet"),
                detail: L("Испрати покана. Кога ќе се регистрира со истиот број или е-пошта, патувањето автоматски ќе го/ја чека.",
                          "Send an invite. Once they sign up with the same number or email, the trip will be waiting for them."),
                shareMessage: message)
        case .isYou:
            inviteResult = InviteResult(title: L("Тоа си ти 🙂", "That's you 🙂"), detail: "", shareMessage: nil)
        case .failed:
            inviteResult = InviteResult(
                title: L("Не успеа", "Couldn't add them"),
                detail: L("Контактот нема број или е-пошта, или нема интернет.", "The contact has no number or email, or you're offline."),
                shareMessage: nil)
        }
    }

    // MARK: Време

    private func weatherSection(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(L("Време", "Weather"))
                Spacer()
                if isRefreshing {
                    ProgressView().controlSize(.small).tint(Theme.navy)
                } else {
                    Text(updatedLabel(trip))
                        .font(.sans(11, .medium))
                        .foregroundStyle(Theme.muted)
                }
            }

            if trip.weather.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: "cloud.sun")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(Theme.navy)
                    Text(trip.isPast
                         ? L("Патувањето заврши.", "This trip is over.")
                         : L("Прогнозата не е достапна. Повлечи надолу за да пробаш повторно.", "No forecast yet. Pull down to try again."))
                        .font(.sans(14))
                        .foregroundStyle(Theme.inkSoft)
                }
                .luxCard(padding: 18)
            } else {
                WeatherStrip(days: trip.weather)
                if trip.weather.contains(where: { !$0.isClimate }) { WeatherCreditView() }
            }
        }
    }

    private func updatedLabel(_ trip: Trip) -> String {
        var label = WeatherSource.describe(trip.weather)
        if let updated = trip.weatherUpdatedAt {
            let f = DateFormatter()
            f.locale = AppLanguage.current.locale
            f.dateFormat = "HH:mm"
            label += " · " + f.string(from: updated)
        }
        return label
    }

    // MARK: Табови

    /// Пакување · План (места по денови) · Пред излез. Ако не собираат во ширина (долги преводи) - лентата се лизга.
    private func tabPicker(_ trip: Trip) -> some View {
        ViewThatFits(in: .horizontal) {
            tabRow(trip)
            ScrollView(.horizontal) { tabRow(trip) }
                .scrollIndicators(.hidden)
        }
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func tabRow(_ trip: Trip) -> some View {
        let places = trip.allPlaces
        return HStack(alignment: .bottom, spacing: 18) {
            tabButton(.packing, title: L("Пакување", "Packing"), count: "\(trip.packedCount)/\(trip.totalCount)")
            tabButton(.plan, title: L("План", "Plan"),
                      count: places.isEmpty ? "" : "\(places.filter(\.isDone).count)/\(places.count)")
            tabButton(.exit, title: L("Пред излез", "Before you leave"), count: "\(trip.exitChecklist.filter(\.isDone).count)/\(trip.exitChecklist.count)")
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func tabContent(_ trip: Trip) -> some View {
        if tab == .packing {
            packingSection(trip)
        } else if tab == .plan {
            if premium.isPremium {
                TripPlanSection(trip: trip)
            } else {
                PremiumLockRow(icon: "mappin.and.ellipse",
                               title: L("План по денови", "Day-by-day plan"),
                               detail: L("Места за посета, сликање и пазарење, ресторани и каде спиеш - ден по ден, со час и адреса.",
                                         "Sights, photo spots, shopping, restaurants and where you're staying - day by day, with a time and an address."))
            }
        } else if premium.isPremium {
            exitSection(trip)
        } else {
            PremiumLockRow(icon: "house",
                           title: L("Последен круг низ домот", "One last walk through home"),
                           detail: L("Шпорет, прозорци, полнач, клучеви - листа за мирен излез од дома.",
                                     "Stove, windows, charger, keys - a checklist for leaving home calmly."))
        }
    }

    private func tabButton(_ value: Tab, title: String, count: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { tab = value }
        } label: {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.sans(12, .semibold))
                    .tracking(1.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if !count.isEmpty {
                    Text(count)
                        .font(.codes(14))
                        .opacity(0.6)
                        .lineLimit(1)
                }
            }
            .fixedSize()
            .foregroundStyle(tab == value ? Theme.navy : Theme.muted)
            .padding(.bottom, 11)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(tab == value ? Theme.navy : Color.clear)
                    .frame(height: 1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Пакување

    private func packingSection(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(trip.packedCount == trip.totalCount && trip.totalCount > 0
                         ? L("Сè е спакувано.", "All packed.")
                         : L("\(trip.packedCount) од \(trip.totalCount) спакувани", "\(trip.packedCount) of \(trip.totalCount) packed"))
                        .font(.serif(22))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(Int((trip.progress * 100).rounded()))%")
                        .font(.codes(22))
                        .foregroundStyle(Theme.navy)
                }
                GaugeBar(ratio: trip.progress, color: Theme.navy, height: 3)
            }

            let suggestions = PackingEngine.suggestions(for: trip)
            if !suggestions.isEmpty {
                SuggestionsCard(items: suggestions,
                                onAdd: { item in
                                    withAnimation {
                                        store.mutate(tripID) { t in
                                            if t.together != nil && item.isShareable {
                                                var copy = item
                                                copy.assignee = t.isCloud ? t.myCompanionID : nil
                                                t.together?.append(copy)
                                            } else {
                                                t.items.append(item)
                                            }
                                        }
                                    }
                                },
                                onDismissAll: {
                                    withAnimation {
                                        store.mutate(tripID) { $0.dismissedSuggestions.append(contentsOf: suggestions.map(\.identity)) }
                                    }
                                })
            }

            if trip.together != nil {
                togetherBlock(trip)
            }

            let showsFamily = (premium.isPremium && trip.hasFamily) || !trip.sharedWithMe.isEmpty
            if trip.together != nil || showsFamily {
                Text(L("МОЈА ЛИСТА", "MY LIST"))
                    .font(.sans(11, .semibold))
                    .tracking(2.4)
                    .foregroundStyle(Theme.gold)
                    .padding(.top, 4)
            }

            ForEach(ItemCategory.allCases) { category in
                let group = trip.items.filter { $0.category == category }
                if !group.isEmpty {
                    categoryBlock(category, items: group, trip: trip)
                }
            }

            Button {
                addTogether = false
                addItemCategory = .accessories
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text(L("Додај свој предмет", "Add your own item"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())

            // Децата и миленичињата - секое со своја листа (Premium); листа споделена со мене ја гледам секогаш
            if showsFamily {
                FamilyPackingSections(trip: trip)
                    .padding(.top, 8)
            }

            Text(L("Допри за спакувано. Држи подолго за количина или бришење.",
                   "Tap to mark as packed. Long-press for quantity or removal."))
                .font(.sans(12))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    /// „Заедно“ - единствениот заеднички дел: кој што носи, синхронизирано кај сите.
    private func togetherBlock(_ trip: Trip) -> some View {
        let items = trip.togetherItems
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "person.2")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Theme.gold)
                Text(L("ЗАЕДНО", "TOGETHER"))
                    .font(.sans(12, .semibold))
                    .tracking(2.4)
                    .foregroundStyle(Theme.navy)
                Spacer()
                if trip.undecidedCount > 0 {
                    Text(L("\(trip.undecidedCount) неодлучени", "\(trip.undecidedCount) undecided"))
                        .font(.sans(11, .semibold))
                        .foregroundStyle(Theme.terracotta)
                }
            }
            Text(L("Работи што ги делите - изберете кој што носи. Се гледа и штиклира кај сите. Кој ќе штиклира дека зел нешто, тоа станува негово.",
                   "Things you share - choose who brings what. Everyone sees and ticks the same list. Whoever ticks an item takes it over."))
                .font(.sans(12))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    PackingRow(item: item,
                               companions: trip.travelers,
                               assigneeName: trip.companionName(item.assignee),
                               meID: trip.myCompanionID,
                               isCloud: trip.isCloud,
                               showsWho: true,
                               onAssign: { assign(item, to: $0) },
                               onToggle: { toggle(item) },
                               onIncrease: { changeQuantity(item, by: 1) },
                               onDecrease: { changeQuantity(item, by: -1) },
                               onDelete: { remove(item) })
                    if index < items.count - 1 {
                        Hairline().padding(.leading, 50)
                    }
                }
                if !items.isEmpty { Hairline() }
                Button {
                    addTogether = true
                    addItemCategory = .toiletries
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 18)
                        Text(L("Додај заедничко", "Add shared item"))
                            .font(.sans(12, .semibold))
                            .tracking(1.2)
                            .textCase(.uppercase)
                        Spacer()
                    }
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .luxCard(padding: 0, fill: Theme.surface, radius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1)
            )
        }
    }

    private func categoryBlock(_ category: ItemCategory, items: [PackingItem], trip: Trip) -> some View {
        // Облека, обувки, костими, очила…: колку од секој предмет веќе е во аутфитите (синхронизирано постојано)
        let shares: [UUID: ClothingTarget.Share] =
            category != .documents && !wardrobe.wearCounts(for: trip).isEmpty
            ? wardrobe.shares(for: trip) : [:]
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(category.title.uppercased())
                    .font(.sans(11, .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.navy)
                Spacer()
                Text("\(items.filter(\.isPacked).count)/\(items.count)")
                    .font(.codes(14))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 2)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    PackingRow(item: item,
                               outfitShare: shares[item.id],
                               onToggle: { toggle(item) },
                               onIncrease: { changeQuantity(item, by: 1) },
                               onDecrease: { changeQuantity(item, by: -1) },
                               onDelete: { remove(item) })
                    if index < items.count - 1 {
                        Hairline().padding(.leading, 50)
                    }
                }
                Hairline()
                Button {
                    addTogether = false
                    addItemCategory = category
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 18)
                        Text(L("Додај", "Add"))
                            .font(.sans(12, .semibold))
                            .tracking(1.2)
                            .textCase(.uppercase)
                        Spacer()
                    }
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .luxCard(padding: 0, radius: 16)
        }
    }

    /// Промена на предмет - било во мојата листа или во „Заедно“.
    private func updateItem(_ id: UUID, _ change: @escaping (inout PackingItem) -> Void) {
        store.mutate(tripID) { trip in
            if let i = trip.items.firstIndex(where: { $0.id == id }) {
                change(&trip.items[i])
            } else if var together = trip.together, let i = together.firstIndex(where: { $0.id == id }) {
                change(&together[i])
                trip.together = together
            }
        }
    }

    private func toggle(_ item: PackingItem) {
        withAnimation(.easeInOut(duration: 0.2)) {
            store.mutate(tripID) { trip in
                if let i = trip.items.firstIndex(where: { $0.id == item.id }) {
                    trip.items[i].isPacked.toggle()
                } else if var together = trip.together, let i = together.firstIndex(where: { $0.id == item.id }) {
                    together[i].isPacked.toggle()
                    // Заедничко: кој штиклира дека го зел - тој го носи (пр. било за Виктор, го зедов јас)
                    if together[i].isPacked, !trip.isMine(together[i]) {
                        if trip.isCloud {
                            if let me = trip.myCompanionID { together[i].assignee = me }
                        } else {
                            together[i].assignee = nil   // локално nil = јас
                        }
                    }
                    trip.together = together
                }
            }
        }
    }

    private func assign(_ item: PackingItem, to companion: UUID?) {
        withAnimation(.easeInOut(duration: 0.2)) {
            updateItem(item.id) { $0.assignee = companion }
        }
    }

    private func changeQuantity(_ item: PackingItem, by delta: Int) {
        updateItem(item.id) { entry in
            let newValue = max(1, entry.quantity + delta)
            entry.quantity = newValue
            entry.wornCount = min(entry.wornCount, newValue)
            entry.quantityEdited = true
            // Рачно сменет ред од аутфитите станува обичен - гардеробата повеќе не ја менува бројката
            entry.fromOutfits = nil
        }
    }

    /// Додаден во туѓо патување: багажот и стилот се засега на сопственикот → избери ги своите.
    private static let samePlanKey = "member-same-plan"

    /// Член што уште ги има градовите/датумите или багажот на сопственикот.
    private func needsMemberSetup(_ trip: Trip) -> Bool {
        let planOpen = trip.ownPlan != true && !trip.dismissedSuggestions.contains(Self.samePlanKey)
        return trip.ownBags != true || planOpen
    }

    /// Поканет во туѓо патување: свои градови и датуми (тргам од друго место, доаѓам подоцна…) и свој багаж.
    private func memberSetupCard(_ trip: Trip) -> some View {
        let owner = (trip.companions ?? []).first { $0.uid != nil && $0.uid == trip.ownerUID }?.firstName
        let planOpen = trip.ownPlan != true && !trip.dismissedSuggestions.contains(Self.samePlanKey)
        let bagsOpen = trip.ownBags != true
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Theme.navy)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.goldPale))
                Text(L("Направи го твое", "Make it yours"))
                    .font(.sans(15, .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Text(owner.map {
                L("\($0) те додаде во патувањето. Засега градовите, датумите и багажот се како кај \($0). Тргаш од друго место, доаѓаш подоцна или остануваш подолго? Смени ги - важат само за тебе, а кај \($0) ништо не се менува.",
                  "\($0) added you to this trip. For now the cities, dates and luggage are \($0)'s. Leaving from somewhere else, arriving later or staying longer? Change them - they're only yours and nothing changes for \($0).")
            } ?? L("Засега градовите, датумите и багажот се како кај тој што те додаде. Смени ги - важат само за тебе.",
                   "For now the cities, dates and luggage are those of whoever added you. Change them - they're only yours."))
                .font(.sans(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if planOpen {
                    Button {
                        editStartStep = 0
                        showEdit = true
                    } label: {
                        Text(L("Мои градови и датуми", "My cities & dates"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                if bagsOpen {
                    Button {
                        editStartStep = 2
                        showEdit = true
                    } label: {
                        Text(L("Мој багаж", "My luggage"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            if planOpen {
                Button {
                    store.mutate(tripID) { $0.dismissedSuggestions.append(Self.samePlanKey) }
                } label: {
                    Text(owner.map { L("Патувам исто како \($0)", "I'm travelling the same as \($0)") }
                         ?? L("Патувам истите датуми", "I'm travelling the same dates"))
                        .font(.sans(12, .medium))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .luxCard(padding: 16, radius: 18)
    }

    /// Кој е со мене кога и каде (заедничко патување со различни градови и датуми).
    @ViewBuilder
    private func companionPlans(_ trip: Trip) -> some View {
        let mine = trip.myPlan
        let differing = trip.travelerPlans.filter { !$0.plan.sameRoute(as: mine) }
        if !differing.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(differing) { entry in
                    if entry.id != differing.first?.id { Hairline().padding(.leading, 46) }
                    HStack(alignment: .top, spacing: 12) {
                        Text(String(entry.companion.firstName.prefix(1)).uppercased())
                            .font(.serif(13))
                            .foregroundStyle(Theme.goldLight)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Theme.navy))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.companion.firstName)
                                .font(.sans(14, .semibold))
                                .foregroundStyle(Theme.ink)
                            Text("\(entry.plan.routeText) · \(entry.plan.dateText)")
                                .font(.sans(12))
                                .foregroundStyle(Theme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(togetherText(mine: mine, theirs: entry.plan))
                                .font(.sans(12, .medium))
                                .foregroundStyle(Theme.gold)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                }
            }
            .luxCard(padding: 0, radius: 18)
        }
    }

    private func togetherText(mine: MemberPlan, theirs: MemberPlan) -> String {
        guard let overlap = mine.overlap(with: theirs) else {
            return L("Не се преклопувате", "You don't overlap")
        }
        let dates = MemberPlan.range(overlap.start, overlap.end)
        if overlap.cities.isEmpty {
            return L("Во исто време, на различни места · \(dates)", "Same time, different places · \(dates)")
        }
        let cities = overlap.cities.joined(separator: ", ")
        return L("Заедно · \(dates) · \(cities)", "Together · \(dates) · \(cities)")
    }

    /// Аутфитите имаат парче што листата го нема (пр. сукња) → редот сам се додава.
    private func syncOutfitRows() {
        guard var copy = store.trip(tripID), wardrobe.syncOutfitRows(&copy) else { return }
        store.mutate(tripID) { trip in
            _ = wardrobe.syncOutfitRows(&trip)
        }
    }

    private func remove(_ item: PackingItem) {
        withAnimation {
            store.mutate(tripID) { trip in
                trip.items.removeAll { $0.id == item.id }
                trip.together?.removeAll { $0.id == item.id }
                if !item.isCustom { trip.dismissedSuggestions.append(item.identity) }
            }
        }
    }

    // MARK: Излез од дома

    private func exitSection(_ trip: Trip) -> some View {
        let done = trip.exitChecklist.filter(\.isDone).count
        let allDone = !trip.exitChecklist.isEmpty && done == trip.exitChecklist.count
        let firstName = userName.split(separator: " ").first.map(String.init) ?? userName

        return VStack(alignment: .leading, spacing: 20) {
            if allDone {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundStyle(Theme.goldLight)
                    Text(L("Спремно за пат.", "Ready to go."))
                        .font(.serif(28))
                        .foregroundStyle(Theme.ticketText)
                    Text(L("Домот е безбеден. Убав пат, \(firstName).", "Home is secure. Have a beautiful trip, \(firstName)."))
                        .font(.sans(14))
                        .foregroundStyle(Theme.ticketText.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(26)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.ticket(trip.tint)))
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Последен круг низ домот", "One last walk through home"))
                        .font(.serif(22))
                        .foregroundStyle(Theme.ink)
                    Text(L("Помини ја листата на излез - за да не мислиш на шпоретот на аеродром.",
                           "Run through this on your way out, so you're not thinking about the stove at the airport."))
                        .font(.sans(14))
                        .foregroundStyle(Theme.inkSoft)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(trip.exitChecklist.enumerated()), id: \.element.id) { index, item in
                    ExitRow(item: item) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            store.mutate(tripID) { t in
                                if let i = t.exitChecklist.firstIndex(where: { $0.id == item.id }) {
                                    t.exitChecklist[i].isDone.toggle()
                                }
                            }
                        }
                    } onDelete: {
                        withAnimation {
                            store.mutate(tripID) { t in t.exitChecklist.removeAll { $0.id == item.id } }
                        }
                    }
                    if index < trip.exitChecklist.count - 1 {
                        Hairline().padding(.leading, 56)
                    }
                }
            }
            .luxCard(padding: 0, radius: 16)

            HStack(spacing: 10) {
                Button {
                    showAddExit = true
                } label: {
                    Label(L("Додај", "Add"), systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    withAnimation {
                        store.mutate(tripID) { t in
                            for i in t.exitChecklist.indices { t.exitChecklist[i].isDone = false }
                        }
                    }
                } label: {
                    Label(L("Одново", "Reset"), systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .sensoryFeedback(.success, trigger: allDone)
    }

    // MARK: Прогноза - при секое отворање

    @MainActor
    private func refreshWeather(force: Bool) async {
        isRefreshing = true
        await store.refreshWeather(tripID, force: force)
        isRefreshing = false
    }
}

// MARK: - Ред во листата

struct PackingRow: View {
    let item: PackingItem
    var companions: [Companion] = []
    var assigneeName: String?
    var meID: UUID? = nil
    var isCloud: Bool = false
    var showsWho: Bool = false
    /// Колку од ова е веќе во аутфитите (пр. 3 од 5 маици).
    var outfitShare: ClothingTarget.Share? = nil
    var onAssign: (UUID?) -> Void = { _ in }
    let onToggle: () -> Void
    let onIncrease: () -> Void
    let onDecrease: () -> Void
    let onDelete: () -> Void

    private var showsWhoPicker: Bool { showsWho }

    private var isMine: Bool { item.assignee != nil && item.assignee == meID }
    private var isAssignedToOther: Bool { item.assignee != nil && item.assignee != meID }

    /// Што пишува на копчето „кој носи“.
    private var whoLabel: String {
        if item.assignee == nil { return isCloud ? L("Кој?", "Who?") : L("Јас", "Me") }
        if isMine { return L("Јас", "Me") }
        return assigneeName ?? "?"
    }

    @ViewBuilder
    private var whoMenu: some View {
        Button(L("Јас", "Me"), systemImage: (isCloud ? isMine : item.assignee == nil) ? "checkmark" : "person") {
            onAssign(isCloud ? meID : nil)
        }
        ForEach(companions) { companion in
            Button(companion.firstName, systemImage: item.assignee == companion.id ? "checkmark" : "person") {
                onAssign(companion.id)
            }
        }

    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(item.isPacked ? Theme.navy : Color.clear)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(item.isPacked ? Theme.navy : Theme.muted.opacity(0.6), lineWidth: 1)
                        if item.isPacked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.goldLight)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(width: 18, height: 18)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.displayName)
                            .strikethrough(item.isPacked, color: Theme.muted.opacity(0.6))
                            .font(.sans(15))
                            .foregroundStyle(item.isPacked ? Theme.muted : Theme.ink)

                        if let detail = item.detailText {
                            Text(detail)
                                .font(.sans(12))
                                .foregroundStyle(Theme.muted)
                        }

                        // Само кога аутфитите го надминуваат планираното
                        if let share = outfitShare, share.have > share.need {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(L("\(share.have - share.need) повеќе од планираното", "\(share.have - share.need) more than planned"))
                                    .font(.sans(11, .semibold))
                            }
                            .foregroundStyle(Theme.terracotta)
                        }
                    }

                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(item.isPacked ? [.isSelected] : [])
            .accessibilityHint(L("Допри за спакувано", "Double-tap to mark as packed"))

            if showsWhoPicker {
                Menu {
                    whoMenu
                } label: {
                    HStack(spacing: 4) {
                        Text(whoLabel.uppercased())
                            .font(.sans(10, .semibold))
                            .tracking(1)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(isAssignedToOther ? Theme.goldLight : (isCloud && item.assignee == nil ? Theme.terracotta : Theme.navy))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(isAssignedToOther ? Theme.navy : Color.clear))
                    .overlay(Capsule().strokeBorder(Theme.navy.opacity(isAssignedToOther ? 0 : 0.25), lineWidth: 0.75))
                }
            }

            if let share = outfitShare {
                // До планираното (×6): колку има во аутфитите
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "hanger")
                            .font(.system(size: 9, weight: .semibold))
                        Text("\(share.have)")
                            .font(.sans(12, .bold))
                    }
                    .foregroundStyle(share.have > share.need ? Theme.ticketText
                                     : (share.have == share.need ? Theme.sage : Theme.gold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(share.have > share.need ? Theme.terracotta
                                               : (share.have == share.need ? Theme.sage : Theme.gold).opacity(0.14)))
                    Text("×\(item.quantity)")
                        .font(.codes(17))
                        .foregroundStyle(item.isPacked ? Theme.muted : Theme.navy)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L("Во аутфитите \(share.have) од планирани \(item.quantity)",
                                      "\(share.have) in outfits of \(item.quantity) planned"))
            } else if item.category != .documents {
                Text("×\(item.quantity)")
                    .font(.codes(17))
                    .foregroundStyle(item.isPacked ? Theme.muted : Theme.navy)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .contextMenu {
            if showsWho && !companions.isEmpty {
                Menu(L("Кој го носи", "Who brings it"), systemImage: "person.2") {
                    whoMenu
                }
                Divider()
            }
            Button(L("Уште едно", "One more"), systemImage: "plus", action: onIncrease)
            Button(L("Едно помалку", "One less"), systemImage: "minus", action: onDecrease)
            Divider()
            Button(L("Отстрани", "Remove"), systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

struct ExitRow: View {
    let item: ChecklistItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(item.isDone ? Theme.muted : Theme.navy)
                    .frame(width: 26)

                Text(item.displayTitle)
                    .strikethrough(item.isDone, color: Theme.muted.opacity(0.6))
                    .font(.sans(15))
                    .foregroundStyle(item.isDone ? Theme.muted : Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                ZStack {
                    Circle()
                        .fill(item.isDone ? Theme.navy : Color.clear)
                    Circle()
                        .strokeBorder(item.isDone ? Theme.navy : Theme.muted.opacity(0.6), lineWidth: 1)
                    if item.isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.goldLight)
                    }
                }
                .frame(width: 22, height: 22)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(L("Отстрани", "Remove"), systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Багаж

struct BagFitCard: View {
    let trip: Trip

    var body: some View {
        let level = PackingEngine.fitLevel(for: trip)
        let color: Color = level == .over ? Theme.terracotta : (level == .snug ? Theme.gold : Theme.navy)

        VStack(alignment: .leading, spacing: 18) {
            // Сите багажи (пр. мала торба + кабински + чекиран)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(trip.allBags.enumerated()), id: \.offset) { _, spec in
                    HStack(spacing: 14) {
                        Image(systemName: spec.icon)
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(Theme.navy)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(spec.displayTitle)
                                .font(.serif(trip.allBags.count > 1 ? 17 : 20))
                                .foregroundStyle(Theme.ink)
                            Text(spec.limitText)
                                .font(.sans(13))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        Spacer()
                    }
                }
            }

            meter(label: trip.allBags.count > 1 ? L("Волумен (вкупно)", "Volume (total)") : L("Волумен", "Volume"),
                  value: "\(Int(trip.packedVolume.rounded())) / \(Int(trip.totalUsableVolume.rounded())) L",
                  ratio: trip.fillRatio,
                  color: color)

            if let weightRatio = trip.weightRatio, let limit = trip.totalWeightLimit {
                meter(label: L("Тежина (проценка)", "Weight (estimate)"),
                      value: "\(Fmt.number((trip.packedWeight * 10).rounded() / 10)) / \(Fmt.number(limit)) kg",
                      ratio: weightRatio,
                      color: weightRatio > 1 ? Theme.terracotta : (weightRatio > 0.9 ? Theme.gold : Theme.navy))
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: level == .over ? "exclamationmark.triangle" : (level == .snug ? "hand.raised" : "checkmark.circle"))
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(color)
                    .padding(.top, 1)
                Text(PackingEngine.advice(for: trip))
                    .font(.sans(14))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)

            // Свои мерки поголеми од дозволеното кај авиокомпанијата
            ForEach(trip.ownBagWarnings, id: \.self) { warning in
                ownBagWarning(warning)
            }
        }
        .luxCard(padding: 20, radius: 18)
    }

    private func ownBagWarning(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .padding(.top, 1)
            Text(text)
                .font(.sans(13, .semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.terracotta)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.terracotta.opacity(0.09)))
    }

    private func meter(label: String, value: String, ratio: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .font(.sans(10, .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text(value)
                    .font(.codes(17))
                    .foregroundStyle(Theme.ink)
            }
            GaugeBar(ratio: ratio, color: color, height: 3)
        }
    }
}

// MARK: - Предлози

struct SuggestionsCard: View {
    let items: [PackingItem]
    let onAdd: (PackingItem) -> Void
    let onDismissAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Theme.gold)
                Text(L("Предлози според новата прогноза", "Suggested by the new forecast"))
                    .font(.sans(14, .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button(L("Отфрли", "Dismiss"), action: onDismissAll)
                    .font(.sans(12, .medium))
                    .foregroundStyle(Theme.muted)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        Button { onAdd(item) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                Text(item.quantity > 1 ? "\(item.displayName) ×\(item.quantity)" : item.displayName)
                                    .font(.sans(13, .medium))
                            }
                            .foregroundStyle(Theme.navy)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Theme.surface))
                            .overlay(Capsule().strokeBorder(Theme.navy.opacity(0.25), lineWidth: 0.75))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
        }
        .luxCard(padding: 16, fill: Theme.goldPale, radius: 16)
    }
}

// MARK: - Додавање предмет

struct AddItemSheet: View {
    let initialCategory: ItemCategory
    var isShared: Bool = false
    /// Свој наслов (пр. „За Ана“).
    var title: String?
    let onAdd: (PackingItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var quantity = 1
    @State private var category: ItemCategory = .accessories
    @State private var didSetup = false
    @FocusState private var focused: Bool

    init(initialCategory: ItemCategory, isShared: Bool = false, title: String? = nil,
         onAdd: @escaping (PackingItem) -> Void) {
        self.initialCategory = initialCategory
        self.isShared = isShared
        self.title = title
        self.onAdd = onAdd
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Eyebrow(title ?? (isShared ? L("Заедничко", "Shared item") : L("Нов предмет", "New item")), color: Theme.gold)
                        Spacer()
                        CircleIconButton(systemName: "xmark") { dismiss() }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        TextField("", text: $name, prompt: Text(L("Што да спакуваме?", "What should we pack?")).foregroundColor(Theme.muted.opacity(0.7)))
                            .font(.serif(26))
                            .foregroundStyle(Theme.ink)
                            .focused($focused)
                            .submitLabel(.done)
                            .onSubmit(add)
                        Rectangle()
                            .fill(focused ? Theme.navy : Theme.hairline)
                            .frame(height: 1)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(L("Категорија", "Category"))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                            ForEach(ItemCategory.allCases) { c in
                                ChipButton(title: c.title, isSelected: category == c, expand: true) {
                                    category = c
                                }
                            }
                        }
                    }

                    HStack {
                        Text(L("Количина", "Quantity"))
                            .font(.sans(15, .medium))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        HStack(spacing: 16) {
                            stepButton("minus") { quantity = max(1, quantity - 1) }
                            Text("\(quantity)")
                                .font(.codes(24))
                                .foregroundStyle(Theme.ink)
                                .frame(minWidth: 28)
                            stepButton("plus") { quantity = min(30, quantity + 1) }
                        }
                    }
                    .luxCard(padding: 16)

                    Button(action: add) {
                        Text(L("Додај во листата", "Add to list"))
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(24)
                .containerRelativeFrame(.horizontal)
            }
        }
        .onAppear {
            if !didSetup {
                category = initialCategory
                didSetup = true
            }
            focused = true
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.navy)
                .frame(width: 34, height: 34)
                .overlay(Circle().strokeBorder(Theme.navy.opacity(0.25), lineWidth: 0.75))
        }
        .buttonStyle(PressableStyle())
    }

    private func add() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onAdd(PackingItem(name: trimmed,
                          category: category,
                          quantity: quantity,
                          note: nil,
                          unitVolume: 0.5,
                          unitWeight: 0.2,
                          isCustom: true))
        dismiss()
    }
}


// MARK: - Резултат од покана

struct InviteResultSheet: View {
    let result: TripDetailView.InviteResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Eyebrow(L("Сопатник", "Companion"), color: Theme.gold)
                    Spacer()
                    CircleIconButton(systemName: "xmark") { dismiss() }
                }
                Text(result.title)
                    .font(.serif(28))
                    .foregroundStyle(Theme.ink)
                if !result.detail.isEmpty {
                    Text(result.detail)
                        .font(.sans(15))
                        .foregroundStyle(Theme.inkSoft)
                        .lineSpacing(3)
                }
                Spacer(minLength: 0)
                if let message = result.shareMessage {
                    ShareLink(item: message) {
                        HStack(spacing: 10) {
                            Image(systemName: "paperplane")
                                .font(.system(size: 12, weight: .semibold))
                            Text(L("Испрати покана", "Send invite"))
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button(L("Супер", "Great")) { dismiss() }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(24)
        }
    }
}
