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

// MARK: - Секција во патувањето: аутфит за секој ден

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
        let planned = days.filter { wardrobe.outfit(trip.outfitID(on: $0)) != nil }.count

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(L("Аутфити по денови", "Outfits by day"))
                Spacer()
                Text("\(planned)/\(days.count)")
                    .font(.codes(14))
                    .foregroundStyle(Theme.muted)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(days, id: \.self) { date in
                        Button {
                            pickingDay = PickDay(date: date)
                        } label: {
                            dayCard(date)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)

            if wardrobe.items.isEmpty {
                Text(L("Додај облека во „Гардероба“ и испланирај што ќе носиш секој ден.",
                       "Add clothes in “Wardrobe” and plan what you'll wear each day."))
                    .font(.sans(12))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(item: $pickingDay) { day in
            OutfitPickerSheet(tripID: trip.id, date: day.date)
                .environmentObject(store)
                .environmentObject(wardrobe)
                .presentationCornerRadius(28)
        }
    }

    private func dayCard(_ date: Date) -> some View {
        let key = Trip.dayKey(date)
        let outfit = wardrobe.outfit(trip.outfitID(on: date))
        let weather = trip.weather.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let repeats = outfit.map { chosen in
            wardrobe.items(in: chosen).filter { wardrobe.usage(of: $0.id, in: trip, excluding: key) > 0 }.count
        } ?? 0

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
                if let outfit {
                    OutfitCollage(items: wardrobe.items(in: outfit))
                        .padding(4)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Theme.gold)
                }
            }
            .frame(width: 116, height: 116)

            VStack(alignment: .leading, spacing: 3) {
                Text(outfit?.name ?? L("Избери аутфит", "Pick an outfit"))
                    .font(.sans(12, outfit == nil ? .regular : .medium))
                    .foregroundStyle(outfit == nil ? Theme.muted : Theme.ink)
                    .lineLimit(1)
                if repeats > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 9, weight: .semibold))
                        Text(repeats == 1 ? L("1 повторено", "1 repeat") : L("\(repeats) повторени", "\(repeats) repeats"))
                            .font(.sans(10, .semibold))
                    }
                    .foregroundStyle(Theme.gold)
                }
            }
            .frame(height: 32, alignment: .top)
        }
        .padding(10)
        .frame(width: 136)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75))
    }
}

// MARK: - Избор на аутфит за ден (со порака за повторување)

struct OutfitPickerSheet: View {
    let tripID: UUID
    let date: Date

    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var wardrobe: WardrobeStore
    @Environment(\.dismiss) private var dismiss

    @State private var season: Season?
    @State private var didSetup = false
    @State private var showBuilder = false
    @State private var createdNew = false
    @State private var pending: Outfit?

    private var dayKey: String { Trip.dayKey(date) }

    var body: some View {
        ZStack {
            PaperBackground()
            if let trip = store.trip(tripID) {
                content(trip)
            }
        }
        .onAppear {
            guard !didSetup else { return }
            didSetup = true
            season = store.trip(tripID)?.season
        }
        .sheet(isPresented: $showBuilder, onDismiss: {
            if createdNew { dismiss() }
        }) {
            OutfitBuilderView(startSeason: season, trip: store.trip(tripID), dayKey: dayKey) { outfit in
                createdNew = true
                assign(outfit)
            }
            .environmentObject(wardrobe)
            .presentationCornerRadius(28)
        }
        .alert(L("Веќе облечено", "Already worn"),
               isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
               presenting: pending) { outfit in
            Button(L("Сепак избери", "Choose anyway")) {
                assign(outfit)
                dismiss()
            }
            Button(L("Откажи", "Cancel"), role: .cancel) {}
        } message: { outfit in
            Text(repeatMessage(outfit))
        }
    }

