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
    var companions: [Companion] = []

    init() {}

    /// Нацрт од постоечко патување (за уредување).
    init(trip: Trip) {
        origin = trip.origin
        destination = trip.destination
        startDate = trip.startDate.startOfDay
        endDate = trip.endDate.startOfDay
        transport = trip.transport
        airlineID = trip.airlineID ?? "wizz"
        activities = Set(trip.activities)
        style = trip.style
        hasLaundry = trip.hasLaundry
        companions = trip.travelers

        let bag = trip.bag
        if bag.kind == .custom || bag.key == "custom" {
            useCustomBag = true
            customBag = bag
        } else if let index = bagOptions.firstIndex(where: { $0.key != nil && $0.key == bag.key })
                    ?? bagOptions.firstIndex(where: { $0.kind == bag.kind && $0.height == bag.height && $0.width == bag.width && $0.depth == bag.depth }) {
            bagIndex = index
        } else {
            useCustomBag = true
            customBag = bag
        }
    }

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
    let editing: Trip?
    let onCreate: (UUID) -> Void

    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: TripDraft
    @State private var step = 0
    @State private var weather: [WeatherDay]
    @State private var weatherSource: WeatherSource
    @State private var isLoadingWeather = false
    @State private var weatherKey: String
    @State private var companionName = ""
    @FocusState private var companionFocused: Bool

    private let stepCount = 5

    init(editing: Trip? = nil, onCreate: @escaping (UUID) -> Void) {
        self.editing = editing
        self.onCreate = onCreate
        if let trip = editing {
            _draft = State(initialValue: TripDraft(trip: trip))
            _weather = State(initialValue: trip.weather)
            _weatherSource = State(initialValue: trip.weatherSource)
            _weatherKey = State(initialValue: TripWizardView.weatherKey(trip.destination, trip.startDate.startOfDay, trip.endDate.startOfDay))
        } else {
            _draft = State(initialValue: TripDraft())
            _weather = State(initialValue: [])
            _weatherSource = State(initialValue: .none)
            _weatherKey = State(initialValue: "")
        }
    }

    private var isEditing: Bool { editing != nil }

    private static func weatherKey(_ place: Place, _ start: Date, _ end: Date) -> String {
        "\(place.id)-\(start.timeIntervalSince1970)-\(end.timeIntervalSince1970)"
    }

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                topBar
                progressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 6)

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        titleBlock
                        stepContent
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 26)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.horizontal)
                    .id(step)
                    .transition(.opacity)
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
                .font(.codes(17))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            if isEditing {
                Button(action: saveEdits) {
                    Text(L("Зачувај", "Save"))
                        .font(.sans(11, .semibold))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.goldLight)
                        .padding(.horizontal, 16)
                        .frame(height: 42)
                        .background(Capsule().fill(canSave ? Theme.navy : Theme.muted.opacity(0.4)))
                }
                .buttonStyle(PressableStyle())
                .disabled(!canSave)
            } else if step > 0 {
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
                    .fill(i <= step ? Theme.navy : Theme.navy.opacity(0.1))
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .frame(height: 22)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isEditing || i < step { go(to: i) }
                    }
            }
        }
        .padding(.top, 12)
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(eyebrow, color: Theme.gold)
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
        switch step {
        case 0: return L("Дестинација", "Destination")
        case 1: return L("Датуми", "Dates")
        case 2: return L("Превоз и багаж", "Transport and luggage")
        case 3: return L("Стил на патувањето", "Travel style")
        default: return L("Преглед", "Review")
        }
    }

    private var title: String {
        switch step {
        case 0: return L("Каде патуваш?", "Where are you going?")
        case 1: return L("Кога?", "When?")
        case 2: return L("Како стигнуваш?", "How are you getting there?")
        case 3: return L("Што ќе правиш?", "What will you do?")
        default: return isEditing ? L("Провери ги промените.", "Review your changes.") : L("Картата е спремна.", "Your ticket is ready.")
        }
    }

    private var subtitle: String {
        switch step {
        case 0: return isEditing
                    ? L("Допри ја цртата горе за да скокнеш на кој било чекор, или „Зачувај“ кога ќе завршиш.",
                        "Tap the bar above to jump to any step, or “Save” when you're done.")
                    : L("Ќе го проверам времето на дестинацијата и дали ти треба адаптер за струја.",
                        "I'll check the weather at your destination and whether you need a plug adapter.")
        case 1: return L("Допри го денот на поаѓање, па денот на враќање.",
                         "Tap your departure day, then your return day.")
        case 2: return L("Ги знам мерките за рачен багаж — за да не платиш казна на излезот.",
                         "I know the hand-luggage sizes, so you won't pay a fee at the gate.")
        case 3: return L("Избери сè што важи. Листата се прилагодува на твојот план.",
                         "Pick everything that applies. The list adapts to your plans.")
        default: return L("Провери ги деталите и ќе ја составам твојата листа.",
                          "Check the details and I'll put your list together.")
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
            PlaceSearchField(label: L("Од", "From"),
                             placeholder: L("Град на поаѓање", "Departure city"),
                             selection: $draft.origin)
            PlaceSearchField(label: L("До", "To"),
                             placeholder: L("Град, држава…", "City, country…"),
                             selection: $draft.destination,
                             suggestions: AppLanguage.current == .mk
                                ? ["Рим", "Париз", "Истанбул", "Барселона", "Виена", "Атина"]
                                : ["Rome", "Paris", "Istanbul", "Barcelona", "Vienna", "Athens"])
        }
    }

    // Чекор 2
    private var datesStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            DateRangeCalendar(start: $draft.startDate, end: $draft.endDate)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(draft.dayCount)")
                    .font(.codes(68))
                    .foregroundStyle(Theme.navy)
                    .contentTransition(.numericText())
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayWord)
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
                    Text(L("Ќе имам перална машина", "I'll have a washing machine"))
                        .font(.sans(15, .medium))
                        .foregroundStyle(Theme.ink)
                    Text(L("Пакуваш облека за најмногу 4 дена и переш.", "Pack for at most 4 days and wash."))
                        .font(.sans(13))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .tint(Theme.navy)
            .luxCard(padding: 18)
        }
    }

    private var dayWord: String {
        if AppLanguage.current == .mk { return draft.dayCount == 1 ? "ден" : "дена" }
        return draft.dayCount == 1 ? "day" : "days"
    }

    // Чекор 3
    private var transportStep: some View {
        VStack(alignment: .leading, spacing: 26) {
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
                    Eyebrow(L("Авиокомпанија", "Airline"))
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
                Eyebrow(L("Со што пакуваш", "What you're packing in"))
                VStack(spacing: 0) {
                    let options = draft.bagOptions
                    ForEach(Array(options.enumerated()), id: \.offset) { index, bag in
                        BagOptionRow(bag: bag, isSelected: !draft.useCustomBag && draft.bagIndex == index) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                draft.bagIndex = index
                                draft.useCustomBag = false
                            }
                        }
                        Hairline().padding(.leading, 64)
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
                    noteRow(icon: "info.circle", text: L("Мерките се информативни (\(Airlines.dataUpdated)). Провери ги на сајтот на авиокомпанијата пред лет.",
                                                         "Sizes are a guide (\(Airlines.dataUpdated)). Check the airline's website before you fly."))
                }
            }
        }
    }

    private var customBagEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(L("Мерки на твојот багаж", "Your bag's size"))
            HStack(spacing: 10) {
                numberField(L("Висина", "Height"), value: $draft.customBag.height, unit: "cm")
                numberField(L("Ширина", "Width"), value: $draft.customBag.width, unit: "cm")
                numberField(L("Длабочина", "Depth"), value: $draft.customBag.depth, unit: "cm")
            }
            HStack(spacing: 10) {
                numberField(L("Макс. тежина", "Max weight"), value: Binding(
                    get: { draft.customBag.weightLimit ?? 0 },
                    set: { draft.customBag.weightLimit = $0 > 0 ? $0 : nil }
                ), unit: "kg")
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Волумен", "Volume"))
                        .font(.sans(11, .medium))
                        .foregroundStyle(Theme.muted)
                    Text("\(Int(draft.customBag.volume.rounded())) L")
                        .font(.codes(22))
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
                    .font(.codes(20))
                    .foregroundStyle(Theme.ink)
                Text(unit)
                    .font(.sans(12))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.paper))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75))
        }
        .frame(maxWidth: .infinity)
    }

    private func noteRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Theme.gold)
                .padding(.top, 2)
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

            companionsEditor

            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(L("За кого пакуваме", "Who are we packing for"))
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

    private var companionsEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(L("Со кого патуваш", "Who's coming along"))
            HStack(spacing: 10) {
                TextField("", text: $companionName, prompt: Text(L("Име на пријател", "Friend's name")).foregroundColor(Theme.muted.opacity(0.75)))
                    .font(.serif(18))
                    .foregroundStyle(Theme.ink)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($companionFocused)
                    .onSubmit(addCompanion)
                Button(action: addCompanion) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.goldLight)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.navy))
                }
                .buttonStyle(PressableStyle())
                .disabled(companionName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .luxCard(padding: 0, radius: 14)

            if !draft.companions.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(draft.companions) { companion in
                            Button {
                                withAnimation { draft.companions.removeAll { $0.id == companion.id } }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(companion.name)
                                        .font(.sans(13, .medium))
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundStyle(Theme.goldLight)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(Theme.navy))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            Text(L("Заедничките работи (шампон, крема за сонце, адаптер…) можете да ги поделите — тоа што го носи пријател не зафаќа место во твојот багаж.",
                   "Share common items (shampoo, sunscreen, adapter…) — whatever a friend carries doesn't take space in your bag."))
                .font(.sans(12))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func addCompanion() {
        let name = companionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        withAnimation { draft.companions.append(Companion(name: name)) }
        companionName = ""
    }

    // Чекор 5
    private var previewTrip: Trip? {
        guard let destination = draft.destination else { return nil }
        var trip = Trip(origin: draft.origin,
                        destination: destination,
                        startDate: draft.startDate.startOfDay,
                        endDate: max(draft.endDate, draft.startDate).startOfDay,
                        transport: draft.transport,
                        airlineID: draft.transport == .plane ? draft.airlineID : nil,
                        bag: draft.resolvedBag,
                        activities: Activity.allCases.filter { draft.activities.contains($0) },
                        style: draft.style,
                        hasLaundry: draft.hasLaundry)
        trip.weather = weather
        trip.weatherSource = weatherSource
        trip.tint = editing?.tint ?? (store.trips.count % Theme.ticketColors.count)
        trip.companions = draft.companions.isEmpty ? nil : draft.companions
        if let editing { trip.items = editing.items }
        return trip
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let trip = previewTrip {
                BoardingPassCard(trip: trip)
            }

            VStack(alignment: .leading, spacing: 14) {
                summaryRow(icon: draft.transport.icon, text: transportText)
                summaryRow(icon: draft.resolvedBag.kind.icon, text: "\(draft.resolvedBag.displayTitle) · \(draft.resolvedBag.limitText)")
                if !draft.companions.isEmpty {
                    summaryRow(icon: "person.2", text: draft.companions.map(\.name).joined(separator: ", "))
                }
                if !draft.activities.isEmpty {
                    summaryRow(icon: "sparkles", text: Activity.allCases.filter { draft.activities.contains($0) }.map(\.title).joined(separator: ", "))
                }
            }
            .luxCard(padding: 20)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow(L("Време на дестинацијата", "Weather at your destination"))
                    Spacer()
                    if !weather.isEmpty {
                        Text(weatherSource.label)
                            .font(.sans(11, .medium))
                            .foregroundStyle(Theme.muted)
                    }
                }
                if isLoadingWeather {
                    HStack(spacing: 12) {
                        ProgressView().tint(Theme.navy)
                        Text(L("Ја читам прогнозата…", "Reading the forecast…"))
                            .font(.sans(14))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .luxCard(padding: 18)
                } else if weather.isEmpty {
                    Text(L("Прогнозата не е достапна во моментов. Ќе додадам работи за секое време, а подоцна ќе ја освежам.",
                           "The forecast isn't available right now. I'll pack for any weather and refresh it later."))
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
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Theme.gold)
                .frame(width: 22)
            Text(text)
                .font(.sans(15))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var transportText: String {
        if draft.transport == .plane, let airline = Airlines.find(draft.airlineID), airline.id != "other" {
            return "\(draft.transport.title) · \(airline.name)"
        }
        return draft.transport.title
    }

    private var reviewWeatherKey: String {
        guard let d = draft.destination else { return "" }
        return TripWizardView.weatherKey(d, draft.startDate.startOfDay, draft.endDate.startOfDay)
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
                    Text(step == stepCount - 1
                         ? (isEditing ? L("Зачувај промени", "Save changes") : L("Состави ја листата", "Build my list"))
                         : L("Продолжи", "Continue"))
                    Image(systemName: step == stepCount - 1 ? "sparkles" : "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
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
        .background(Theme.paper.opacity(0.96).ignoresSafeArea(edges: .bottom))
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
        } else if isEditing {
            saveEdits()
        } else {
            create()
        }
    }

    private var canSave: Bool {
        draft.destination != nil && draft.endDate >= draft.startDate && draft.resolvedBag.volume > 0
    }

    /// Ги зачувува промените, без да се губи спакуваното, сопатниците и рачно додаденото.
    private func saveEdits() {
        guard let original = editing, canSave, var updated = previewTrip else { return }
        updated.id = original.id
        updated.tint = original.tint
        updated.createdAt = original.createdAt
        updated.exitChecklist = original.exitChecklist
        updated.dismissedSuggestions = original.dismissedSuggestions

        let sameBasis = original.destination.id == updated.destination.id
            && original.startDate.startOfDay == updated.startDate
            && original.endDate.startOfDay == updated.endDate
        if !weather.isEmpty && weatherKey == reviewWeatherKey {
            updated.weather = weather
            updated.weatherSource = weatherSource
            updated.weatherUpdatedAt = sameBasis ? original.weatherUpdatedAt : Date()
        } else if sameBasis {
            updated.weather = original.weather
            updated.weatherSource = original.weatherSource
            updated.weatherUpdatedAt = original.weatherUpdatedAt
        } else {
            updated.weather = []
            updated.weatherSource = .none
            updated.weatherUpdatedAt = nil
        }

        let validCompanions = Set(updated.travelers.map(\.id))
        updated.items = original.items.map { item in
            var copy = item
            if let who = copy.assignee, !validCompanions.contains(who) { copy.assignee = nil }
            return copy
        }
        updated.items = PackingEngine.regenerate(updated)

        let finalTrip = updated
        store.mutate(original.id) { $0 = finalTrip }
        if updated.weather.isEmpty {
            Task { await store.refreshWeather(original.id, force: true) }
        }
        dismiss()
    }

    private func create() {
        guard var trip = previewTrip else { return }
        trip.weatherUpdatedAt = weather.isEmpty ? nil : Date()
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
                        .font(.sans(10, .semibold))
                        .tracking(1.8)
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
                            ProgressView().tint(Theme.navy)
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
                                Text(place.code)
                                    .font(.codes(22))
                                    .foregroundStyle(Theme.navy)
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
                                Text(place.flag).font(.system(size: 18))
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
                                Text(place.code)
                                    .font(.codes(16))
                                    .foregroundStyle(Theme.muted)
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
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(isSelected ? Theme.goldLight : Theme.navy)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark" : "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.goldLight : Theme.muted)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.serif(18))
                        .foregroundStyle(isSelected ? Theme.ticketText : Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let subtitle {
                        Text(subtitle)
                            .font(.sans(12))
                            .foregroundStyle(isSelected ? Theme.ticketText.opacity(0.7) : Theme.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Theme.navy : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Theme.navy : Theme.hairline, lineWidth: 0.75)
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
                .font(.sans(13, isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Theme.goldLight : Theme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: expand ? .infinity : nil)
                .background(Capsule().fill(isSelected ? Theme.navy : Theme.surface))
                .overlay(Capsule().strokeBorder(isSelected ? Theme.navy : Theme.hairline, lineWidth: 0.75))
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
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Theme.navy)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(bag.displayTitle)
                            .font(.sans(15, .medium))
                            .foregroundStyle(Theme.ink)
                        if bag.isFree {
                            Text(L("БЕСПЛАТНО", "FREE"))
                                .font(.sans(9, .bold))
                                .tracking(1.2)
                                .foregroundStyle(Theme.sage)
                        }
                    }
                    Text(bag.kind == .custom ? (bag.displayDetail ?? "") : bag.limitText)
                        .font(.sans(13))
                        .foregroundStyle(Theme.inkSoft)
                    if bag.kind != .custom, let detail = bag.displayDetail {
                        Text(detail)
                            .font(.sans(12))
                            .foregroundStyle(Theme.muted)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Theme.navy : Theme.hairline, lineWidth: 1.2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Theme.navy)
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

// MARK: - Време

struct WeatherStrip: View {
    let days: [WeatherDay]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(days) { day in
                        WeatherDayCell(day: day)
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)

            if days.contains(where: \.isEstimate) {
                HStack(alignment: .top, spacing: 4) {
                    Text("*")
                        .font(.codes(14))
                        .foregroundStyle(Theme.gold)
                    Text(L("Истиот ден лани. Се заменува со вистинска прогноза 16 дена пред денот.",
                           "Same day last year. Replaced by the real forecast 16 days ahead."))
                        .font(.sans(12))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

struct WeatherDayCell: View {
    let day: WeatherDay

    var body: some View {
        VStack(spacing: 7) {
            Text(Fmt.weekdayShort(day.date).uppercased())
                .font(.sans(9, .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.muted)
            HStack(spacing: 1) {
                Text(Fmt.day(day.date))
                    .font(.codes(15))
                    .foregroundStyle(Theme.inkSoft)
                if day.isEstimate {
                    Text("*")
                        .font(.codes(15))
                        .foregroundStyle(Theme.gold)
                }
            }
            Image(systemName: day.icon)
                .font(.system(size: 19, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.navy)
                .frame(height: 24)
            Text("\(Int(day.maxTemp.rounded()))°")
                .font(.codes(20))
                .foregroundStyle(Theme.ink)
            Text("\(Int(day.minTemp.rounded()))°")
                .font(.codes(14))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 7))
                Text("\(day.rainChance ?? 0)%")
                    .font(.sans(9, .medium))
            }
            .foregroundStyle((day.rainChance ?? 0) >= 40 ? Theme.rain : Theme.muted.opacity(0.7))
        }
        .frame(width: 58)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(day.isEstimate ? Theme.paper : Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 0.75, dash: day.isEstimate ? [3, 3] : []))
        )
    }
}
