import SwiftUI
import MapKit
import UIKit

// MARK: - Нацрт на патувањето

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
    var customBag: BagSpec = Airlines.customBag()
    var activities: Set<Activity> = [.walking]
    var style: TravelerStyle = .neutral
    var hasLaundry = false
    var companions: [Companion] = []

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

    /// Најголемиот — „главниот“ багаж.
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
        let diff = Calendar.current.dateComponents([.day], from: startDate.startOfDay, to: endDate.startOfDay).day ?? 0
        return max(1, diff + 1)
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
    @State private var weather: [WeatherDay]
    @State private var weatherSource: WeatherSource
    @State private var isLoadingWeather = false
    @State private var weatherKey: String
    @State private var companionName = ""
    @FocusState private var companionFocused: Bool
    /// Пријатели од контакти: по креирањето — ако имаат Valise, влегуваат во патувањето; ако немаат — покана.
    @State private var pendingInvites: [PendingInvite] = []
    @State private var contactNote: String?
    @State private var showAirlinePicker = false

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
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
                // Нов чекор = нов ScrollView, секогаш од врвот
                .id(step)
                .transition(.opacity)

                bottomBar
            }
        }
        .sensoryFeedback(.selection, trigger: step)
        .onAppear {
            // Без Premium нема правила на авиокомпании — општи багажи
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
                            draft.resetBags()
                        }
                    }
                }
            }

            if draft.transport == .plane && !premium.isPremium {
                PremiumLockRow(icon: "airplane",
                               title: L("Авиокомпанија и правила за багаж", "Airline and baggage rules"),
                               detail: L("Мерки и килограми за 140+ авиокомпании — без казни на аеродром.",
                                         "Sizes and weights for 140+ airlines — no fees at the gate."))
            }

            if draft.transport == .plane && premium.isPremium {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(L("Авиокомпанија", "Airline"))
                    Button {
                        showAirlinePicker = true
                    } label: {
                        let airline = Airlines.find(draft.airlineID)
                        HStack(spacing: 14) {
                            Text(airline?.code ?? "—")
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
                Eyebrow(L("Со што пакуваш — може повеќе", "What you're packing in — pick several"))
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

            if premium.isPremium {
                companionsEditor
            } else {
                PremiumLockRow(icon: "person.2",
                               title: L("Патувај со пријатели", "Travel with friends"),
                               detail: L("Заедничка листа и кој што носи — синхронизирано кај сите.",
                                         "A shared list and who brings what — synced for everyone."))
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
                    Label(L("има Tripdrobe — ќе ја гледа истата листа", "on Tripdrobe — will see the same list"),
                          systemImage: "checkmark.icloud")
                    Label(L("уште нема — по креирањето допри го името во патувањето и испрати покана",
                            "not yet — after creating, tap their name in the trip to send an invite"),
                          systemImage: "envelope")
                }
                .font(.sans(12))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            }

            Text(L("Заедничките работи (шампон, крема за сонце, адаптер…) можете да ги поделите — тоа што го носи пријател не зафаќа место во твојот багаж.",
                   "Share common items (shampoo, sunscreen, adapter…) — whatever a friend carries doesn't take space in your bag."))
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
        var trip = Trip(origin: draft.origin,
                        destination: destination,
                        startDate: draft.startDate.startOfDay,
                        endDate: max(draft.endDate, draft.startDate).startOfDay,
                        transport: draft.transport,
                        airlineID: draft.transport == .plane && premium.isPremium ? draft.airlineID : nil,
                        bag: draft.primaryBag,
                        activities: Activity.allCases.filter { draft.activities.contains($0) },
                        style: draft.style,
                        hasLaundry: draft.hasLaundry)
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
            }

            VStack(alignment: .leading, spacing: 14) {
                summaryRow(icon: draft.transport.icon, text: transportText)
                summaryRow(icon: draft.primaryBag.kind.icon, text: draft.bagsSummary)
                if !draft.companions.isEmpty {
                    summaryRow(icon: "person.2", text: draft.companions.map(\.name).joined(separator: ", "))
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
                    WeatherCreditView()
                }
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
        if draft.transport == .plane, premium.isPremium, let airline = Airlines.find(draft.airlineID), airline.id != "other" {
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
        guard premium.isPremium, let destination = draft.destination else { return }
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
        draft.destination != nil && draft.endDate >= draft.startDate && !draft.resolvedBags.isEmpty && draft.totalVolume > 0
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

        let finalTrip = updated
        store.mutate(original.id) { $0 = finalTrip }
        if updated.weather.isEmpty {
            Task { await store.refreshWeather(original.id, force: true) }
        }
        sendInvites(to: original.id)
        dismiss()
    }

    private func create() {
        guard var trip = previewTrip else { return }
        trip.weatherUpdatedAt = weather.isEmpty ? nil : Date()
        trip.items = PackingEngine.generate(for: trip)
        PackingEngine.ensureTogether(&trip)
        trip.exitChecklist = PackingEngine.defaultExitChecklist()

        LastOrigin.save(draft.origin)
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
                                Text(L("ВКЛУЧЕНО", "INCLUDED"))
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
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Додај \(bag.displayTitle)", "Add \(bag.displayTitle)"))
            } else {
                HStack(spacing: 0) {
                    Button { onChange(count - 1) } label: {
                        Image(systemName: count == 1 ? "xmark" : "minus")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 30, height: 30)
                    }
                    .accessibilityLabel(L("Помалку", "Fewer"))
                    Text("\(count)")
                        .font(.codes(17))
                        .frame(minWidth: 16)
                    Button { onChange(min(maxCount, count + 1)) } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 30, height: 30)
                    }
                    .disabled(count >= maxCount)
                    .opacity(count >= maxCount ? 0.4 : 1)
                    .accessibilityLabel(L("Повеќе", "More"))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.goldLight)
                .padding(.horizontal, 2)
                .background(Capsule().fill(Theme.navy))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
                        Text(L("Нема таква авиокомпанија. Избери „Друга“ и внеси мерки.",
                               "No such airline. Choose “Other” and enter the sizes."))
                            .font(.sans(14))
                            .foregroundStyle(Theme.muted)
                            .listRowBackground(Theme.surface)
                        if let other = Airlines.find("other") { row(other) }
                    } else {
                        ForEach(results) { row($0) }
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

    private func row(_ airline: Airline) -> some View {
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
                    Text(airline.name)
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
