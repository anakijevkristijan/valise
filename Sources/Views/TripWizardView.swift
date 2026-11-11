import SwiftUI
import MapKit
import UIKit

// MARK: - Нацрт на патувањето

/// Уште еден град во патувањето (Premium) - свои датуми и перална.
struct DraftStop: Identifiable {
    let id = UUID()
    var place: Place?
    var startDate: Date
    var endDate: Date
    var hasLaundry = false
}

struct TripDraft {
    var origin: Place? = LastOrigin.load()
    var destination: Place?
    var startDate: Date = Date().adding(days: 14).startOfDay
    var endDate: Date = Date().adding(days: 18).startOfDay
    var transport: Transport = .plane
    var airlineID: String = "wizz"
    /// Колку од секој багаж (клуч → број). Може повеќе багажи.
    var bagCounts: [String: Int] = [:]
    var customCount = 0
    /// Свој багаж (свои мерки) - се памти од последниот пат.
    var customBag: BagSpec = OwnBagMemory.load() ?? Airlines.customBag()
    var activities: Set<Activity> = [.walking]
    var style: TravelerStyle = .neutral
    var hasLaundry = false
    var companions: [Companion] = []
    /// Градовите по првиот (Premium). Првиот е `destination` со `startDate`–`endDate` и `hasLaundry`.
    var extraStops: [DraftStop] = []
    /// Своето име на патувањето (по избор).
    var name = ""
    /// Децата и миленичињата што патуваат (Premium) - од „Моето семејство“.
    var familyIDs: [UUID] = []

    init() {
        resetBags()
    }

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
        name = trip.name ?? ""
        familyIDs = trip.myFamily.map(\.id)
        if trip.isMultiStop, let first = trip.allStops.first {
            destination = first.place
            startDate = first.startDate.startOfDay
            endDate = first.endDate.startOfDay
            hasLaundry = first.hasLaundry
            extraStops = trip.allStops.dropFirst().map {
                DraftStop(place: $0.place, startDate: $0.startDate.startOfDay,
                          endDate: $0.endDate.startOfDay, hasLaundry: $0.hasLaundry)
            }
        }

        let options = bagOptions
        for spec in trip.allBags {
            if spec.kind == .custom || spec.key == "custom" {
                customCount += 1
                customBag = spec
            } else if let key = spec.key, options.contains(where: { $0.key == key }) {
                bagCounts[key, default: 0] += 1
            } else if let match = options.first(where: { $0.kind == spec.kind && $0.height == spec.height
                                                          && $0.width == spec.width && $0.depth == spec.depth }),
                      let key = match.key {
                bagCounts[key, default: 0] += 1
            } else {
                customCount += 1
                customBag = spec
            }
        }
        if bagCounts.isEmpty && customCount == 0 { resetBags() }
    }

    var bagOptions: [BagSpec] {
        if transport == .plane {
            return (Airlines.find(airlineID) ?? Airlines.find("other"))?.bags ?? []
        }
        return Airlines.groundBags
    }

    func count(of spec: BagSpec) -> Int {
        spec.key.flatMap { bagCounts[$0] } ?? 0
    }

    mutating func setCount(_ value: Int, for spec: BagSpec) {
        guard let key = spec.key else { return }
        bagCounts[key] = max(0, value)
    }

    /// По избор на превоз/авиокомпанија: вклучените багажи се избрани однапред.
    mutating func resetBags() {
        bagCounts = [:]
        customCount = 0
        let options = bagOptions
        if transport == .plane {
            let included = options.filter(\.isFree)
            for spec in included.isEmpty ? Array(options.prefix(1)) : included {
                if let key = spec.key { bagCounts[key] = 1 }
            }
        } else if let cabin = options.first(where: { $0.kind == .cabin }), let key = cabin.key {
            bagCounts[key] = 1
        }
    }

    /// Сите избрани багажи (со повторување за бројот).
    var resolvedBags: [BagSpec] {
        var list: [BagSpec] = []
        for spec in bagOptions {
            list += Array(repeating: spec, count: count(of: spec))
        }
        list += Array(repeating: customBag, count: customCount)
        return list
    }

    /// Најголемиот - „главниот“ багаж.
    var primaryBag: BagSpec {
        resolvedBags.max { $0.volume < $1.volume } ?? bagOptions.first ?? customBag
    }

    var totalVolume: Double {
        resolvedBags.reduce(0) { $0 + $1.volume }
    }

    /// „Мала торба + Чекиран куфер ×2 · 96 L“
    var bagsSummary: String {
        var groups: [(title: String, count: Int)] = []
        for spec in resolvedBags {
            let title = spec.displayTitle
            if let index = groups.firstIndex(where: { $0.title == title }) {
                groups[index].count += 1
            } else {
                groups.append((title: title, count: 1))
            }
        }
        let names = groups.map { $0.count > 1 ? "\($0.title) ×\($0.count)" : $0.title }.joined(separator: " + ")
        return "\(names) · \(Int(totalVolume.rounded())) L"
    }

    var dayCount: Int {
        let diff = Calendar.current.dateComponents([.day], from: tripStart, to: tripEnd).day ?? 0
        return max(1, diff + 1)
    }

    // MARK: Повеќе градови

    var isMultiStop: Bool { !extraStops.isEmpty }

    /// Сите градови со избрано место, по датумот на пристигнување.
    var tripStops: [TripStop] {
        guard let destination else { return [] }
        var list = [TripStop(place: destination,
                             startDate: startDate.startOfDay,
                             endDate: max(endDate, startDate).startOfDay,
                             hasLaundry: hasLaundry)]
        for extra in extraStops {
            guard let place = extra.place else { continue }
            list.append(TripStop(place: place,
                                 startDate: extra.startDate.startOfDay,
                                 endDate: max(extra.endDate, extra.startDate).startOfDay,
                                 hasLaundry: extra.hasLaundry))
        }
        return list.enumerated()
            .sorted { $0.element.startDate == $1.element.startDate ? $0.offset < $1.offset : $0.element.startDate < $1.element.startDate }
            .map(\.element)
    }

    var tripStart: Date { tripStops.map(\.startDate).min() ?? startDate.startOfDay }
    var tripEnd: Date { tripStops.map(\.endDate).max() ?? max(endDate, startDate).startOfDay }

    /// Нов град: пристигнуваш кога заминуваш од претходниот.
    mutating func addStop() {
        let arrival = (extraStops.last?.endDate ?? endDate).startOfDay
        extraStops.append(DraftStop(place: nil, startDate: arrival, endDate: arrival.adding(days: 2)))
    }

    var stopsAreComplete: Bool { extraStops.allSatisfy { $0.place != nil } }

    /// Секој град почнува најрано кога заминуваш од претходниот (ист ден е дозволен).
    var datesAreValid: Bool {
        guard endDate >= startDate else { return false }
        var previousEnd = endDate.startOfDay
        for stop in extraStops {
            if stop.endDate < stop.startDate || stop.startDate.startOfDay < previousEnd { return false }
            previousEnd = stop.endDate.startOfDay
        }
        return true
    }

    /// Ако претходниот град сега завршува подоцна, следниот се поместува (со истото траење).
    mutating func chainStops() {
        var previousEnd = max(endDate, startDate).startOfDay
        for index in extraStops.indices {
            let stop = extraStops[index]
            if stop.startDate.startOfDay < previousEnd {
                let length = max(0, Calendar.current.dateComponents([.day], from: stop.startDate.startOfDay,
                                                                    to: stop.endDate.startOfDay).day ?? 0)
                extraStops[index].startDate = previousEnd
                extraStops[index].endDate = previousEnd.adding(days: length)
            }
            previousEnd = max(extraStops[index].endDate, extraStops[index].startDate).startOfDay
        }
    }
}

