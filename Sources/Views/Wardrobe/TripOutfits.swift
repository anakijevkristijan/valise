import SwiftUI

/// „еднаш“, „двапати“, „3 пати“…
enum RepeatText {
    static func times(_ n: Int) -> String {
        if AppLanguage.current == .mk {
            switch n {
            case 1: return "еднаш"
            case 2: return "двапати"
            default: return "\(n) пати"
            }
        }
        switch n {
        case 1: return "once"
        case 2: return "twice"
        default: return "\(n) times"
        }
    }

    /// Кратко за плочка: „веќе еднаш“.
    static func badge(_ n: Int) -> String {
        L("веќе \(times(n))", "worn \(times(n))")
    }
}

// MARK: - Секција во патувањето: аутфити за секој ден

struct TripOutfitsSection: View {
    let trip: Trip

    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var wardrobe: WardrobeStore
    @State private var pickingDay: PickDay?

    struct PickDay: Identifiable {
        let date: Date
        var id: String { Trip.dayKey(date) }
    }

    var body: some View {
        let days = trip.days
        let planned = days.filter { date in trip.outfitIDs(on: date).contains { wardrobe.outfit($0) != nil } }.count
        let wear = wardrobe.wearCounts(for: trip)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(L("Аутфити по денови", "Outfits by day"))
                Spacer()
                Text(L("\(planned)/\(days.count) дена", "\(planned)/\(days.count) days"))
                    .font(.sans(11, .medium))
                    .foregroundStyle(Theme.muted)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(days, id: \.self) { date in
                        Button {
                            pickingDay = PickDay(date: date)
                        } label: {
                            dayCard(date, wear: wear)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)

            if planned > 0 {
                TripClosetSummary(trip: trip)
            } else {
                Text(wardrobe.items.isEmpty
                     ? L("Додај облека во „Гардероба“ и испланирај што ќе носиш секој ден — може и повеќе аутфити во ден.",
                         "Add clothes in “Wardrobe” and plan what you'll wear each day — even several outfits a day.")
                     : L("Допри ден за да додадеш еден или повеќе аутфити.",
                         "Tap a day to add one or more outfits."))
                    .font(.sans(12))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(item: $pickingDay) { day in
            DayOutfitsSheet(tripID: trip.id, date: day.date)
                .environmentObject(store)
                .environmentObject(wardrobe)
                .presentationCornerRadius(28)
        }
    }

    private func dayCard(_ date: Date, wear: [UUID: Int]) -> some View {
        let outfits = trip.outfitIDs(on: date).compactMap { wardrobe.outfit($0) }
        let weather = trip.weather.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let dayPieces = Set(outfits.flatMap(\.itemIDs))
        let repeated = dayPieces.filter { (wear[$0] ?? 0) > 1 }.count

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(Fmt.weekdayShort(date).uppercased())
                    .font(.sans(9, .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.muted)
                Text(Fmt.ticketDate(date))
                    .font(.codes(14))
                    .foregroundStyle(Theme.inkSoft)
                Spacer(minLength: 0)
                if let weather {
                    Image(systemName: weather.icon)
                        .font(.system(size: 11, weight: .light))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.navy)
                    Text("\(Int(weather.maxTemp.rounded()))°")
                        .font(.codes(13))
                        .foregroundStyle(Theme.inkSoft)
                }
            }

            ZStack {
                if let first = outfits.first {
                    if outfits.count > 1 {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.goldPale)
                            .rotationEffect(.degrees(5))
                            .padding(6)
                    }
                    OutfitCollage(items: wardrobe.items(in: first))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface))
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Theme.gold)
                }
            }
            .frame(width: 116, height: 116)
            .overlay(alignment: .topTrailing) {
                if outfits.count > 1 {
                    Text("\(outfits.count)")
                        .font(.sans(11, .bold))
                        .foregroundStyle(Theme.goldLight)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.navy))
                        .offset(x: 4, y: -4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(outfits.isEmpty
                     ? L("Додај аутфит", "Add outfit")
                     : (outfits.count == 1 ? outfits[0].name : PieceText.outfits(outfits.count)))
                    .font(.sans(12, outfits.isEmpty ? .regular : .medium))
                    .foregroundStyle(outfits.isEmpty ? Theme.muted : Theme.ink)
                    .lineLimit(1)
                if repeated > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 9, weight: .bold))
                        Text(repeated == 1 ? L("1 повторено", "1 repeat") : L("\(repeated) повторени", "\(repeated) repeats"))
                            .font(.sans(10, .bold))
                    }
                    .foregroundStyle(Theme.ticketText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.terracotta))
                }
            }
            .frame(height: 38, alignment: .top)
        }
        .padding(10)
        .frame(width: 136)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75))
    }
}

