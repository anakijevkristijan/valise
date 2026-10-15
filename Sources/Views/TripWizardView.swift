import SwiftUI
import UIKit

// MARK: - Нацрт на патувањето

struct TripDraft {
    var origin: Place? = LastOrigin.load()
    var destination: Place?
    var startDate: Date = Date().adding(days: 14).startOfDay
    var endDate: Date = Date().adding(days: 18).startOfDay
    var transport: Transport = .plane
    var airlineID: String = "wizz"
    var bagIndex: Int = 0
    var useCustomBag = false
    var customBag: BagSpec = Airlines.customBag()
    var activities: Set<Activity> = [.walking]
    var style: TravelerStyle = .neutral
    var hasLaundry = false

    var bagOptions: [BagSpec] {
        if transport == .plane {
            return Airlines.find(airlineID)?.bags ?? Airlines.all[0].bags
        }
        return Airlines.groundBags
    }

    var resolvedBag: BagSpec {
        if useCustomBag { return customBag }
        let options = bagOptions
        return options[min(max(bagIndex, 0), options.count - 1)]
    }

    var dayCount: Int {
        let diff = Calendar.current.dateComponents([.day], from: startDate.startOfDay, to: endDate.startOfDay).day ?? 0
        return max(1, diff + 1)
    }
}

// MARK: - Волшебник

struct TripWizardView: View {
    let onCreate: (UUID) -> Void

    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft = TripDraft()
    @State private var step = 0
    @State private var weather: [WeatherDay] = []
    @State private var weatherSource: WeatherSource = .none
    @State private var isLoadingWeather = false
    @State private var weatherKey = ""

    private let stepCount = 5

