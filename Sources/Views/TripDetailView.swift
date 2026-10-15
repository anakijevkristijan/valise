import SwiftUI

struct TripDetailView: View {
    let tripID: UUID

    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""

    enum Tab: String, CaseIterable { case packing, exit }

    @State private var tab: Tab = .packing
    @State private var addItemCategory: ItemCategory?
    @State private var showAddExit = false
    @State private var newExitTitle = ""
    @State private var confirmDelete = false
    @State private var confirmRegenerate = false
    @State private var isRefreshing = false

    var body: some View {
        Group {
            if let trip = store.trip(tripID) {
                content(trip)
            } else {
                LuxBackground()
                    .onAppear { dismiss() }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await autoRefresh() }
    }

    // MARK: Распоред

    private func content(_ trip: Trip) -> some View {
        ZStack {
            LuxBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    topBar(trip)
                    hero(trip)
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
            .refreshable { await refreshWeather() }
        }
        .sensoryFeedback(.selection, trigger: trip.packedCount)
        .sensoryFeedback(.success, trigger: trip.items.count > 0 && trip.packedCount == trip.items.count)
        .sheet(item: $addItemCategory) { category in
            AddItemSheet(initialCategory: category) { item in
                store.mutate(tripID) { $0.items.append(item) }
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(30)
        }
        .alert("Нова ставка", isPresented: $showAddExit) {
            TextField("пр. Исклучен рутер", text: $newExitTitle)
            Button("Додај") {
                let title = newExitTitle.trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    store.mutate(tripID) { $0.exitChecklist.append(ChecklistItem(title: title, icon: "checkmark.circle")) }
                }
                newExitTitle = ""
            }
            Button("Откажи", role: .cancel) { newExitTitle = "" }
        }
        .confirmationDialog("Да се избрише патувањето?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Избриши", role: .destructive) {
                store.delete(tripID)
                dismiss()
            }
        } message: {
            Text("Листата и сите белешки ќе се изгубат.")
        }
        .confirmationDialog("Нова листа?", isPresented: $confirmRegenerate, titleVisibility: .visible) {
            Button("Состави повторно") {
                withAnimation {
                    store.mutate(tripID) {
                        $0.items = PackingEngine.regenerate($0)
                        $0.dismissedSuggestions = []
                    }
                }
            }
        } message: {
            Text("Листата ќе се состави одново според последната прогноза. Спакуваното и рачно додаденото остануваат.")
        }
    }

    private func topBar(_ trip: Trip) -> some View {
        HStack(spacing: 10) {
            CircleIconButton(systemName: "chevron.left") { dismiss() }
            Spacer()
            ShareLink(item: trip.shareText) {
                CircleIcon(systemName: "square.and.arrow.up")
            }
            Menu {
                Button("Освежи прогноза", systemImage: "arrow.clockwise") {
                    Task { await refreshWeather() }
                }
                Button("Состави ја листата одново", systemImage: "wand.and.stars") {
                    confirmRegenerate = true
                }
                Divider()
                Button("Избриши патување", systemImage: "trash", role: .destructive) {
                    confirmDelete = true
                }
            } label: {
                CircleIcon(systemName: "ellipsis")
            }
        }
        .padding(.top, 8)
    }

    // MARK: Херој

    private func hero(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow("\(trip.destination.flag)  \(trip.destination.country)", color: Theme.goldDeep)
                Spacer()
                Pill(text: trip.countdownText, icon: "calendar")
            }

            Text(trip.destination.name)
                .font(.serif(48))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .padding(.top, 26)