// MARK: - Волшебник

struct TripWizardView: View {
    let editing: Trip?
    let onCreate: (UUID) -> Void

    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var premium: PremiumStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: TripDraft
    @State private var step = 0
    /// Каде да лизне екранот (полето што се пишува, следниот град…).
    @State private var scrollTarget: String?
    @State private var weather: [WeatherDay]
    @State private var weatherSource: WeatherSource
    @State private var isLoadingWeather = false
    @State private var weatherKey: String
    @State private var companionName = ""
    @FocusState private var companionFocused: Bool
    /// Пријатели од контакти: по креирањето - ако имаат Valise, влегуваат во патувањето; ако немаат - покана.
    @State private var pendingInvites: [PendingInvite] = []
    @State private var contactNote: String?
    @State private var showAirlinePicker = false
    @State private var showCityPaywall = false

    private let stepCount = 5

    /// `startStep` - пр. 2 = директно на превоз и багаж (член што си го бира својот куфер).
    init(editing: Trip? = nil, startStep: Int = 0, onCreate: @escaping (UUID) -> Void) {
        self.editing = editing
        self.onCreate = onCreate
        _step = State(initialValue: startStep)
        if let trip = editing {
            _draft = State(initialValue: TripDraft(trip: trip))
            _weather = State(initialValue: trip.weather)
            _weatherSource = State(initialValue: trip.weatherSource)
            _weatherKey = State(initialValue: trip.weatherBasisKey)
        } else {
            _draft = State(initialValue: TripDraft())
            _weather = State(initialValue: [])
            _weatherSource = State(initialValue: .none)
            _weatherKey = State(initialValue: "")
        }
    }

    private var isEditing: Bool { editing != nil }