// MARK: - Облека за патувањето: колку парчиња, што се повторува, дали собира

struct TripClosetSummary: View {
    let trip: Trip
    @EnvironmentObject private var wardrobe: WardrobeStore

    var body: some View {
        let load = wardrobe.load(for: trip)
        let planned = wardrobe.plannedItems(for: trip)
        let color = load.level == .over ? Theme.terracotta : (load.level == .tight ? Theme.gold : Theme.sage)

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "hanger")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Theme.gold)
                Text(L("ОБЛЕКА ЗА ПАТУВАЊЕТО", "CLOTHES FOR THIS TRIP"))
                    .font(.sans(11, .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.navy)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(PieceText.pieces(load.pieces))
                    .font(.serif(28))
                    .foregroundStyle(Theme.ink)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(PieceText.outfits(load.outfits))
                        .font(.sans(12, .medium))
                        .foregroundStyle(Theme.inkSoft)
                    Text(load.repeated == 1 ? L("1 се повторува", "1 repeated") : L("\(load.repeated) се повторуваат", "\(load.repeated) repeated"))
                        .font(.sans(12, .medium))
                        .foregroundStyle(load.repeated > 0 ? Theme.gold : Theme.muted)
                }
            }

            let targets = wardrobe.targets(for: trip)
            if !targets.isEmpty {
                TargetChips(targets: targets)
                if let over = TargetText.over(targets) {
                    Label(L("Над планираното: \(over)", "Over the plan: \(over)"), systemImage: "exclamationmark.triangle.fill")
                        .font(.sans(12, .semibold))
                        .foregroundStyle(Theme.terracotta)
                }
            }

            if load.capacity > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(L("Место во куферот", "Room in your bag"))
                            .font(.sans(11, .medium))
                            .foregroundStyle(Theme.muted)
                        Spacer()
                        Text("\(Int(load.packedVolume.rounded())) / \(Int(load.capacity.rounded())) L")
                            .font(.codes(14))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    GaugeBar(ratio: min(load.ratio, 1), color: color, height: 4)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: load.level == .over ? "exclamationmark.triangle" : (load.level == .tight ? "hand.raised" : "checkmark.circle"))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(color)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(load.headline)
                        .font(.sans(13, .semibold))
                        .foregroundStyle(color)
                    Text(load.advice)
                        .font(.sans(13))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if let note = load.travelNote {
                        Text(note)
                            .font(.sans(11))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 10)], spacing: 12) {
                ForEach(planned, id: \.item.id) { entry in
                    VStack(spacing: 4) {
                        Group {
                            if let image = wardrobe.thumbnail(for: entry.item) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Image(systemName: "hanger")
                                    .font(.system(size: 18, weight: .ultraLight))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .frame(width: 50, height: 50)
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(entry.times > 1 ? Theme.goldPale : Theme.stone.opacity(0.5)))
                        .overlay(alignment: .topTrailing) {
                            Text("\(entry.times)×")
                                .font(.sans(10, .bold))
                                .foregroundStyle(entry.times > 1 ? Theme.ticketText : Theme.inkSoft)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(entry.times > 1 ? Theme.gold : Theme.surface))
                                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: entry.times > 1 ? 0 : 0.75))
                                .offset(x: 6, y: -6)
                        }
                        Text(entry.item.name)
                            .font(.sans(10, .medium))
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                    }
                }
            }
        }
        .luxCard(padding: 18)
    }
}

// MARK: - Аутфити за еден ден (повеќе, со порака за повторување)

struct DayOutfitsSheet: View {
    let tripID: UUID
    let date: Date

    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var wardrobe: WardrobeStore
    @Environment(\.dismiss) private var dismiss

    @State private var season: Season?
    @State private var didSetup = false
    @State private var showBuilder = false
    @State private var editing: Outfit?
    @State private var pending: Outfit?
    @State private var toast: String?
    @State private var toastIsWarning = false
    @State private var toastToken = 0

    private var dayKey: String { Trip.dayKey(date) }