            Text(trip.routeText)
                .font(.sans(15, .medium))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 6)

            Hairline().padding(.vertical, 18)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Fmt.range(trip.startDate, trip.endDate))
                        .font(.serif(19))
                        .foregroundStyle(Theme.ink)
                    Text(heroDetail(trip))
                        .font(.sans(13))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                ProgressRing(progress: trip.progress, size: 62)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(colors: [Theme.tint(trip.tint), Theme.surface],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 0.75)
        )
        .shadow(color: Theme.ink.opacity(0.06), radius: 26, x: 0, y: 14)
    }

    private func heroDetail(_ trip: Trip) -> String {
        var parts = [Fmt.days(trip.dayCount), Fmt.nights(trip.nightCount), trip.transport.title]
        if let airline = trip.airline, airline.id != "other" { parts.append(airline.name) }
        return parts.joined(separator: " · ")
    }

    // MARK: Време

    private func weatherSection(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow("Време", color: Theme.muted)
                Spacer()
                if isRefreshing {
                    ProgressView().controlSize(.small).tint(Theme.gold)
                } else {
                    Text(trip.weatherSource.label)
                        .font(.sans(11, .medium))
                        .foregroundStyle(Theme.muted)
                }
            }

            if trip.weather.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: "cloud.sun")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Theme.goldDeep)
                    Text(trip.isPast ? "Патувањето заврши." : "Прогнозата не е достапна. Повлечи надолу за да пробаш повторно.")
                        .font(.sans(14))
                        .foregroundStyle(Theme.inkSoft)
                }
                .luxCard(padding: 18)
            } else {
                WeatherStrip(days: trip.weather)
                if trip.weatherSource == .lastYear {
                    Text("Прогнозата се гледа 16 дена однапред. Дотогаш — какво беше времето истите денови лани.")
                        .font(.sans(12))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: Табови

    private func tabPicker(_ trip: Trip) -> some View {
        HStack(spacing: 4) {
            tabButton(.packing, title: "Пакување", count: "\(trip.packedCount)/\(trip.items.count)")
            tabButton(.exit, title: "Пред излез", count: "\(trip.exitChecklist.filter(\.isDone).count)/\(trip.exitChecklist.count)")
        }
        .padding(4)
        .background(Capsule().fill(Theme.sand.opacity(0.7)))
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 0.5))
    }

    private func tabButton(_ value: Tab, title: String, count: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { tab = value }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.sans(14, .semibold))
                Text(count)
                    .font(.sans(12, .medium))
                    .opacity(0.6)
            }
            .foregroundStyle(tab == value ? Theme.ivory : Theme.inkSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Capsule().fill(tab == value ? Theme.ink : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Пакување

    private func packingSection(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(trip.packedCount == trip.items.count && !trip.items.isEmpty ? "Сè е спакувано." : "\(trip.packedCount) од \(trip.items.count) спакувани")
                        .font(.serif(22))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(Int((trip.progress * 100).rounded()))%")
                        .font(.serif(18))
                        .foregroundStyle(Theme.goldDeep)
                }
                GaugeBar(ratio: trip.progress, color: Theme.gold, height: 5)
            }

            let suggestions = PackingEngine.suggestions(for: trip)
            if !suggestions.isEmpty {
                SuggestionsCard(items: suggestions,
                                onAdd: { item in
                                    withAnimation { store.mutate(tripID) { $0.items.append(item) } }
                                },
                                onDismissAll: {
                                    withAnimation {
                                        store.mutate(tripID) { $0.dismissedSuggestions.append(contentsOf: suggestions.map(\.name)) }
                                    }
                                })
            }

            ForEach(ItemCategory.allCases) { category in
                let group = trip.items.filter { $0.category == category }
                if !group.isEmpty {
                    categoryBlock(category, items: group)
                }
            }

            Button {
                addItemCategory = .accessories
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Додај свој предмет")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())

            Text("Допри за спакувано. Држи подолго за количина или бришење.")
                .font(.sans(12))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    private func categoryBlock(_ category: ItemCategory, items: [PackingItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.goldDeep)
                Text(category.title)
                    .font(.serif(21))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(items.filter(\.isPacked).count)/\(items.count)")
                    .font(.sans(12, .medium))
                    .foregroundStyle(Theme.muted)
                    .monospacedDigit()
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    PackingRow(item: item,
                               onToggle: { toggle(item) },
                               onIncrease: { changeQuantity(item, by: 1) },
                               onDecrease: { changeQuantity(item, by: -1) },
                               onDelete: { remove(item) })
                    if index < items.count - 1 {
                        Hairline().padding(.leading, 58)
                    }
                }
                Hairline()
                Button {
                    addItemCategory = category
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 26)
                        Text("Додај")
                            .font(.sans(14, .medium))
                        Spacer()
                    }
                    .foregroundStyle(Theme.goldDeep)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .luxCard(padding: 0, radius: 22)
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
                if !item.isCustom { trip.dismissedSuggestions.append(item.name) }
            }
        }
    }

    // MARK: Излез од дома

    private func exitSection(_ trip: Trip) -> some View {
        let done = trip.exitChecklist.filter(\.isDone).count
        let allDone = !trip.exitChecklist.isEmpty && done == trip.exitChecklist.count

        return VStack(alignment: .leading, spacing: 20) {
            if allDone {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Theme.goldDeep)
                    Text("Спремно за пат.")
                        .font(.serif(28))
                        .foregroundStyle(Theme.ink)
                    Text("Домот е безбеден. Убав пат, \(userName.split(separator: " ").first.map(String.init) ?? userName)!")
                        .font(.sans(15))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .luxCard(padding: 26, fill: Theme.goldLight.opacity(0.45), radius: 26)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Последен круг низ домот")
                        .font(.serif(22))
                        .foregroundStyle(Theme.ink)
                    Text("Помини ја листата на излез — за да не мислиш на шпоретот на аеродром.")
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
                        Hairline().padding(.leading, 66)
                    }
                }
            }
            .luxCard(padding: 0, radius: 22)

            HStack(spacing: 10) {
                Button {
                    showAddExit = true
                } label: {
                    Label("Додај", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    withAnimation {
                        store.mutate(tripID) { t in
                            for i in t.exitChecklist.indices { t.exitChecklist[i].isDone = false }
                        }
                    }
                } label: {
                    Label("Одново", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .sensoryFeedback(.success, trigger: allDone)
    }

    // MARK: Прогноза

    @MainActor
    private func autoRefresh() async {
        guard let trip = store.trip(tripID), store.needsWeatherRefresh(trip) else { return }
        await refreshWeather()
    }

    @MainActor
    private func refreshWeather() async {
        isRefreshing = true
        await store.refreshWeather(tripID)
        isRefreshing = false
    }
}

// MARK: - Ред во листата

struct PackingRow: View {
    let item: PackingItem
    let onToggle: () -> Void
    let onIncrease: () -> Void
    let onDecrease: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(item.isPacked ? Theme.gold : Color.clear)
                    Circle()
                        .strokeBorder(item.isPacked ? Theme.gold : Theme.muted.opacity(0.45), lineWidth: 1.3)
                    if item.isPacked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.surface)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .strikethrough(item.isPacked, color: Theme.muted.opacity(0.6))
                        .font(.sans(16))
                        .foregroundStyle(item.isPacked ? Theme.muted : Theme.ink)
                    if let detail = item.detailText {
                        Text(detail)
                            .font(.sans(12))
                            .foregroundStyle(Theme.muted)
                    }
                }

                Spacer(minLength: 8)

                if item.quantity > 1 {
                    Text("×\(item.quantity)")
                        .font(.serif(17))
                        .foregroundStyle(item.isPacked ? Theme.muted : Theme.goldDeep)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Уште едно", systemImage: "plus", action: onIncrease)
            Button("Едно помалку", systemImage: "minus", action: onDecrease)
            Divider()
            Button("Отстрани", systemImage: "trash", role: .destructive, action: onDelete)
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
                    .font(.system(size: 15))
                    .foregroundStyle(item.isDone ? Theme.surface : Theme.goldDeep)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(item.isDone ? Theme.sage : Theme.goldLight.opacity(0.55)))

                Text(item.title)
                    .font(.sans(15))
                    .foregroundStyle(item.isDone ? Theme.muted : Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isDone ? Theme.sage : Theme.hairline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Отстрани", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Багаж

struct BagFitCard: View {
    let trip: Trip

    var body: some View {
        let level = PackingEngine.fitLevel(for: trip)
        let color: Color = level == .over ? Theme.terracotta : (level == .snug ? Theme.gold : Theme.sage)

        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: trip.bag.kind.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.goldDeep)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Theme.goldLight.opacity(0.6)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.bag.title)
                        .font(.serif(20))
                        .foregroundStyle(Theme.ink)
                    Text(trip.bag.limitText)
                        .font(.sans(13))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
            }

            meter(label: "Волумен",
                  value: "\(Int(trip.packedVolume.rounded())) / \(Int(trip.bag.usableVolume.rounded())) L",
                  ratio: trip.fillRatio,
                  color: color)

            if let weightRatio = trip.weightRatio, let limit = trip.bag.weightLimit {
                meter(label: "Тежина (проценка)",
                      value: "\(Fmt.number((trip.packedWeight * 10).rounded() / 10)) / \(Fmt.number(limit)) kg",
                      ratio: weightRatio,
                      color: weightRatio > 1 ? Theme.terracotta : (weightRatio > 0.9 ? Theme.gold : Theme.sage))
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: level == .over ? "exclamationmark.triangle" : (level == .snug ? "hand.raised" : "checkmark.circle"))
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                    .padding(.top, 1)
                Text(PackingEngine.advice(for: trip))
                    .font(.sans(14))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color.opacity(0.09)))
        }
        .luxCard(padding: 20, radius: 26)
    }

    private func meter(label: String, value: String, ratio: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.sans(13, .medium))
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                Text(value)
                    .font(.serif(16, .medium))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
            }
            GaugeBar(ratio: ratio, color: color, height: 8)
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
                    .foregroundStyle(Theme.goldDeep)
                Text("Предлози според новата прогноза")
                    .font(.sans(14, .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("Отфрли", action: onDismissAll)
                    .font(.sans(13, .medium))
                    .foregroundStyle(Theme.muted)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        Button { onAdd(item) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                Text(item.quantity > 1 ? "\(item.name) ×\(item.quantity)" : item.name)
                                    .font(.sans(13, .medium))
                            }
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Theme.surface))
                            .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.5), lineWidth: 0.75))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
        }
        .luxCard(padding: 16, fill: Theme.goldLight.opacity(0.4), radius: 22)
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
            Theme.ivory.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Eyebrow("Нов предмет")
                        Spacer()
                        CircleIconButton(systemName: "xmark") { dismiss() }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        TextField("", text: $name, prompt: Text("Што да спакуваме?").foregroundColor(Theme.muted.opacity(0.7)))
                            .font(.serif(26))
                            .foregroundStyle(Theme.ink)
                            .focused($focused)
                            .submitLabel(.done)
                            .onSubmit(add)
                        Rectangle()
                            .fill(focused ? Theme.gold : Theme.hairline)
                            .frame(height: 1)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow("Категорија", color: Theme.muted)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                            ForEach(ItemCategory.allCases) { c in
                                ChipButton(title: c.title, isSelected: category == c, expand: true) {
                                    category = c
                                }
                            }
                        }
                    }

                    HStack {
                        Text("Количина")
                            .font(.sans(15, .medium))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        HStack(spacing: 16) {
                            stepButton("minus") { quantity = max(1, quantity - 1) }
                            Text("\(quantity)")
                                .font(.serif(22))
                                .foregroundStyle(Theme.ink)
                                .frame(minWidth: 28)
                                .monospacedDigit()
                            stepButton("plus") { quantity = min(30, quantity + 1) }
                        }
                    }
                    .luxCard(padding: 16)

                    Button(action: add) {
                        Text("Додај во листата")
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.ivory))
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 0.75))
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