    private func content(_ trip: Trip) -> some View {
        let current = wardrobe.outfit(trip.outfitPlan?[dayKey])
        let weather = trip.weather.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let list = wardrobe.outfits
            .filter { wardrobe.outfitFits($0, season) }
            .sorted { $0.createdAt > $1.createdAt }

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Eyebrow(Fmt.weekdayLong(date), color: Theme.gold)
                    Spacer()
                    CircleIconButton(systemName: "xmark") { dismiss() }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Што ќе облечеш?", "What will you wear?"))
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

                SeasonFilter(season: $season)

                HStack(spacing: 10) {
                    Button {
                        createdNew = false
                        showBuilder = true
                    } label: {
                        Label(L("Нов аутфит", "New outfit"), systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    if current != nil {
                        Button {
                            clear()
                        } label: {
                            Label(L("Отстрани", "Clear"), systemImage: "xmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }

                if list.isEmpty {
                    Text(wardrobe.outfits.isEmpty
                         ? L("Сè уште немаш аутфити. Состави еден од парчињата во гардеробата.",
                             "No outfits yet. Style one from the pieces in your wardrobe.")
                         : L("Нема аутфити за оваа сезона. Избери „Сите“ или состави нов.",
                             "No outfits for this season. Choose “All” or style a new one."))
                        .font(.sans(14))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 18) {
                    ForEach(list) { outfit in
                        Button {
                            choose(outfit, current: current, trip: trip)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                OutfitCard(outfit: outfit)
                                    .overlay(alignment: .topTrailing) {
                                        if current?.id == outfit.id {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Theme.goldLight)
                                                .frame(width: 26, height: 26)
                                                .background(Circle().fill(Theme.navy))
                                                .offset(x: -8, y: 8)
                                        }
                                    }
                                if let note = repeatNote(outfit, trip: trip) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.2.squarepath")
                                            .font(.system(size: 9, weight: .semibold))
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
            .padding(24)
            .containerRelativeFrame(.horizontal)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Повторувања

    private func repeatedItems(_ outfit: Outfit, trip: Trip) -> [(item: WardrobeItem, times: Int)] {
        wardrobe.items(in: outfit).compactMap { item in
            let times = wardrobe.usage(of: item.id, in: trip, excluding: dayKey)
            return times > 0 ? (item: item, times: times) : nil
        }
    }

    private func otherDays(_ outfit: Outfit, trip: Trip) -> [Date] {
        trip.days.filter { Trip.dayKey($0) != dayKey && trip.outfitID(on: $0) == outfit.id }
    }

    private func repeatNote(_ outfit: Outfit, trip: Trip) -> String? {
        let days = otherDays(outfit, trip: trip)
        if !days.isEmpty {
            let dates = days.map(Fmt.ticketDate).joined(separator: ", ")
            return L("Веќе избран: \(dates)", "Already on \(dates)")
        }
        let count = repeatedItems(outfit, trip: trip).count
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
        } else {
            lines.append(L("Ова ти е веќе искористено на патувањето:", "You've already worn this on the trip:"))
            for entry in repeatedItems(outfit, trip: trip) {
                lines.append("• \(entry.item.name) — \(RepeatText.times(entry.times))")
            }
        }
        lines.append("")
        lines.append(L("Повторувањето е сосема во ред — помалку за пакување.", "Repeating is perfectly fine — less to pack."))
        return lines.joined(separator: "\n")
    }

    // MARK: Промени

    private func choose(_ outfit: Outfit, current: Outfit?, trip: Trip) {
        if current?.id == outfit.id {
            dismiss()
            return
        }
        if !otherDays(outfit, trip: trip).isEmpty || !repeatedItems(outfit, trip: trip).isEmpty {
            pending = outfit
        } else {
            assign(outfit)
            dismiss()
        }
    }

    private func assign(_ outfit: Outfit) {
        let key = dayKey
        store.mutate(tripID) { t in
            var plan = t.outfitPlan ?? [:]
            plan[key] = outfit.id
            t.outfitPlan = plan
        }
    }

    private func clear() {
        let key = dayKey
        store.mutate(tripID) { t in
            var plan = t.outfitPlan ?? [:]
            plan.removeValue(forKey: key)
            t.outfitPlan = plan.isEmpty ? nil : plan
        }
        dismiss()
    }
}

// MARK: - Во листата за пакување: облеката од аутфитите

struct OutfitPackingBlock: View {
    let trip: Trip

    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var wardrobe: WardrobeStore

    var body: some View {
        let planned = wardrobe.plannedItems(for: trip)
        let packed = Set(trip.outfitPacked ?? [])

        if !planned.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "hanger")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Theme.gold)
                    Text(L("ОД АУТФИТИТЕ", "FROM YOUR OUTFITS"))
                        .font(.sans(11, .semibold))
                        .tracking(2)
                        .foregroundStyle(Theme.navy)
                    Spacer()
                    Text("\(planned.filter { packed.contains($0.item.id) }.count)/\(planned.count)")
                        .font(.codes(14))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 2)

                VStack(spacing: 0) {
                    ForEach(Array(planned.enumerated()), id: \.element.item.id) { index, entry in
                        row(entry.item, days: entry.days, isPacked: packed.contains(entry.item.id))
                        if index < planned.count - 1 {
                            Hairline().padding(.leading, 82)
                        }
                    }
                }
                .luxCard(padding: 0, fill: Theme.surface, radius: 16)
            }
        }
    }

    private func row(_ item: WardrobeItem, days: Int, isPacked: Bool) -> some View {
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
                    if let image = wardrobe.image(for: item) {
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
                    Text(days == 1
                         ? L("за 1 ден", "for 1 day")
                         : L("за \(Fmt.days(days))", "for \(Fmt.days(days))"))
                        .font(.sans(12))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 4)
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