    var body: some View {
        ZStack(alignment: .top) {
            PaperBackground()
            if let trip = store.trip(tripID) {
                content(trip)
            }
            if let toast {
                ToastBanner(text: toast, isWarning: toastIsWarning)
                    .padding(.top, 12)
                    .zIndex(2)
            }
        }
        .onAppear {
            guard !didSetup else { return }
            didSetup = true
            season = store.trip(tripID)?.season
        }
        .sheet(isPresented: $showBuilder) {
            OutfitBuilderView(startSeason: season, trip: store.trip(tripID)) { outfit in
                add(outfit)
            }
            .environmentObject(wardrobe)
            .presentationCornerRadius(28)
        }
        .sheet(item: $editing) { outfit in
            OutfitBuilderView(existing: outfit, trip: store.trip(tripID))
                .environmentObject(wardrobe)
                .presentationCornerRadius(28)
        }
        .alert(L("Веќе облечено", "Already worn"),
               isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
               presenting: pending) { outfit in
            Button(L("Сепак додај", "Add anyway")) { add(outfit) }
            Button(L("Откажи", "Cancel"), role: .cancel) {}
        } message: { outfit in
            Text(repeatMessage(outfit))
        }
    }

    private func content(_ trip: Trip) -> some View {
        let todays = trip.outfitIDs(forKey: dayKey).compactMap { wardrobe.outfit($0) }
        let todayIDs = Set(todays.map(\.id))
        let weather = trip.weather.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let available = wardrobe.outfits
            .filter { !todayIDs.contains($0.id) && wardrobe.outfitFits($0, season) }
            .sorted { $0.createdAt > $1.createdAt }

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Eyebrow(Fmt.weekdayLong(date), color: Theme.gold)
                    Spacer()
                    CircleIconButton(systemName: "xmark") { dismiss() }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Аутфити за денот", "Outfits for the day"))
                        .font(.serif(30))
                        .foregroundStyle(Theme.ink)
                    if let weather {
                        HStack(spacing: 8) {
                            Image(systemName: weather.icon)
                                .font(.system(size: 15, weight: .light))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Theme.navy)
                            Text("\(Int(weather.maxTemp.rounded()))° / \(Int(weather.minTemp.rounded()))°")
                                .font(.codes(17))
                                .foregroundStyle(Theme.inkSoft)
                            if weather.isEstimate {
                                Text(L("* лани", "* last year"))
                                    .font(.sans(11))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
                }

                // Веќе избрани за денот
                if todays.isEmpty {
                    Text(L("Сè уште ништо. Додај еден или повеќе — за ден, вечер, плажа…",
                           "Nothing yet. Add one or more — for daytime, evening, the beach…"))
                        .font(.sans(14))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(todays.enumerated()), id: \.element.id) { index, outfit in
                            dayRow(outfit, trip: trip)
                            if index < todays.count - 1 {
                                Hairline().padding(.leading, 94)
                            }
                        }
                    }
                    .luxCard(padding: 0, fill: Theme.surface, radius: 16)
                }

