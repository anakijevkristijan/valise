import SwiftUI

struct TripDetailView: View {
    let tripID: UUID

    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("userName") private var userName: String = ""

    enum Tab: String, CaseIterable { case packing, exit }

    @State private var tab: Tab = .packing
    @State private var addItemCategory: ItemCategory?
    @State private var showAddExit = false
    @State private var newExitTitle = ""
    @State private var confirmDelete = false
    @State private var confirmRegenerate = false
    @State private var isRefreshing = false
    @State private var showStory = false
    @State private var showAddCompanion = false
    @State private var newCompanionName = ""

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
        .task { await refreshWeather(force: false) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshWeather(force: false) }
            }
        }
    }

    // MARK: Распоред

    private func content(_ trip: Trip) -> some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    topBar(trip)
                    titleBlock(trip)
                    BoardingPassCard(trip: trip)
                    companionsSection(trip)
                    weatherSection(trip)
                    BagFitCard(trip: trip)
                    tabPicker(trip)

                    Group {
                        if tab == .packing {
                            packingSection(trip)
                        } else {
                            exitSection(trip)
                        }
                    }
                    .transition(.opacity)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 60)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .refreshable { await refreshWeather(force: true) }
        }
        .task { _ = await PhotoService.photo(for: trip.destination) }
        .sensoryFeedback(.selection, trigger: trip.packedCount)
        .sensoryFeedback(.success, trigger: trip.items.count > 0 && trip.packedCount == trip.items.count)
        .sheet(item: $addItemCategory) { category in
            AddItemSheet(initialCategory: category) { item in
                store.mutate(tripID) { $0.items.append(item) }
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showStory) {
            StorySheet(trip: trip)
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
        .confirmationDialog(L("Да се избрише патувањето?", "Delete this trip?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L("Избриши", "Delete"), role: .destructive) {
                store.delete(tripID)
                dismiss()
            }
        } message: {
            Text(L("Листата и сите белешки ќе се изгубат.", "The list and all notes will be lost."))
        }
        .confirmationDialog(L("Нова листа?", "Rebuild the list?"), isPresented: $confirmRegenerate, titleVisibility: .visible) {
            Button(L("Состави повторно", "Rebuild")) {
                withAnimation {
                    store.mutate(tripID) {
                        $0.items = PackingEngine.regenerate($0)
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
                showStory = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.aperture")
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
                Button(L("Освежи прогноза", "Refresh forecast"), systemImage: "arrow.clockwise") {
                    Task { await refreshWeather(force: true) }
                }
                Button(L("Состави ја листата одново", "Rebuild the list"), systemImage: "wand.and.stars") {
                    confirmRegenerate = true
                }
                Divider()
                Button(L("Избриши патување", "Delete trip"), systemImage: "trash", role: .destructive) {
                    confirmDelete = true
                }
            } label: {
                CircleIcon(systemName: "ellipsis")
            }
        }
        .padding(.top, 8)
    }

    private func titleBlock(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Eyebrow("\(trip.destination.flag)  \(trip.destination.country)", color: Theme.gold)
                Spacer()
                Pill(text: trip.countdownText, icon: "calendar")
            }
            Text(trip.destination.name)
                .font(.serif(44))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
            Text(heroDetail(trip))
                .font(.sans(14))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func heroDetail(_ trip: Trip) -> String {
        var parts = [Fmt.range(trip.startDate, trip.endDate), Fmt.nights(trip.nightCount), trip.transport.title]
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
                            ShareLink(item: trip.shareText(for: companion, from: userName)) {
                                Label(L("Испрати му/ѝ листа", "Send them the list"), systemImage: "paperplane")
                            }
                            Button(L("Отстрани", "Remove"), systemImage: "trash", role: .destructive) {
                                withAnimation {
                                    store.mutate(tripID) { t in
                                        t.companions = (t.companions ?? []).filter { $0.id != companion.id }
                                        for i in t.items.indices where t.items[i].assignee == companion.id {
                                            t.items[i].assignee = nil
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

                    Button {
                        showAddCompanion = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 13, weight: .light))
                            Text(L("Додај пријател", "Add a friend"))
                                .font(.sans(13, .medium))
                        }
                        .foregroundStyle(Theme.navy)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .overlay(Capsule().strokeBorder(Theme.navy.opacity(0.3), style: StrokeStyle(lineWidth: 0.75, dash: [3, 3])))
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)

            if !trip.travelers.isEmpty {
                Text(L("Држи подолго на предмет за да избереш кој го носи. Тоа што го носи пријател не зафаќа место во твојот багаж.",
                       "Long-press an item to choose who brings it. What a friend carries doesn't take space in your bag."))
                    .font(.sans(12))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
            }
        }
    }

    private func updatedLabel(_ trip: Trip) -> String {
        var label = trip.weatherSource.label
        if let updated = trip.weatherUpdatedAt {
            let f = DateFormatter()
            f.locale = AppLanguage.current.locale
            f.dateFormat = "HH:mm"
            label += " · " + f.string(from: updated)
        }
        return label
    }

    // MARK: Табови

    private func tabPicker(_ trip: Trip) -> some View {
        HStack(spacing: 24) {
            tabButton(.packing, title: L("Пакување", "Packing"), count: "\(trip.packedCount)/\(trip.items.count)")
            tabButton(.exit, title: L("Пред излез", "Before you leave"), count: "\(trip.exitChecklist.filter(\.isDone).count)/\(trip.exitChecklist.count)")
            Spacer()
        }
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func tabButton(_ value: Tab, title: String, count: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { tab = value }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text(title.uppercased())
                        .font(.sans(12, .semibold))
                        .tracking(1.6)
                    Text(count)
                        .font(.codes(14))
                        .opacity(0.6)
                }
                .foregroundStyle(tab == value ? Theme.navy : Theme.muted)
                Rectangle()
                    .fill(tab == value ? Theme.navy : Color.clear)
                    .frame(height: 1.5)
            }
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Пакување

    private func packingSection(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(trip.packedCount == trip.items.count && !trip.items.isEmpty
                         ? L("Сè е спакувано.", "All packed.")
                         : L("\(trip.packedCount) од \(trip.items.count) спакувани", "\(trip.packedCount) of \(trip.items.count) packed"))
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
                                    withAnimation { store.mutate(tripID) { $0.items.append(item) } }
                                },
                                onDismissAll: {
                                    withAnimation {
                                        store.mutate(tripID) { $0.dismissedSuggestions.append(contentsOf: suggestions.map(\.identity)) }
                                    }
                                })
            }

            ForEach(ItemCategory.allCases) { category in
                let group = trip.items.filter { $0.category == category }
                if !group.isEmpty {
                    categoryBlock(category, items: group, trip: trip)
                }
            }

            Button {
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

            Text(L("Допри за спакувано. Држи подолго за количина, бришење или кој носи.",
                   "Tap to mark as packed. Long-press for quantity, removal or who brings it."))
                .font(.sans(12))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    private func categoryBlock(_ category: ItemCategory, items: [PackingItem], trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
                               companions: trip.travelers,
                               assigneeName: trip.companionName(item.assignee),
                               onAssign: { assign(item, to: $0) },
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

    private func toggle(_ item: PackingItem) {
        withAnimation(.easeInOut(duration: 0.2)) {
            store.mutate(tripID) { trip in
                if let i = trip.items.firstIndex(where: { $0.id == item.id }) {
                    trip.items[i].isPacked.toggle()
                }
            }
        }
    }

    private func assign(_ item: PackingItem, to companion: UUID?) {
        withAnimation(.easeInOut(duration: 0.2)) {
            store.mutate(tripID) { trip in
                if let i = trip.items.firstIndex(where: { $0.id == item.id }) {
                    trip.items[i].assignee = companion
                }
            }
        }
    }

    private func changeQuantity(_ item: PackingItem, by delta: Int) {
        store.mutate(tripID) { trip in
            if let i = trip.items.firstIndex(where: { $0.id == item.id }) {
                let newValue = max(1, trip.items[i].quantity + delta)
                trip.items[i].quantity = newValue
                trip.items[i].wornCount = min(trip.items[i].wornCount, newValue)
            }
        }
    }

    private func remove(_ item: PackingItem) {
        withAnimation {
            store.mutate(tripID) { trip in
                trip.items.removeAll { $0.id == item.id }
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
                    Text(L("Помини ја листата на излез — за да не мислиш на шпоретот на аеродром.",
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

    // MARK: Прогноза — при секое отворање

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
    var onAssign: (UUID?) -> Void = { _ in }
    let onToggle: () -> Void
    let onIncrease: () -> Void
    let onDecrease: () -> Void
    let onDelete: () -> Void

    var body: some View {
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
                    if let assigneeName {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 9))
                            Text(L("носи \(assigneeName)", "\(assigneeName) brings it"))
                                .font(.sans(12, .medium))
                        }
                        .foregroundStyle(Theme.gold)
                    } else if !companions.isEmpty && item.isShareable {
                        Text(L("ЗАЕДНИЧКО", "SHARED"))
                            .font(.sans(9, .semibold))
                            .tracking(1.4)
                            .foregroundStyle(Theme.sage)
                    }
                    if let detail = item.detailText {
                        Text(detail)
                            .font(.sans(12))
                            .foregroundStyle(Theme.muted)
                    }
                }

                Spacer(minLength: 8)

                if item.quantity > 1 {
                    Text("×\(item.quantity)")
                        .font(.codes(17))
                        .foregroundStyle(item.isPacked ? Theme.muted : Theme.navy)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !companions.isEmpty {
                Menu(L("Кој го носи", "Who brings it"), systemImage: "person.2") {
                    Button(L("Јас", "Me"), systemImage: item.assignee == nil ? "checkmark" : "person") { onAssign(nil) }
                    ForEach(companions) { companion in
                        Button(companion.firstName, systemImage: item.assignee == companion.id ? "checkmark" : "person") {
                            onAssign(companion.id)
                        }
                    }
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
            HStack(spacing: 14) {
                Image(systemName: trip.bag.kind.icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Theme.navy)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.bag.displayTitle)
                        .font(.serif(20))
                        .foregroundStyle(Theme.ink)
                    Text(trip.bag.limitText)
                        .font(.sans(13))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
            }

            meter(label: L("Волумен", "Volume"),
                  value: "\(Int(trip.packedVolume.rounded())) / \(Int(trip.bag.usableVolume.rounded())) L",
                  ratio: trip.fillRatio,
                  color: color)

            if let weightRatio = trip.weightRatio, let limit = trip.bag.weightLimit {
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
        }
        .luxCard(padding: 20, radius: 18)
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
    let onAdd: (PackingItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var quantity = 1
    @State private var category: ItemCategory = .accessories
    @State private var didSetup = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Eyebrow(L("Нов предмет", "New item"), color: Theme.gold)
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
