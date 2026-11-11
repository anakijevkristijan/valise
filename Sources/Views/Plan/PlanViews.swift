import SwiftUI

// MARK: - Таб „План“ во патувањето: места по денови

/// Места за посета, сликање, пазарење, каде се јаде и каде се спие - ден по ден, со час и адреса.
/// Без ден = „кога било“ (листа со желби за патувањето).
struct TripPlanSection: View {
    let trip: Trip
    @EnvironmentObject private var store: TripStore
    @State private var editing: Draft?

    struct Draft: Identifiable {
        let id = UUID()
        var place: TripPlace
        var isNew: Bool
    }

    init(trip: Trip) {
        self.trip = trip
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if trip.allPlaces.isEmpty {
                Text(L("Запиши каде сакаш да одиш - музеј, место за сликање, продавница, ресторан, каде спиеш. Сè е по денови, со час и адреса.",
                       "Note where you want to go - a museum, a photo spot, a shop, a restaurant, where you're staying. All by day, with a time and an address."))
                    .font(.sans(14))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(trip.days, id: \.self) { date in
                dayBlock(date)
            }

            anytimeBlock
        }
        .sheet(item: $editing) { draft in
            PlaceEditor(trip: trip, place: draft.place, isNew: draft.isNew,
                        onSave: { place in store.mutate(trip.id) { $0.save(place: place) } },
                        onDelete: { store.mutate(trip.id) { $0.removePlace(draft.place.id) } })
                .presentationCornerRadius(28)
        }
    }

    // MARK: Ден