                Button {
                    showBuilder = true
                } label: {
                    Label(L("Состави нов аутфит", "Style a new outfit"), systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                if !wardrobe.outfits.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(L("Додај од твоите аутфити", "Add from your outfits"))
                        SeasonFilter(season: $season)
                    }

                    if available.isEmpty {
                        Text(L("Нема повеќе аутфити за оваа сезона. Избери „Сите“ или состави нов.",
                               "No more outfits for this season. Choose “All” or style a new one."))
                            .font(.sans(13))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 18) {
                        ForEach(available) { outfit in
                            Button {
                                choose(outfit, trip: trip)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    OutfitCard(outfit: outfit)
                                        .overlay(alignment: .topTrailing) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Theme.goldLight)
                                                .frame(width: 26, height: 26)
                                                .background(Circle().fill(Theme.navy))
                                                .offset(x: -8, y: 8)
                                        }
                                    if let note = repeatNote(outfit, trip: trip) {
                                        HStack(alignment: .top, spacing: 4) {
                                            Image(systemName: "arrow.2.squarepath")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.top, 2)
                                            Text(note)
                                                .font(.sans(11, .semibold))
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }
                                        .foregroundStyle(Theme.terracotta)
                                        .padding(.horizontal, 2)
                                    }
                                }
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Text(L("Готово", "Done"))
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 6)
            }
            .padding(24)
            .containerRelativeFrame(.horizontal)
        }
        .scrollIndicators(.hidden)
    }

    private func dayRow(_ outfit: Outfit, trip: Trip) -> some View {
        let wear = wardrobe.wearCounts(for: trip)
        let repeated = wardrobe.items(in: outfit).filter { (wear[$0.id] ?? 0) > 1 }

        return HStack(spacing: 14) {
            Button {
                editing = outfit
            } label: {
                HStack(spacing: 14) {
                    OutfitCollage(items: wardrobe.items(in: outfit))
                        .frame(width: 64, height: 64)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.stone.opacity(0.5)))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(outfit.name)
                            .font(.serif(17))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text(PieceText.pieces(outfit.itemIDs.count))
                            .font(.sans(12))
                            .foregroundStyle(Theme.muted)
                        if !repeated.isEmpty {
                            Text(L("Повторено: ", "Repeated: ") + repeated.map(\.name).joined(separator: ", "))
                                .font(.sans(11, .semibold))
                                .foregroundStyle(Theme.terracotta)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                remove(outfit)
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Theme.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: Повторувања

    private func otherDays(_ outfit: Outfit, trip: Trip) -> [Date] {
        trip.days.filter { Trip.dayKey($0) != dayKey && trip.outfitIDs(on: $0).contains(outfit.id) }
    }

    private func repeatNote(_ outfit: Outfit, trip: Trip) -> String? {
        let days = otherDays(outfit, trip: trip)
        if !days.isEmpty {
            let dates = days.map(Fmt.ticketDate).joined(separator: ", ")
            return L("Веќе избран: \(dates)", "Already on \(dates)")
        }
        let count = wardrobe.repeats(in: outfit, trip: trip).count
        guard count > 0 else { return nil }
        return count == 1
            ? L("1 парче веќе искористено", "1 piece already worn")
            : L("\(count) парчиња веќе искористени", "\(count) pieces already worn")
    }

    private func repeatMessage(_ outfit: Outfit) -> String {
        guard let trip = store.trip(tripID) else { return "" }
        var lines: [String] = []
        let days = otherDays(outfit, trip: trip)
        if !days.isEmpty {
            let dates = days.map(Fmt.ticketDate).joined(separator: ", ")
            lines.append(L("Овој аутфит веќе е избран за \(dates).", "This outfit is already planned for \(dates)."))
            lines.append("")
        }
        let repeats = wardrobe.repeats(in: outfit, trip: trip)
        if !repeats.isEmpty {
            lines.append(L("Ова ти е веќе искористено на патувањето:", "You already wear these on the trip:"))
            for entry in repeats {
                lines.append("• \(entry.item.name) — \(RepeatText.times(entry.times))")
            }
            lines.append("")
        }
        lines.append(L("Повторувањето е сосема во ред — помалку за пакување.", "Repeating is perfectly fine — less to pack."))
        return lines.joined(separator: "\n")
    }

    // MARK: Промени

    private func choose(_ outfit: Outfit, trip: Trip) {
        if !otherDays(outfit, trip: trip).isEmpty || !wardrobe.repeats(in: outfit, trip: trip).isEmpty {
            pending = outfit
        } else {
            add(outfit)
        }
    }

    private func add(_ outfit: Outfit) {
        let key = dayKey
        withAnimation(.easeInOut(duration: 0.25)) {
            store.mutate(tripID) { $0.addOutfit(outfit.id, forKey: key) }
        }
        // Дали сега аутфитите го надминуваат планираното во листата?
        if let trip = store.trip(tripID), let over = TargetText.over(wardrobe.targets(for: trip)) {
            show(L("Додадено, но го надминуваш планираното: \(over).", "Added, but over the plan: \(over)."), warning: true)
        } else {
            show(L("Додадено: \(outfit.name)", "Added: \(outfit.name)"), warning: false)
        }
    }

    private func remove(_ outfit: Outfit) {
        let key = dayKey
        withAnimation(.easeInOut(duration: 0.25)) {
            store.mutate(tripID) { $0.removeOutfit(outfit.id, forKey: key) }
        }
    }

    private func show(_ text: String, warning: Bool) {
        toastToken += 1
        let token = toastToken
        toastIsWarning = warning
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { toast = text }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: warning ? 3_200_000_000 : 2_000_000_000)
            if token == toastToken {
                withAnimation(.easeOut(duration: 0.3)) { toast = nil }
            }
        }
    }
}

// MARK: - Во листата за пакување: облеката од аутфитите (веднаш под „Облека“)

struct OutfitPackingBlock: View {
    let trip: Trip

    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var wardrobe: WardrobeStore
    @State private var pickingDay: TripOutfitsSection.PickDay?