    var body: some View {
        ZStack {
            LuxBackground()

            VStack(spacing: 0) {
                topBar
                progressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 6)

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        titleBlock
                        stepContent
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 26)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 24)),
                        removal: .opacity
                    ))
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)

                bottomBar
            }
        }
        .sensoryFeedback(.selection, trigger: step)
    }

    // MARK: Лента горе

    private var topBar: some View {
        HStack {
            if step > 0 {
                CircleIconButton(systemName: "chevron.left") { go(to: step - 1) }
            } else {
                CircleIconButton(systemName: "xmark") { dismiss() }
            }
            Spacer()
            Text(String(format: "%02d / %02d", step + 1, stepCount))
                .font(.serif(15))
                .foregroundStyle(Theme.inkSoft)
                .monospacedDigit()
            Spacer()
            if step > 0 {
                CircleIconButton(systemName: "xmark") { dismiss() }
            } else {
                Color.clear.frame(width: 42, height: 42)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<stepCount, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Theme.gold : Theme.ink.opacity(0.08))
                    .frame(height: 3)
            }
        }
        .padding(.top, 12)
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(eyebrow)
            Text(title)
                .font(.serif(34))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(.sans(15))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(3)
        }
    }

    private var eyebrow: String {
        ["Дестинација", "Датуми", "Превоз и багаж", "Стил на патувањето", "Преглед"][step]
    }

    private var title: String {
        switch step {
        case 0: return "Каде патуваш?"
        case 1: return "Кога?"
        case 2: return "Како стигнуваш?"
        case 3: return "Што ќе правиш?"
        default: return "Сè е спремно."
        }
    }

    private var subtitle: String {
        switch step {
        case 0: return "Ќе го проверам времето на дестинацијата и дали ти треба адаптер за струја."
        case 1: return "Од бројот на денови зависи колку облека ти треба."
        case 2: return "Ги знам мерките за рачен багаж — за да не платиш казна на излезот."
        case 3: return "Избери сè што важи. Листата се прилагодува на твојот план."
        default: return "Провери го прегледот и ќе ја составам твојата листа."
        }
    }

    // MARK: Содржина по чекор

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: destinationStep
        case 1: datesStep
        case 2: transportStep
        case 3: activitiesStep
        default: reviewStep
        }
    }

    // Чекор 1
    private var destinationStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            PlaceSearchField(label: "Од", placeholder: "Град на поаѓање", selection: $draft.origin)
            PlaceSearchField(label: "До", placeholder: "Град, држава…", selection: $draft.destination, suggestions: ["Рим", "Париз", "Истанбул", "Барселона", "Виена", "Атина"])
        }
    }

    // Чекор 2
    private var datesStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 0) {
                dateRow(label: "Поаѓање", icon: "airplane.departure", selection: $draft.startDate, from: Date().startOfDay)
                Hairline().padding(.horizontal, 18)
                dateRow(label: "Враќање", icon: "airplane.arrival", selection: $draft.endDate, from: draft.startDate)
            }
            .luxCard(padding: 0)
            .environment(\.locale, Fmt.mk)
            .onChange(of: draft.startDate) { _, newValue in
                if draft.endDate < newValue { draft.endDate = newValue }
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(draft.dayCount)")
                    .font(.serif(64, .light))
                    .foregroundStyle(Theme.goldDeep)
                    .contentTransition(.numericText())
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.dayCount == 1 ? "ден" : "дена")
                        .font(.serif(22))
                        .foregroundStyle(Theme.ink)
                    Text(Fmt.nights(max(0, draft.dayCount - 1)))
                        .font(.sans(14))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .animation(.snappy, value: draft.dayCount)
            .padding(.horizontal, 4)

            Toggle(isOn: $draft.hasLaundry) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ќе имам перална машина")
                        .font(.sans(15, .medium))
                        .foregroundStyle(Theme.ink)
                    Text("Пакуваш облека за најмногу 4 дена и переш.")
                        .font(.sans(13))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .tint(Theme.gold)
            .luxCard(padding: 18)
        }
    }

    private func dateRow(label: String, icon: String, selection: Binding<Date>, from: Date) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.goldDeep)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.goldLight.opacity(0.6)))
            Text(label)
                .font(.sans(16, .medium))
                .foregroundStyle(Theme.ink)
            Spacer()
            DatePicker("", selection: selection, in: from..., displayedComponents: .date)
                .labelsHidden()
                .tint(Theme.goldDeep)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // Чекор 3
    private var transportStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Transport.allCases) { t in
                    SelectTile(icon: t.icon, title: t.title, subtitle: nil, isSelected: draft.transport == t) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            draft.transport = t
                            draft.bagIndex = t == .plane ? 0 : 1
                            draft.useCustomBag = false
                        }
                    }
                }
            }

            if draft.transport == .plane {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow("Авиокомпанија", color: Theme.muted)
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Airlines.all) { airline in
                                ChipButton(title: airline.name, isSelected: draft.airlineID == airline.id) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        draft.airlineID = airline.id
                                        draft.bagIndex = 0
                                        draft.useCustomBag = false
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Eyebrow("Со што пакуваш", color: Theme.muted)
                VStack(spacing: 0) {
                    let options = draft.bagOptions
                    ForEach(Array(options.enumerated()), id: \.offset) { index, bag in
                        BagOptionRow(bag: bag, isSelected: !draft.useCustomBag && draft.bagIndex == index) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                draft.bagIndex = index
                                draft.useCustomBag = false
                            }
                        }
                        Hairline().padding(.leading, 70)
                    }
                    BagOptionRow(bag: draft.customBag, isSelected: draft.useCustomBag) {
                        withAnimation(.easeInOut(duration: 0.2)) { draft.useCustomBag = true }
                    }
                }
                .luxCard(padding: 0)

                if draft.useCustomBag {
                    customBagEditor
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if draft.transport == .plane {
                    if let tip = Airlines.find(draft.airlineID)?.tip {
                        noteRow(icon: "exclamationmark.circle", text: tip)
                    }
                    noteRow(icon: "info.circle", text: "Мерките се информативни (\(Airlines.dataUpdated)). Провери ги на сајтот на авиокомпанијата пред лет.")
                }
            }
        }
    }

    private var customBagEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Мерки на твојот багаж", color: Theme.muted)
            HStack(spacing: 10) {
                numberField("Висина", value: $draft.customBag.height, unit: "cm")
                numberField("Ширина", value: $draft.customBag.width, unit: "cm")
                numberField("Длабочина", value: $draft.customBag.depth, unit: "cm")
            }
            HStack(spacing: 10) {
                numberField("Макс. тежина", value: Binding(
                    get: { draft.customBag.weightLimit ?? 0 },
                    set: { draft.customBag.weightLimit = $0 > 0 ? $0 : nil }
                ), unit: "kg")
                VStack(alignment: .leading, spacing: 6) {
                    Text("Волумен")
                        .font(.sans(11, .medium))
                        .foregroundStyle(Theme.muted)
                    Text("\(Int(draft.customBag.volume.rounded())) L")
                        .font(.serif(20))
                        .foregroundStyle(Theme.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .luxCard(padding: 18)
    }

    private func numberField(_ label: String, value: Binding<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.sans(11, .medium))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 4) {
                TextField("0", value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.serif(20))
                    .foregroundStyle(Theme.ink)
                Text(unit)
                    .font(.sans(12))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.ivory))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75))
        }
        .frame(maxWidth: .infinity)
    }

    private func noteRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Theme.goldDeep)
                .padding(.top, 1)
            Text(text)
                .font(.sans(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    // Чекор 4
    private var activitiesStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Activity.allCases) { activity in
                    SelectTile(icon: activity.icon,
                               title: activity.title,
                               subtitle: activity.subtitle,
                               isSelected: draft.activities.contains(activity)) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if draft.activities.contains(activity) {
                                draft.activities.remove(activity)
                            } else {
                                draft.activities.insert(activity)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Eyebrow("За кого пакуваме", color: Theme.muted)
                HStack(spacing: 8) {
                    ForEach(TravelerStyle.allCases) { style in
                        ChipButton(title: style.title, isSelected: draft.style == style, expand: true) {
                            withAnimation(.easeInOut(duration: 0.2)) { draft.style = style }
                        }
                    }
                }
            }
        }
    }

    // Чекор 5
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 16) {
                if let destination = draft.destination {
                    HStack(alignment: .firstTextBaseline) {
                        Text(destination.name)
                            .font(.serif(32))
                            .foregroundStyle(Theme.ink)
                        Text(destination.flag)
                            .font(.system(size: 24))
                    }
                }
                summaryRow(icon: "mappin.and.ellipse", text: routeText)
                summaryRow(icon: "calendar", text: "\(Fmt.range(draft.startDate, draft.endDate)) · \(Fmt.days(draft.dayCount))")
                summaryRow(icon: draft.transport.icon, text: transportText)
                summaryRow(icon: draft.resolvedBag.kind.icon, text: "\(draft.resolvedBag.title) · \(draft.resolvedBag.limitText)")
                if !draft.activities.isEmpty {
                    summaryRow(icon: "sparkles", text: Activity.allCases.filter { draft.activities.contains($0) }.map(\.title).joined(separator: ", "))
                }
            }
            .luxCard(padding: 22)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow("Време на дестинацијата", color: Theme.muted)
                    Spacer()
                    if !weather.isEmpty {
                        Text(weatherSource.label)
                            .font(.sans(11, .medium))
                            .foregroundStyle(Theme.muted)
                    }
                }
                if isLoadingWeather {
                    HStack(spacing: 12) {
                        ProgressView().tint(Theme.gold)
                        Text("Ја читам прогнозата…")
                            .font(.sans(14))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .luxCard(padding: 18)
                } else if weather.isEmpty {
                    Text("Прогнозата не е достапна во моментов. Ќе додадам работи за секое време, а подоцна ќе ја освежам.")
                        .font(.sans(14))
                        .foregroundStyle(Theme.inkSoft)
                        .luxCard(padding: 18)
                } else {
                    WeatherStrip(days: weather)
                }
            }
        }
        .task(id: reviewWeatherKey) { await loadWeather() }
    }

    private func summaryRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.goldDeep)
                .frame(width: 22)
            Text(text)
                .font(.sans(15))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var routeText: String {
        let to = draft.destination?.name ?? "—"
        if let from = draft.origin?.name { return "\(from) → \(to)" }
        return to
    }

    private var transportText: String {
        if draft.transport == .plane, let airline = Airlines.find(draft.airlineID), airline.id != "other" {
            return "\(draft.transport.title) · \(airline.name)"
        }
        return draft.transport.title
    }

    private var reviewWeatherKey: String {
        guard let d = draft.destination else { return "" }
        return "\(d.id)-\(draft.startDate.timeIntervalSince1970)-\(draft.endDate.timeIntervalSince1970)"
    }

    @MainActor
    private func loadWeather() async {
        guard let destination = draft.destination else { return }
        let key = reviewWeatherKey
        if key == weatherKey && !weather.isEmpty { return }
        isLoadingWeather = true
        let result = await WeatherService.fetchWeather(for: destination, from: draft.startDate, to: draft.endDate)
        weather = result.days
        weatherSource = result.source
        weatherKey = key
        isLoadingWeather = false
    }

    // MARK: Лента долу

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Button(action: next) {
                HStack(spacing: 10) {
                    Text(step == stepCount - 1 ? "Состави ја листата" : "Продолжи")
                    Image(systemName: step == stepCount - 1 ? "sparkles" : "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canContinue || (step == stepCount - 1 && isLoadingWeather))
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.ivory.opacity(0.94).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Hairline() }
    }

    private var canContinue: Bool {
        switch step {
        case 0: return draft.destination != nil
        case 1: return draft.endDate >= draft.startDate
        case 2: return draft.resolvedBag.volume > 0
        default: return true
        }
    }

    private func go(to newStep: Int) {
        hideKeyboard()
        withAnimation(.easeInOut(duration: 0.35)) {
            step = min(max(newStep, 0), stepCount - 1)
        }
    }

    private func next() {
        if step < stepCount - 1 {
            go(to: step + 1)
        } else {
            create()
        }
    }

    private func create() {
        guard let destination = draft.destination else { return }
        var trip = Trip(
            origin: draft.origin,
            destination: destination,
            startDate: draft.startDate.startOfDay,
            endDate: max(draft.endDate, draft.startDate).startOfDay,
            transport: draft.transport,
            airlineID: draft.transport == .plane ? draft.airlineID : nil,
            bag: draft.resolvedBag,
            activities: Activity.allCases.filter { draft.activities.contains($0) },
            style: draft.style,
            hasLaundry: draft.hasLaundry
        )
        trip.weather = weather
        trip.weatherSource = weatherSource
        trip.weatherUpdatedAt = weather.isEmpty ? nil : Date()
        trip.tint = store.trips.count % Theme.tints.count
        trip.items = PackingEngine.generate(for: trip)
        trip.exitChecklist = PackingEngine.defaultExitChecklist()

        LastOrigin.save(draft.origin)
        store.add(trip)
        onCreate(trip.id)
        dismiss()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Пребарување место

struct PlaceSearchField: View {
    let label: String
    let placeholder: String
    @Binding var selection: Place?
    var suggestions: [String] = []

    @State private var query = ""
    @State private var results: [Place] = []
    @State private var isSearching = false
    @State private var isEditing = false
    @FocusState private var focused: Bool

    private var showsField: Bool { selection == nil || isEditing }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Text(label.uppercased())
                        .font(.sans(11, .semibold))
                        .tracking(1.6)
                        .foregroundStyle(Theme.gold)
                        .frame(width: 30, alignment: .leading)

                    if showsField {
                        TextField("", text: $query, prompt: Text(placeholder).foregroundColor(Theme.muted.opacity(0.75)))
                            .font(.serif(21))
                            .foregroundStyle(Theme.ink)
                            .focused($focused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .submitLabel(.search)
                        if isSearching {
                            ProgressView().tint(Theme.gold)
                        } else if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.muted.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    } else if let place = selection {
                        Button {
                            isEditing = true
                            query = ""
                            focused = true
                        } label: {
                            HStack(spacing: 12) {
                                Text(place.flag).font(.system(size: 24))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                        .font(.serif(21))
                                        .foregroundStyle(Theme.ink)
                                    if !place.subtitle.isEmpty {
                                        Text(place.subtitle)
                                            .font(.sans(13))
                                            .foregroundStyle(Theme.inkSoft)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "pencil")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.muted)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)

                if showsField && !results.isEmpty {
                    Hairline()
                    ForEach(results) { place in
                        Button { choose(place) } label: {
                            HStack(spacing: 12) {
                                Text(place.flag).font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                        .font(.sans(16, .medium))
                                        .foregroundStyle(Theme.ink)
                                    Text(place.subtitle)
                                        .font(.sans(13))
                                        .foregroundStyle(Theme.inkSoft)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
            .luxCard(padding: 0)

            if showsField && query.isEmpty && !suggestions.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { s in
                            ChipButton(title: s, isSelected: false) {
                                query = s
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .task(id: query) { await search() }
    }

    private func choose(_ place: Place) {
        withAnimation(.easeInOut(duration: 0.25)) {
            selection = place
            isEditing = false
            results = []
            query = ""
        }
        focused = false
    }

    @MainActor
    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else {
            results = []
            isSearching = false
            return
        }
        try? await Task.sleep(nanoseconds: 350_000_000)
        if Task.isCancelled { return }
        isSearching = true
        let found = (try? await WeatherService.searchPlaces(q)) ?? []
        if Task.isCancelled { return }
        withAnimation(.easeInOut(duration: 0.2)) { results = found }
        isSearching = false
    }
}

// MARK: - Мали компоненти

struct SelectTile: View {
    let icon: String
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(isSelected ? Theme.ivory : Theme.goldDeep)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(isSelected ? Theme.gold : Theme.goldLight.opacity(0.55)))
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? Theme.gold : Theme.hairline)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.serif(18))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let subtitle {
                        Text(subtitle)
                            .font(.sans(12))
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? Theme.goldLight.opacity(0.45) : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? Theme.gold : Theme.hairline, lineWidth: isSelected ? 1.2 : 0.75)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

struct ChipButton: View {
    let title: String
    let isSelected: Bool
    var expand: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.sans(14, isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Theme.ivory : Theme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: expand ? .infinity : nil)
                .background(Capsule().fill(isSelected ? Theme.ink : Theme.surface))
                .overlay(Capsule().strokeBorder(isSelected ? Theme.ink : Theme.hairline, lineWidth: 0.75))
        }
        .buttonStyle(PressableStyle())
    }
}

struct BagOptionRow: View {
    let bag: BagSpec
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: bag.kind.icon)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.goldDeep)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.goldLight.opacity(0.55)))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(bag.title)
                            .font(.sans(16, .medium))
                            .foregroundStyle(Theme.ink)
                        if bag.isFree {
                            Text("БЕСПЛАТНО")
                                .font(.sans(9, .bold))
                                .tracking(1)
                                .foregroundStyle(Theme.sage)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Theme.sage.opacity(0.12)))
                        }
                    }
                    Text(bag.kind == .custom ? (bag.detail ?? "") : bag.limitText)
                        .font(.sans(13))
                        .foregroundStyle(Theme.inkSoft)
                    if bag.kind != .custom, let detail = bag.detail {
                        Text(detail)
                            .font(.sans(12))
                            .foregroundStyle(Theme.muted)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Theme.gold : Theme.hairline, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Theme.gold)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct WeatherStrip: View {
    let days: [WeatherDay]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(days) { day in
                    WeatherDayCell(day: day)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
    }
}

struct WeatherDayCell: View {
    let day: WeatherDay

    var body: some View {
        VStack(spacing: 8) {
            Text(Fmt.weekdayShort(day.date).uppercased())
                .font(.sans(10, .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.muted)
            Text(Fmt.day(day.date))
                .font(.sans(12, .medium))
                .foregroundStyle(Theme.inkSoft)
            Image(systemName: day.icon)
                .font(.system(size: 22))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.goldDeep)
                .frame(height: 26)
            Text("\(Int(day.maxTemp.rounded()))°")
                .font(.serif(19, .medium))
                .foregroundStyle(Theme.ink)
            Text("\(Int(day.minTemp.rounded()))°")
                .font(.sans(13))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 8))
                Text("\(day.rainChance ?? 0)%")
                    .font(.sans(10, .medium))
            }
            .foregroundStyle((day.rainChance ?? 0) >= 40 ? Color(hex: 0x6F8797) : Theme.muted.opacity(0.7))
        }
        .frame(width: 64)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75))
    }
}