    private func dayBlock(_ date: Date) -> some View {
        let key = Trip.dayKey(date)
        let places = trip.places(forKey: key)
        let weather = trip.weather.first { Calendar.current.isDate($0.date, inSameDayAs: date) }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Fmt.weekdayShort(date).uppercased())
                    .font(.sans(12, .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.navy)
                Text(Fmt.ticketDate(date))
                    .font(.codes(15))
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                if let weather {
                    Image(systemName: weather.icon)
                        .font(.system(size: 12, weight: .light))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.navy)
                    Text("\(Int(weather.maxTemp.rounded()))°")
                        .font(.codes(14))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .padding(.horizontal, 2)

            placeList(places, dayKey: key)
        }
    }

    private var anytimeBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("КОГА БИЛО", "ANYTIME"))
                    .font(.sans(12, .semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.navy)
                Spacer()
            }
            .padding(.horizontal, 2)

            placeList(trip.unscheduledPlaces, dayKey: nil)
        }
    }

    private func placeList(_ places: [TripPlace], dayKey: String?) -> some View {
        VStack(spacing: 0) {
            ForEach(places) { place in
                PlaceRow(place: place,
                         onOpen: { editing = Draft(place: place, isNew: false) },
                         onToggle: { toggle(place) })
                Hairline().padding(.leading, 64)
            }
            Button {
                editing = Draft(place: TripPlace(kind: .sight, title: "", dayKey: dayKey), isNew: true)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 18)
                    Text(L("Додај место", "Add a place"))
                        .font(.sans(12, .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                    Spacer()
                }
                .foregroundStyle(Theme.gold)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .luxCard(padding: 0, radius: 16)
    }

    private func toggle(_ place: TripPlace) {
        var copy = place
        copy.isDone.toggle()
        withAnimation(.easeInOut(duration: 0.2)) {
            store.mutate(trip.id) { $0.save(place: copy) }
        }
    }
}

/// Едно место: икона за видот, наслов, час и адреса, „бевме“.
private struct PlaceRow: View {
    let place: TripPlace
    let onOpen: () -> Void
    let onToggle: () -> Void

    private var detail: String {
        var parts: [String] = []
        if let time = place.timeText { parts.append(time) }
        parts.append(place.kind.title)
        if let address = place.address, !address.isEmpty { parts.append(address) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    Image(systemName: place.kind.icon)
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(Theme.navy)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.goldPale))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(place.title)
                            .font(.serif(19))
                            .foregroundStyle(place.isDone ? Theme.muted : Theme.ink)
                            .strikethrough(place.isDone, color: Theme.muted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(detail)
                            .font(.sans(12))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggle) {
                Image(systemName: place.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(place.isDone ? Theme.navy : Theme.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Додај / уреди место

struct PlaceEditor: View {
    let trip: Trip
    let isNew: Bool
    let onSave: (TripPlace) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var place: TripPlace
    @State private var address: String
    @State private var note: String
    @State private var hasTime: Bool
    @State private var time: Date
    @FocusState private var titleFocused: Bool

    init(trip: Trip, place: TripPlace, isNew: Bool, onSave: @escaping (TripPlace) -> Void, onDelete: @escaping () -> Void) {
        self.trip = trip
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
        _place = State(initialValue: place)
        _address = State(initialValue: place.address ?? "")
        _note = State(initialValue: place.note ?? "")
        _hasTime = State(initialValue: place.minutes != nil)
        let minutes = place.minutes ?? 10 * 60
        let start = Calendar.current.startOfDay(for: Date())
        _time = State(initialValue: start.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    private var trimmedTitle: String { place.title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Eyebrow(isNew ? L("Ново место", "New place") : L("Место", "Place"), color: Theme.gold)
                        Spacer()
                        CircleIconButton(systemName: "xmark") { dismiss() }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        TextField("", text: $place.title,
                                  prompt: Text(L("пр. Стариот град", "e.g. Old Town")).foregroundColor(Theme.muted.opacity(0.7)))
                            .font(.serif(26))
                            .foregroundStyle(Theme.ink)
                            .submitLabel(.done)
                            .focused($titleFocused)
                        Hairline()
                    }

                    kindPicker
                    dayPicker
                    timePicker

                    field(L("Адреса или кварт", "Address or area"), text: $address,
                          prompt: L("по избор", "optional"))
                    field(L("Белешка", "Note"), text: $note,
                          prompt: L("пр. билети однапред, најдобро на зајдисонце", "e.g. book ahead, best at sunset"))

                    Button(action: save) {
                        Text(isNew ? L("Додај", "Add") : L("Зачувај", "Save"))
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(trimmedTitle.isEmpty)

                    if !trimmedTitle.isEmpty {
                        Button {
                            if let url = current.mapsURL(city: trip.destination.name) { openURL(url) }
                        } label: {
                            Label(L("Отвори во Мапи", "Open in Maps"), systemImage: "map")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    if !isNew {
                        Button {
                            onDelete()
                            dismiss()
                        } label: {
                            Text(L("Избриши", "Delete"))
                                .font(.sans(14, .medium))
                                .foregroundStyle(Theme.terracotta)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
                .containerRelativeFrame(.horizontal)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            if isNew { titleFocused = true }
        }
    }

    // MARK: Делови

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(L("Што е", "What it is"))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(PlaceKind.allCases) { kind in
                    kindChip(kind)
                }
            }
        }
    }

    private func kindChip(_ kind: PlaceKind) -> some View {
        let isOn = place.kind == kind
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { place.kind = kind }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: kind.icon)
                    .font(.system(size: 13, weight: .regular))
                Text(kind.title)
                    .font(.sans(13, isOn ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isOn ? Theme.goldLight : Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(isOn ? Theme.navy : Theme.surface))
            .overlay(Capsule().strokeBorder(isOn ? Theme.navy : Theme.hairline, lineWidth: 0.75))
        }
        .buttonStyle(PressableStyle())
    }

    private var dayPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(L("Кој ден", "Which day"))
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ChipButton(title: L("Кога било", "Anytime"), isSelected: place.dayKey == nil) {
                        withAnimation(.easeInOut(duration: 0.2)) { place.dayKey = nil }
                    }
                    ForEach(trip.days, id: \.self) { date in
                        let key = Trip.dayKey(date)
                        ChipButton(title: "\(Fmt.weekdayShort(date)) \(Fmt.ticketDate(date))", isSelected: place.dayKey == key) {
                            withAnimation(.easeInOut(duration: 0.2)) { place.dayKey = key }
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var timePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $hasTime.animation(.easeInOut(duration: 0.2))) {
                Text(L("Со час", "Set a time"))
                    .font(.sans(15, .medium))
                    .foregroundStyle(Theme.ink)
            }
            .tint(Theme.navy)
            if hasTime {
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
            }
        }
        .luxCard(padding: 18)
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(label)
            TextField("", text: text, prompt: Text(prompt).foregroundColor(Theme.muted.opacity(0.7)), axis: .vertical)
                .font(.sans(16))
                .foregroundStyle(Theme.ink)
                .lineLimit(1...4)
            Hairline()
        }
    }

    // MARK: Зачувај

    /// Местото како што е сега во формата.
    private var current: TripPlace {
        var copy = place
        copy.title = trimmedTitle
        let cleanAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.address = cleanAddress.isEmpty ? nil : cleanAddress
        copy.note = cleanNote.isEmpty ? nil : cleanNote
        if hasTime {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
            copy.minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        } else {
            copy.minutes = nil
        }
        return copy
    }

    private func save() {
        guard !trimmedTitle.isEmpty else { return }
        onSave(current)
        dismiss()
    }
}