    var body: some View {
        let planned = wardrobe.plannedItems(for: trip)
        let packed = Set(trip.outfitPacked ?? [])

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "hanger")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Theme.gold)
                Text(L("ОБЛЕКА ОД АУТФИТИТЕ", "CLOTHES FROM YOUR OUTFITS"))
                    .font(.sans(11, .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.navy)
                Spacer()
                if !planned.isEmpty {
                    Text("\(planned.filter { packed.contains($0.item.id) }.count)/\(planned.count)")
                        .font(.codes(14))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 2)

            if planned.isEmpty {
                emptyCard
            } else {
                summary(planned)

                VStack(spacing: 0) {
                    ForEach(Array(planned.enumerated()), id: \.element.item.id) { index, entry in
                        row(entry.item, times: entry.times, isPacked: packed.contains(entry.item.id))
                        if index < planned.count - 1 {
                            Hairline().padding(.leading, 82)
                        }
                    }
                }
                .luxCard(padding: 0, fill: Theme.surface, radius: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1)
                )

                let targets = wardrobe.targets(for: trip)
                if !targets.isEmpty {
                    targetsCard(targets)
                }
            }
        }
        .sheet(item: $pickingDay) { day in
            DayOutfitsSheet(tripID: trip.id, date: day.date)
                .environmentObject(store)
                .environmentObject(wardrobe)
                .presentationCornerRadius(28)
        }
    }

    // MARK: Празно

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Тука автоматски се бројат парчињата од аутфитите што ќе ги испланираш по денови.",
                   "Pieces from the outfits you plan for each day are counted here automatically."))
                .font(.sans(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                if let first = trip.days.first { pickingDay = .init(date: first) }
            } label: {
                Label(L("Планирај аутфити", "Plan outfits"), systemImage: "calendar")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .luxCard(padding: 16)
    }

    // MARK: Колку од секоја категорија

    private func summary(_ planned: [(item: WardrobeItem, times: Int)]) -> some View {
        let counts = WardrobeCategory.allCases.compactMap { category -> String? in
            let n = planned.filter { $0.item.category == category }.count
            return n > 0 ? category.count(n) : nil
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text(L("Треба да спакуваш \(PieceText.pieces(planned.count)):", "You need to pack \(PieceText.pieces(planned.count)):"))
                .font(.sans(13, .semibold))
                .foregroundStyle(Theme.ink)
            Text(counts.joined(separator: " · "))
                .font(.sans(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
    }

    // MARK: Листата наспроти аутфитите (секогаш синхронизирано)

    private func targetsCard(_ targets: [ClothingTarget]) -> some View {
        let missing = TargetText.missing(targets)
        return VStack(alignment: .leading, spacing: 10) {
            Text(L("Листата наспроти аутфитите", "The list vs. your outfits"))
                .font(.sans(12, .semibold))
                .foregroundStyle(Theme.ink)
            TargetChips(targets: targets)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: missing == nil ? "checkmark.circle" : "exclamationmark.triangle")
                    .font(.system(size: 12, weight: .regular))
                    .padding(.top, 1)
                Text(missing.map {
                    L("Во аутфитите фалат: \($0). Додај ги во некој аутфит или состави нов.",
                      "Your outfits are missing: \($0). Add them to an outfit or style a new one.")
                } ?? L("Аутфитите го покриваат сè што предлага листата.",
                       "Your outfits cover everything the list suggests."))
                    .font(.sans(12, .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(missing == nil ? Theme.sage : Theme.terracotta)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill((missing == nil ? Theme.sage : Theme.terracotta).opacity(0.07)))
    }

    // MARK: Ред

    private func row(_ item: WardrobeItem, times: Int, isPacked: Bool) -> some View {
        Button {
            toggle(item.id)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(isPacked ? Theme.navy : Color.clear)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(isPacked ? Theme.navy : Theme.muted.opacity(0.6), lineWidth: 1)
                    if isPacked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.goldLight)
                    }
                }
                .frame(width: 18, height: 18)

                Group {
                    if let image = wardrobe.thumbnail(for: item) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "hanger")
                            .font(.system(size: 16, weight: .ultraLight))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .frame(width: 36, height: 36)
                .opacity(isPacked ? 0.5 : 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .strikethrough(isPacked, color: Theme.muted.opacity(0.6))
                        .font(.sans(15))
                        .foregroundStyle(isPacked ? Theme.muted : Theme.ink)
                        .lineLimit(1)
                    Text(L("се облекува \(RepeatText.times(times))", "worn \(RepeatText.times(times))"))
                        .font(.sans(12, times > 1 ? .semibold : .regular))
                        .foregroundStyle(times > 1 ? Theme.gold : Theme.muted)
                }
                Spacer(minLength: 4)
                if times > 1 {
                    Text("\(times)×")
                        .font(.sans(11, .bold))
                        .foregroundStyle(Theme.ticketText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.gold))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            store.mutate(trip.id) { t in
                var packed = t.outfitPacked ?? []
                if let index = packed.firstIndex(of: id) {
                    packed.remove(at: index)
                } else {
                    packed.append(id)
                }
                t.outfitPacked = packed
            }
        }
    }
}