    /// Член (не сопственик) на заедничко патување ги менува своите градови и датуми.
    private var editsSharedAsMember: Bool {
        guard let editing else { return false }
        return editing.isCloud && !editing.isMine
    }


    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                topBar
                progressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 6)

                ScrollViewReader { proxy in
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
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollIndicators(.hidden)
                    // Нов чекор = нов ScrollView, секогаш од врвот
                    .id(step)
                    .transition(.opacity)
                    // Екранот го следи она што го пополнуваш (поле над тастатурата, следниот град)
                    .onChange(of: scrollTarget) { _, target in
                        guard let target else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(target, anchor: .top)
                            }
                            scrollTarget = nil
                        }
                    }
                }

                bottomBar
            }
        }
        .sensoryFeedback(.selection, trigger: step)
        .onAppear {
            // Без Premium нема правила на авиокомпании - општи багажи
            if !premium.isPremium && draft.airlineID != "other" && !isEditing {
                draft.airlineID = "other"
                draft.resetBags()
            }
        }
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
        case 0 where editsSharedAsMember:
            return L("Градовите и датумите што ќе ги смениш важат само за тебе - другите си ги задржуваат своите. Тргаш од друго место, доаѓаш подоцна или остануваш подолго? Само смени.",
                     "Cities and dates you change are only yours - everyone else keeps theirs. Leaving from somewhere else, arriving later or staying longer? Just change them.")
        case 1 where editsSharedAsMember:
            return L("Твоите датуми - не мора да се исти како кај другите.",
                     "Your dates - they don't have to match anyone else's.")
        case 0: return isEditing
                    ? L("Допри ја цртата горе за да скокнеш на кој било чекор, или „Зачувај“ кога ќе завршиш.",
                        "Tap the bar above to jump to any step, or “Save” when you're done.")
                    : L("Ќе го проверам времето на дестинацијата и дали ти треба адаптер за струја.",
                        "I'll check the weather at your destination and whether you need a plug adapter.")
        case 1 where draft.isMultiStop:
            return L("За секој град: денот кога пристигнуваш и денот кога заминуваш.",
                     "For each city: the day you arrive and the day you leave.")
        case 1: return L("Допри го денот на поаѓање, па денот на враќање.",
                         "Tap your departure day, then your return day.")
        case 2: return L("Ги знам мерките за рачен багаж - за да не платиш казна на излезот.",
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
                             selection: $draft.origin,
                             onFocus: { scrollTarget = "place-origin" })
                .id("place-origin")
            PlaceSearchField(label: draft.isMultiStop ? L("Прв град", "First stop") : L("До", "To"),
                             placeholder: L("Град, држава…", "City, country…"),
                             selection: $draft.destination,
                             suggestions: AppLanguage.current == .mk
                                ? ["Рим", "Париз", "Истанбул", "Барселона", "Виена", "Атина"]
                                : ["Rome", "Paris", "Istanbul", "Barcelona", "Vienna", "Athens"],
                             onFocus: { scrollTarget = "place-destination" })
                .id("place-destination")

            // Уште градови (Premium): Солун → Лефкада → Миконос
            ForEach($draft.extraStops) { $stop in
                let stopID = stop.id
                HStack(alignment: .top, spacing: 8) {
                    PlaceSearchField(label: L("Потоа", "Then"),
                                     placeholder: L("Следен град", "Next city"),
                                     selection: $stop.place,
                                     autoFocus: true,
                                     onFocus: { scrollTarget = "place-\(stopID)" })
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            draft.extraStops.removeAll { $0.id == stopID }
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 18)
                    .accessibilityLabel(L("Тргни го градот", "Remove city"))
                }
                .id("place-\(stopID)")
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if draft.destination != nil {
                Button {
                    if premium.isPremium {
                        withAnimation(.easeInOut(duration: 0.2)) { draft.addStop() }
                    } else {
                        showCityPaywall = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text(L("Додај уште еден град", "Add another city"))
                            .font(.sans(14, .semibold))
                        if !premium.isPremium {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.gold)
                        }
                        Spacer()
                    }
                    .foregroundStyle(Theme.navy)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.navy.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .sheet(isPresented: $showCityPaywall) {
            PremiumSheet().environmentObject(premium)
        }
    }

    // Чекор 2
    private var datesStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            if draft.isMultiStop {
                // Посебен календар и перална за секој град
                VStack(alignment: .leading, spacing: 12) {
                    cityHeader(draft.destination, number: 1)
                    DateRangeCalendar(start: $draft.startDate, end: $draft.endDate, arriveLeave: true,
                                      onCollapse: { scrollTarget = draft.extraStops.first.map { "city-\($0.id)" } },
                                      onExpand: { scrollTarget = "city-first" })
                    laundryToggle($draft.hasLaundry, city: draft.destination?.name)
                }
                .id("city-first")
                ForEach($draft.extraStops) { $stop in
                    let stopID = stop.id
                    let index = draft.extraStops.firstIndex { $0.id == stopID } ?? 0
                    // Не пред заминувањето од претходниот град
                    let previousEnd = index == 0 ? draft.endDate : draft.extraStops[index - 1].endDate
                    let nextID: UUID? = index + 1 < draft.extraStops.count ? draft.extraStops[index + 1].id : nil
                    VStack(alignment: .leading, spacing: 12) {
                        cityHeader(stop.place, number: index + 2)
                        DateRangeCalendar(start: $stop.startDate, end: $stop.endDate,
                                          earliest: previousEnd, arriveLeave: true,
                                          onCollapse: { scrollTarget = nextID.map { "city-\($0)" } },
                                          onExpand: { scrollTarget = "city-\(stopID)" })
                        laundryToggle($stop.hasLaundry, city: stop.place?.name)
                    }
                    .padding(.top, 10)
                    .id("city-\(stopID)")
                }
            } else {
                DateRangeCalendar(start: $draft.startDate, end: $draft.endDate)
            }

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

            if !draft.isMultiStop {
                laundryToggle($draft.hasLaundry, city: nil)
            }
        }
        // Следниот град секогаш по претходниот: ако првиот сега завршува подоцна, вториот се поместува
        .onAppear { draft.chainStops() }
        .onChange(of: draft.endDate) { _, _ in draft.chainStops() }
        .onChange(of: draft.extraStops.map(\.endDate)) { _, _ in draft.chainStops() }
    }

    private func cityHeader(_ place: Place?, number: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.codes(15))
                .foregroundStyle(Theme.goldLight)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.navy))
            Text(place.map { "\($0.flag)  \($0.name)" } ?? "-")
                .font(.serif(24))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func laundryToggle(_ isOn: Binding<Bool>, city: String?) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(city.map { L("Перална машина во \($0)", "Washing machine in \($0)") }
                     ?? L("Ќе имам перална машина", "I'll have a washing machine"))
                    .font(.sans(15, .medium))
                    .foregroundStyle(Theme.ink)
                Text(city == nil
                     ? L("Пакуваш облека за најмногу 4 дена и переш.", "Pack for at most 4 days and wash.")
                     : L("Таму переш - понатаму ти треба помалку облека.", "You wash there, so you need fewer clothes after."))
                    .font(.sans(13))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .tint(Theme.navy)
        .luxCard(padding: 18)
    }

    private var dayWord: String {
        draft.dayCount == 1 ? L("ден", "day") : L("дена", "days")
    }

    // Чекор 3
    private var transportStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Transport.allCases) { t in
                    SelectTile(icon: t.icon, title: t.title, subtitle: nil, isSelected: draft.transport == t) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            draft.transport = t
                            draft.resetBags()
                        }
                    }
                }
            }

            if draft.transport == .plane && !premium.isPremium {
                PremiumLockRow(icon: "airplane",
                               title: L("Авиокомпанија и правила за багаж", "Airline and baggage rules"),
                               detail: L("Мерки и килограми за 140+ авиокомпании - без казни на аеродром.",
                                         "Sizes and weights for 140+ airlines - no fees at the gate."))
            }

            if draft.transport == .plane && premium.isPremium {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(L("Авиокомпанија", "Airline"))
                    Button {
                        showAirlinePicker = true
                    } label: {
                        let airline = Airlines.find(draft.airlineID)
                        HStack(spacing: 14) {
                            Text(airline?.code ?? "-")
                                .font(.codes(16))
                                .foregroundStyle(Theme.goldLight)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Theme.navy))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(airline?.name ?? L("Избери авиокомпанија", "Choose an airline"))
                                    .font(.sans(16, .semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(L("Пребарај меѓу \(Airlines.all.count - 1) авиокомпании", "Search \(Airlines.all.count - 1) airlines"))
                                    .font(.sans(12))
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.navy)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75))
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(L("Со што пакуваш - може повеќе", "What you're packing in - pick several"))
                VStack(spacing: 0) {
                    let options = draft.bagOptions
                    ForEach(Array(options.enumerated()), id: \.offset) { _, bag in
                        BagCountRow(bag: bag, count: draft.count(of: bag)) { value in
                            withAnimation(.easeInOut(duration: 0.2)) { draft.setCount(value, for: bag) }
                        }
                        Hairline().padding(.leading, 64)
                    }
                    BagCountRow(bag: draft.customBag, count: draft.customCount) { value in
                        withAnimation(.easeInOut(duration: 0.2)) { draft.customCount = max(0, value) }
                    }
                }
                .luxCard(padding: 0)

                if draft.customCount > 0 {
                    customBagEditor
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if draft.resolvedBags.isEmpty {
                    noteRow(icon: "exclamationmark.circle", text: L("Избери барем еден багаж.", "Choose at least one bag."))
                } else {
                    noteRow(icon: "suitcase", text: L("Вкупно: \(draft.bagsSummary)", "Total: \(draft.bagsSummary)"))
                }

                if draft.transport == .plane && premium.isPremium {
                    if let tip = Airlines.find(draft.airlineID)?.tip {
                        noteRow(icon: "exclamationmark.circle", text: tip)
                    }
                    noteRow(icon: "info.circle", text: L("Мерките се информативни (\(Airlines.dataUpdated)). Провери ги на сајтот на авиокомпанијата пред лет.",
                                                         "Sizes are a guide (\(Airlines.dataUpdated)). Check the airline's website before you fly."))
                    if let site = Airlines.find(draft.airlineID)?.website, let url = URL(string: "https://\(site)") {
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 12))
                                Text(site)
                                    .font(.sans(13, .medium))
                            }
                            .foregroundStyle(Theme.navy)
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
        .sheet(isPresented: $showAirlinePicker) {
            AirlinePickerSheet(selectedID: draft.airlineID) { airline in
                withAnimation(.easeInOut(duration: 0.2)) {
                    draft.airlineID = airline.id
                    draft.resetBags()
                }
            }
            .presentationCornerRadius(28)
        }
    }

    private var customBagEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(L("Мерки на твојот багаж", "Your bag's size"))
            HStack(spacing: 8) {
                shapeChip(.suitcase, title: L("Куфер", "Suitcase"))
                shapeChip(.backpack, title: L("Ранец", "Backpack"))
            }
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
            if let check = ownBagCheck {
                ownBagNote(check.result, airline: check.airline)
            }
        }
        .luxCard(padding: 18)
    }

    private func shapeChip(_ shape: BagKind, title: String) -> some View {
        let isOn = draft.customBag.shape == shape
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { draft.customBag.shape = shape }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: shape.icon)
                    .font(.system(size: 13, weight: .regular))
                Text(title)
                    .font(.sans(13, isOn ? .semibold : .medium))
            }
            .foregroundStyle(isOn ? Theme.goldLight : Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(isOn ? Theme.navy : Theme.paper))
            .overlay(Capsule().strokeBorder(isOn ? Theme.navy : Theme.hairline, lineWidth: 0.75))
        }
        .buttonStyle(PressableStyle())
    }

    /// Својот багаж спореден со правилата на избраната авиокомпанија (само за лет, Premium).
    private var ownBagCheck: (result: OwnBagCheck, airline: String)? {
        guard draft.transport == .plane, premium.isPremium, draft.customBag.volume > 0,
              let airline = Airlines.find(draft.airlineID),
              let result = OwnBagCheck.check(draft.customBag, airline: airline) else { return nil }
        return (result, airline.name)
    }

    private func ownBagNote(_ check: OwnBagCheck, airline: String) -> some View {
        let color = check.isWarning ? Theme.terracotta : Theme.sage
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: check.isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle")
                .font(.system(size: 13))
                .padding(.top, 1)
            Text(check.text(airline: airline))
                .font(.sans(13, check.isWarning ? .semibold : .regular))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(color)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.09)))
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

            if premium.isPremium {
                companionsEditor
                FamilyTripPicker(selection: $draft.familyIDs, inTrip: editing?.myFamily ?? [])
            } else {
                PremiumLockRow(icon: "person.2",
                               title: L("Патувај со пријатели", "Travel with friends"),
                               detail: L("Заедничка листа и кој што носи - синхронизирано кај сите.",
                                         "A shared list and who brings what - synced for everyone."))
                PremiumLockRow(icon: "figure.and.child.holdinghands",
                               title: L("Деца и миленичиња", "Kids and pets"),
                               detail: L("Своја листа за секое дете (според возраста) и за миленичето.",
                                         "Their own list for each child (by age) and for your pet."))
            }

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

            Button(action: pickContact) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 16, weight: .light))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Додај од контакти", "Add from contacts"))
                            .font(.sans(14, .semibold))
                        Text(L("Ќе видиш дали веќе има Tripdrobe", "See right away if they're on Tripdrobe"))
                            .font(.sans(12))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                .foregroundStyle(Theme.navy)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())

            if let contactNote {
                Text(contactNote)
                    .font(.sans(12, .medium))
                    .foregroundStyle(Theme.terracotta)
            }

            if !draft.companions.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(draft.companions) { companion in
                            Button {
                                withAnimation {
                                    draft.companions.removeAll { $0.id == companion.id }
                                    pendingInvites.removeAll { $0.id == companion.id }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if let invite = pendingInvites.first(where: { $0.id == companion.id }) {
                                        if let hasApp = invite.hasApp {
                                            Image(systemName: hasApp ? "checkmark.icloud" : "envelope")
                                                .font(.system(size: 11, weight: .semibold))
                                        } else {
                                            ProgressView().controlSize(.mini).tint(Theme.goldLight)
                                        }
                                    } else if companion.hasAccount {
                                        Image(systemName: "checkmark.icloud")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
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

            if !pendingInvites.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label(L("има Tripdrobe - ќе ја гледа истата листа", "on Tripdrobe - will see the same list"),
                          systemImage: "checkmark.icloud")
                    Label(L("уште нема - по креирањето допри го името во патувањето и испрати покана",
                            "not yet - after creating, tap their name in the trip to send an invite"),
                          systemImage: "envelope")
                }
                .font(.sans(12))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            }

            Text(L("Заедничките работи (шампон, крема за сонце, адаптер…) можете да ги поделите - тоа што го носи пријател не зафаќа место во твојот багаж.",
                   "Share common items (shampoo, sunscreen, adapter…) - whatever a friend carries doesn't take space in your bag."))
                .font(.sans(12))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pickContact() {
        contactNote = nil
        ContactPickerPresenter.shared.present { contact in
            guard let contact else { return }
            Task { @MainActor in await addContact(contact) }
        }
    }

    @MainActor
    private func addContact(_ contact: PickedContact) async {
        let phoneKeys = contact.phones.compactMap { PhoneID.normalize($0) }.map { PhoneID.phoneKey($0) }
        let emailKeys = contact.emails.map { PhoneID.emailKey($0) }
        let keys = Array(Set(phoneKeys)) + Array(Set(emailKeys))
        guard !keys.isEmpty else {
            contactNote = L("Контактот нема број или е-пошта.", "This contact has no number or email.")
            return
        }
        let companion = Companion(name: contact.name)
        withAnimation {
            draft.companions.append(companion)
            pendingInvites.append(PendingInvite(id: companion.id, contact: contact, hasApp: nil))
        }
        let uid = await store.cloud?.lookup(keys: keys)
        if let uid, uid == Session.uid {
            withAnimation {
                draft.companions.removeAll { $0.id == companion.id }
                pendingInvites.removeAll { $0.id == companion.id }
            }
            contactNote = L("Тоа си ти 🙂", "That's you 🙂")
            return
        }
        if let index = pendingInvites.firstIndex(where: { $0.id == companion.id }) {
            withAnimation { pendingInvites[index].hasApp = uid != nil }
        }
    }

    /// По зачувувањето: пријателите од контакти се додаваат во патувањето (или добиваат покана).
    private func sendInvites(to tripID: UUID) {
        let invites = pendingInvites
        guard !invites.isEmpty else { return }
        let store = self.store
        Task { @MainActor in
            for invite in invites {
                _ = await store.invite(name: invite.contact.name,
                                       phones: invite.contact.phones,
                                       emails: invite.contact.emails,
                                       to: tripID)
            }
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
        let stops = draft.tripStops
        var trip = Trip(origin: draft.origin,
                        destination: stops.first?.place ?? destination,
                        startDate: draft.tripStart,
                        endDate: draft.tripEnd,
                        transport: draft.transport,
                        airlineID: draft.transport == .plane && premium.isPremium ? draft.airlineID : nil,
                        bag: draft.primaryBag,
                        activities: Activity.allCases.filter { draft.activities.contains($0) },
                        style: draft.style,
                        hasLaundry: stops.contains { $0.hasLaundry })
        trip.stops = stops.count > 1 ? stops : nil
        let typedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.name = typedName.isEmpty ? nil : typedName
        trip.bags = draft.resolvedBags
        trip.weather = weather
        trip.weatherSource = weatherSource
        trip.tint = editing?.tint ?? (store.trips.count % Theme.ticketColors.count)
        let plain = draft.companions.filter { companion in !pendingInvites.contains { $0.id == companion.id } }
        trip.companions = plain.isEmpty ? nil : plain
        if let editing {
            trip.items = editing.items
            trip.together = editing.together
        }
        return trip
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let trip = previewTrip {
                BoardingPassCard(trip: trip)

                // Име на патувањето (по избор)
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(L("Име на патувањето", "Trip name"))
                    TextField("", text: $draft.name,
                              prompt: Text(trip.autoTitle).foregroundColor(Theme.muted.opacity(0.7)))
                        .font(.serif(24))
                        .foregroundStyle(Theme.ink)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                    Hairline()
                    Text(L("По избор. Ако го оставиш празно, ќе пишува „\(trip.autoTitle)“.",
                           "Optional. Leave it empty and it will say “\(trip.autoTitle)”."))
                        .font(.sans(12))
                        .foregroundStyle(Theme.muted)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                if draft.isMultiStop, let trip = previewTrip {
                    summaryRow(icon: "map", text: trip.stopsText)
                }
                summaryRow(icon: draft.transport.icon, text: transportText)
                summaryRow(icon: draft.primaryBag.icon, text: draft.bagsSummary)
                if !draft.companions.isEmpty {
                    summaryRow(icon: "person.2", text: draft.companions.map(\.name).joined(separator: ", "))
                }
                if premium.isPremium && !familyNames.isEmpty {
                    summaryRow(icon: "figure.and.child.holdinghands", text: FamilyText.names(familyNames))
                }
                if !draft.activities.isEmpty {
                    summaryRow(icon: "sparkles", text: Activity.allCases.filter { draft.activities.contains($0) }.map(\.title).joined(separator: ", "))
                }
            }
            .luxCard(padding: 20)

            if !premium.isPremium {
                PremiumLockRow(icon: "cloud.sun",
                               title: L("Прогноза за секој ден", "Forecast for every day"),
                               detail: L("Со Premium листата се прилагодува на времето на дестинацијата.",
                                         "With Premium the list adapts to the weather at your destination."))
            } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow(L("Време на дестинацијата", "Weather at your destination"))
                    Spacer()
                    if !weather.isEmpty {
                        Text(WeatherSource.describe(weather))
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
                    if weather.contains(where: { !$0.isClimate }) { WeatherCreditView() }
                }
            }
            }
        }
        .task(id: reviewWeatherKey) { await loadWeather() }
    }

    /// Имињата на избраните деца и миленичиња.
    private var familyNames: [String] {
        let family = FamilyStore.shared
        return draft.familyIDs.compactMap { id in
            family.member(id)?.name ?? editing?.family?.first { $0.id == id }?.name
        }
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
        if draft.transport == .plane, premium.isPremium, let airline = Airlines.find(draft.airlineID), airline.id != "other" {
            return "\(draft.transport.title) · \(airline.name)"
        }
        return draft.transport.title
    }

    /// Исти градови и датуми = истата прогноза (како `Trip.weatherBasisKey`).
    private var reviewWeatherKey: String {
        draft.tripStops
            .map { "\($0.place.id)-\($0.startDate.startOfDay.timeIntervalSince1970)-\($0.endDate.startOfDay.timeIntervalSince1970)" }
            .joined(separator: "|")
    }

    @MainActor
    private func loadWeather() async {
        let stops = draft.tripStops
        guard premium.isPremium, !stops.isEmpty else { return }
        let key = reviewWeatherKey
        if key == weatherKey && !weather.isEmpty { return }
        isLoadingWeather = true
        let result = await WeatherService.fetchWeather(for: stops)
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
        case 0: return draft.destination != nil && draft.stopsAreComplete
        case 1: return draft.datesAreValid
        case 2: return !draft.resolvedBags.isEmpty && draft.totalVolume > 0
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
        draft.destination != nil && draft.stopsAreComplete && draft.datesAreValid
            && !draft.resolvedBags.isEmpty && draft.totalVolume > 0
    }

    /// Ги зачувува промените, без да се губи спакуваното, сопатниците и рачно додаденото.
    private func saveEdits() {
        guard let original = editing, canSave, var updated = previewTrip else { return }
        updated.id = original.id
        updated.tint = original.tint
        updated.createdAt = original.createdAt
        updated.exitChecklist = original.exitChecklist
        updated.dismissedSuggestions = original.dismissedSuggestions
        updated.outfitPlan = original.outfitPlan
        updated.outfitDays = original.outfitDays
        updated.outfitPacked = original.outfitPacked
        updated.familyOutfitDays = original.familyOutfitDays
        updated.familyOutfitPacked = original.familyOutfitPacked
        updated.places = original.places
        // Багажот и стилот сега се мои (кај заедничко патување - само за мене)
        updated.ownBags = true
        // Член на заедничко патување: сменетите градови и датуми се само мои,
        // а ако не ги менувал - продолжува да ги следи тие на сопственикот
        updated.memberPlans = original.memberPlans
        if original.isCloud && !original.isMine {
            let planChanged = !original.myPlan.sameRoute(as: updated.myPlan)
                || original.transport != updated.transport
                || original.airlineID != updated.airlineID
                || original.hasLaundry != updated.hasLaundry
            updated.ownPlan = (original.ownPlan == true || planChanged) ? true : nil
        }

        // Заедничко патување: мојот запис, сопственикот и членовите остануваат
        updated.ownerUID = original.ownerUID
        if original.isCloud {
            let mine = (original.companions ?? []).filter { $0.uid != nil && $0.uid == Session.uid }
            let others = updated.companions ?? []
            updated.companions = mine + others
            let keptUIDs = Set((updated.companions ?? []).compactMap(\.uid))
            updated.memberUIDs = (original.memberUIDs ?? []).filter { uid in
                uid == original.ownerUID || keptUIDs.contains(uid)
            }
        } else {
            updated.memberUIDs = original.memberUIDs
        }

        let sameBasis = original.weatherBasisKey == updated.weatherBasisKey
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

        let validCompanions = Set((updated.companions ?? []).map(\.id))
        updated.items = original.items
        updated.together = original.together.map { list in
            list.map { item in
                var copy = item
                if let who = copy.assignee, !validCompanions.contains(who) { copy.assignee = nil }
                return copy
            }
        }
        PackingEngine.ensureTogether(&updated)
        PackingEngine.dissolveTogether(&updated)
        PackingEngine.rebuild(&updated)
        // Децата и миленичињата: новите добиваат листа, постоечките ја задржуваат спакуваното
        // Листите што некој ми ги споделил остануваат како што се (ги уредува сопственикот).
        if premium.isPremium {
            let mine = FamilyPacking.family(for: draft.familyIDs, trip: updated, previous: original.family) ?? []
            let all = mine + original.sharedWithMe
            updated.family = all.isEmpty ? nil : all
        } else {
            updated.family = original.family
        }
        updated.pruneFamilyShares()
        if draft.customCount > 0 { OwnBagMemory.save(draft.customBag) }

        let finalTrip = updated
        store.mutate(original.id) { $0 = finalTrip }
        if !updated.weather.contains(where: { !$0.isClimate }) {
            Task { await store.refreshWeather(original.id, force: true) }
        }
        sendInvites(to: original.id)
        dismiss()
    }

    private func create() {
        guard var trip = previewTrip else { return }
        trip.weatherUpdatedAt = weather.contains(where: { !$0.isClimate }) ? Date() : nil
        trip.items = PackingEngine.generate(for: trip)
        PackingEngine.ensureTogether(&trip)
        trip.exitChecklist = PackingEngine.defaultExitChecklist()
        if premium.isPremium {
            trip.family = FamilyPacking.family(for: draft.familyIDs, trip: trip, previous: nil)
        }

        LastOrigin.save(draft.origin)
        if draft.customCount > 0 { OwnBagMemory.save(draft.customBag) }
        store.add(trip)
        sendInvites(to: trip.id)
        onCreate(trip.id)
        dismiss()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Пријател избран од контакти, додека се прави патувањето.
struct PendingInvite: Identifiable {
    let id: UUID
    let contact: PickedContact
    /// nil = се проверува; true = има Valise; false = ќе добие покана
    var hasApp: Bool?
}

// MARK: - Пребарување место

struct PlaceSearchField: View {
    let label: String
    let placeholder: String
    @Binding var selection: Place?
    var suggestions: [String] = []
    /// Ново празно поле (следен град) - тастатурата веднаш се отвора.
    var autoFocus = false
    /// Полето доби фокус - екранот лизга за да е над тастатурата.
    var onFocus: (() -> Void)? = nil

    @StateObject private var completer = PlaceCompleter()
    @State private var query = ""
    /// Open-Meteo резерва (само тест-верзии) кога Apple нема предлог.
    @State private var fallback: [Place] = []
    @State private var resolving: MKLocalSearchCompletion?
    @State private var failed = false
    @State private var isEditing = false
    @FocusState private var focused: Bool

    private var showsField: Bool { selection == nil || isEditing }
    private var hasResults: Bool { !completer.results.isEmpty || !fallback.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Text(label.uppercased())
                        .font(.sans(10, .semibold))
                        .tracking(1.8)
                        .foregroundStyle(Theme.gold)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(minWidth: 40, alignment: .leading)

                    if showsField {
                        TextField("", text: $query, prompt: Text(placeholder).foregroundColor(Theme.muted.opacity(0.75)))
                            .font(.serif(21))
                            .foregroundStyle(Theme.ink)
                            .focused($focused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .submitLabel(.search)
                            .onSubmit {
                                if let first = completer.results.first { pick(first) }
                                else if let first = fallback.first { choose(first) }
                            }
                        if resolving != nil {
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

                if showsField && hasResults {
                    Hairline()
                    VStack(spacing: 0) {
                        ForEach(completer.results, id: \.self) { item in
                            Button { pick(item) } label: {
                                resultRow(icon: Text(Image(systemName: "mappin.circle")),
                                          title: item.title,
                                          subtitle: item.subtitle,
                                          code: CityCode.code(for: item.title),
                                          busy: resolving == item)
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(fallback) { place in
                            Button { choose(place) } label: {
                                resultRow(icon: Text(place.flag),
                                          title: place.name,
                                          subtitle: place.subtitle,
                                          code: place.code,
                                          busy: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if showsField && failed {
                    Text(L("Не можам да го најдам ова место. Пробај повторно.", "Couldn't load this place. Please try again."))
                        .font(.sans(12, .medium))
                        .foregroundStyle(Theme.terracotta)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
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
        .onChange(of: query) { _, newValue in
            failed = false
            completer.update(newValue)
        }
        .onChange(of: focused) { _, isFocused in
            if isFocused { onFocus?() }
        }
        .onAppear {
            guard autoFocus, selection == nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        }
        .task(id: query) { await loadFallback() }
    }

    private func resultRow(icon: Text, title: String, subtitle: String, code: String, busy: Bool) -> some View {
        HStack(spacing: 12) {
            icon
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Theme.gold)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.sans(16, .medium))
                    .foregroundStyle(Theme.ink)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.sans(13))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                }
            }
            Spacer()
            if busy {
                ProgressView().controlSize(.small).tint(Theme.navy)
            } else {
                Text(code)
                    .font(.codes(16))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    /// Предлогот од Apple Maps добива координати дури при избор.
    private func pick(_ item: MKLocalSearchCompletion) {
        guard resolving == nil else { return }
        resolving = item
        Task { @MainActor in
            let place = await WeatherService.resolve(item)
            resolving = nil
            if let place {
                choose(place)
            } else {
                failed = true
            }
        }
    }

    private func choose(_ place: Place) {
        withAnimation(.easeInOut(duration: 0.25)) {
            selection = place
            isEditing = false
            fallback = []
            query = ""
        }
        completer.update("")
        focused = false
    }

    /// Ако Apple нема предлог, во тест-верзиите пробува и со Open-Meteo.
    @MainActor
    private func loadFallback() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 3 else {
            fallback = []
            return
        }
        try? await Task.sleep(nanoseconds: 600_000_000)
        if Task.isCancelled || !completer.results.isEmpty {
            fallback = []
            return
        }
        let found = await WeatherService.searchOpenMeteoIfAllowed(q)
        if Task.isCancelled { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            fallback = completer.results.isEmpty ? found : []
        }
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
                Image(systemName: bag.icon)
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

/// Багаж со бројач: 0 = не е избран; 1–3 = колку парчиња.
struct BagCountRow: View {
    let bag: BagSpec
    let count: Int
    var maxCount: Int = 3
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if count == 0 { onChange(1) }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: bag.icon)
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Theme.navy)
                        .frame(width: 34)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(bag.displayTitle)
                                .font(.sans(15, .medium))
                                .foregroundStyle(Theme.ink)
                            if bag.isFree {
                                Text(L("ВКЛУЧЕНО", "INCLUDED"))
                                    .font(.sans(9, .bold))
                                    .tracking(1.2)
                                    .foregroundStyle(Theme.sage)
                            }
                        }
                        Text(bag.kind == .custom && count == 0 ? (bag.displayDetail ?? "") : bag.limitText)
                            .font(.sans(13))
                            .foregroundStyle(Theme.inkSoft)
                        if bag.kind != .custom, let detail = bag.displayDetail {
                            Text(detail)
                                .font(.sans(12))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if count == 0 {
                Button { onChange(1) } label: {
                    Circle()
                        .strokeBorder(Theme.hairline, lineWidth: 1.2)
                        .frame(width: 26, height: 26)
                        .frame(width: 48, height: 48)      // поголема површина за допир
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Додај \(bag.displayTitle)", "Add \(bag.displayTitle)"))
            } else {
                HStack(spacing: 0) {
                    Button { onChange(count - 1) } label: {
                        Image(systemName: count == 1 ? "xmark" : "minus")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 44, height: 40)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(L("Помалку", "Fewer"))
                    Text("\(count)")
                        .font(.codes(18))
                        .frame(minWidth: 18)
                    Button { onChange(min(maxCount, count + 1)) } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 44, height: 40)
                            .contentShape(Rectangle())
                    }
                    .disabled(count >= maxCount)
                    .opacity(count >= maxCount ? 0.4 : 1)
                    .accessibilityLabel(L("Повеќе", "More"))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.goldLight)
                .background(Capsule().fill(Theme.navy))
                .sensoryFeedback(.selection, trigger: count)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
    }
}

/// Пребарување авиокомпанија: популарни горе, па по региони; име, IATA код или земја.
struct AirlinePickerSheet: View {
    let selectedID: String
    let onSelect: (Airline) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    if selectedID.hasPrefix(Airlines.namedPrefix), let mine = Airlines.find(selectedID) {
                        Section(L("Избрана", "Selected")) { row(mine) }
                    }
                    Section(L("Популарни", "Popular")) {
                        ForEach(Airlines.popular) { row($0) }
                    }
                    ForEach(AirlineRegion.allCases) { region in
                        let list = Airlines.all.filter { $0.region == region && $0.id != "other" }
                        if !list.isEmpty {
                            Section(region.title) {
                                ForEach(list) { row($0) }
                            }
                        }
                    }
                    if let other = Airlines.find("other") {
                        Section { row(other) }
                    }
                } else {
                    let results = Airlines.search(query)
                    if results.isEmpty {
                        Text(L("Ја немаме во листата. Додај ја по име - ќе ставам најчести мерки - или избери „Друга“.",
                               "It isn't in our list. Add it by name - I'll use the most common sizes - or choose “Other”."))
                            .font(.sans(14))
                            .foregroundStyle(Theme.muted)
                            .listRowBackground(Theme.surface)
                    } else {
                        ForEach(results) { row($0) }
                    }
                    if let typed = typedAirline(results) {
                        Section {
                            row(typed, label: L("Додај „\(typed.name)“", "Add “\(typed.name)”"))
                        } footer: {
                            Text(L("Ако твојата авиокомпанија ја нема, внеси го целото име. Мерките ќе бидат најчестите - провери ги на нејзиниот сајт.",
                                   "If your airline isn't listed, type its full name. You'll get the most common sizes - check them on its website."))
                                .font(.sans(12))
                        }
                    }
                    if results.isEmpty, let other = Airlines.find("other") {
                        Section { row(other) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: L("Име, код (W6) или земја", "Name, code (W6) or country"))
            .autocorrectionDisabled()
            .navigationTitle(L("Авиокомпанија", "Airline"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Затвори", "Close")) { dismiss() }
                }
            }
        }
    }

    /// Внесеното име како авиокомпанија, ако не е веќе точно во резултатите.
    private func typedAirline(_ results: [Airline]) -> Airline? {
        guard let id = Airlines.namedID(query), let airline = Airlines.find(id) else { return nil }
        let typed = Airlines.fold(airline.name)
        if results.contains(where: { Airlines.fold($0.name) == typed || Airlines.fold($0.code) == typed }) { return nil }
        return airline
    }

    private func row(_ airline: Airline, label: String? = nil) -> some View {
        Button {
            onSelect(airline)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text(airline.code)
                    .font(.codes(14))
                    .foregroundStyle(Theme.goldLight)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.navy))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label ?? airline.name)
                        .font(.sans(15, .medium))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle(airline))
                        .font(.sans(12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer()
                if airline.id == selectedID {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.navy)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.surface)
    }

    private func subtitle(_ airline: Airline) -> String {
        var parts: [String] = []
        if !airline.country.isEmpty { parts.append(airline.countryName) }
        if airline.isLowCost { parts.append(L("нискобуџетна", "low-cost")) }
        if let cabin = airline.bags.first(where: { $0.kind == .cabin }) {
            parts.append(L("кабински \(cabin.dimensionText)", "cabin \(cabin.dimensionText)"))
        }
        if airline.isTypical { parts.append(L("типично", "typical")) }
        return parts.joined(separator: " · ")
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

            if days.contains(where: \.isLastYear) {
                footnote("*", L("Истиот ден претходната година. Се заменува со вистинска прогноза \(WeatherService.forecastHorizonDays + 1) дена пред денот.",
                                "Same day in a previous year. Replaced by the real forecast \(WeatherService.forecastHorizonDays + 1) days ahead."))
            }
            if days.contains(where: \.isClimate) {
                footnote("~", L("Климатска проценка за градот и месецот - засега немам податоци за овие денови. Ќе ја заменам штом ги добијам.",
                                "Climate estimate for the city and month - no data for these days yet. I'll replace it as soon as I get it."))
            }
        }
    }

    private func footnote(_ mark: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(mark)
                .font(.codes(14))
                .foregroundStyle(Theme.gold)
            Text(text)
                .font(.sans(12))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
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
            if let place = day.place {
                // Кај повеќе градови: во кој град си тој ден
                Text(CityCode.code(for: place))
                    .font(.sans(9, .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.gold)
            }
            HStack(spacing: 1) {
                Text(Fmt.day(day.date))
                    .font(.codes(15))
                    .foregroundStyle(Theme.inkSoft)
                if day.isEstimate {
                    Text(day.isClimate ? "~" : "*")
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
                Text(day.isClimate ? "-" : "\(day.rainChance ?? 0)%")
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
