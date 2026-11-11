import Foundation

// MARK: - Место

struct Place: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    var region: String?
    var country: String
    var countryCode: String
    var latitude: Double
    var longitude: Double
    var timezone: String?

    var flag: String {
        let base: UInt32 = 127397
        var result = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let flagScalar = UnicodeScalar(base + scalar.value) {
                result.unicodeScalars.append(flagScalar)
            }
        }
        return result
    }

    var subtitle: String {
        [region, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty && $0 != name }
            .joined(separator: ", ")
    }

    var code: String { CityCode.code(for: name) }
}

// MARK: - Превоз

enum Transport: String, Codable, CaseIterable, Identifiable {
    case plane, car, train, bus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plane: return L("Авион", "Plane")
        case .car: return L("Кола", "Car")
        case .train: return L("Воз", "Train")
        case .bus: return L("Автобус", "Bus")
        }
    }

    var icon: String {
        switch self {
        case .plane: return "airplane"
        case .car: return "car.fill"
        case .train: return "tram.fill"
        case .bus: return "bus.fill"
        }
    }
}

// MARK: - Багаж

enum BagKind: String, Codable {
    case personal, cabin, checked, backpack, suitcase, custom

    var icon: String {
        switch self {
        case .personal, .backpack: return "backpack"
        case .cabin: return "suitcase.rolling"
        case .checked, .suitcase: return "suitcase"
        case .custom: return "ruler"
        }
    }

    /// Приближна тежина на празната торба/куфер (kg).
    var tare: Double {
        switch self {
        case .personal, .backpack: return 0.6
        case .cabin: return 2.2
        case .checked, .suitcase: return 3.5
        case .custom: return 1.0
        }
    }
}

struct BagSpec: Codable, Hashable {
    var title: String
    var detail: String?
    var height: Double
    var width: Double
    var depth: Double
    var weightLimit: Double?
    var kind: BagKind
    var isFree: Bool = false
    /// Стабилен клуч (пр. „wizz.cabin“) за превод на насловот.
    var key: String?
    /// Свој багаж: куфер или ранец (за иконата и тежината на празниот багаж).
    var shape: BagKind?

    var icon: String { (kind == .custom ? shape : nil)?.icon ?? kind.icon }
    var tare: Double { (kind == .custom ? shape : nil)?.tare ?? kind.tare }

    var volume: Double { height * width * depth / 1000 }
    var usableVolume: Double { volume * 0.88 }

    var displayTitle: String {
        if kind == .custom, let shape {
            return shape == .backpack ? L("Мој ранец", "My backpack") : L("Мој куфер", "My suitcase")
        }
        if let key, let spec = Airlines.spec(forKey: key) { return spec.title }
        return title
    }

    var displayDetail: String? {
        if let key, let spec = Airlines.spec(forKey: key) { return spec.detail }
        return detail
    }

    var dimensionText: String {
        "\(Fmt.number(height)) × \(Fmt.number(width)) × \(Fmt.number(depth)) cm"
    }

    var limitText: String {
        var parts = [dimensionText]
        if let weightLimit { parts.append(L("до \(Fmt.number(weightLimit)) kg", "up to \(Fmt.number(weightLimit)) kg")) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Активности и стил

enum Activity: String, Codable, CaseIterable, Identifiable {
    case photo, walking, dining, work, fitness, beach, hiking, nightlife

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photo: return L("Сликање", "Photos")
        case .walking: return L("Прошетки", "Walking")
        case .dining: return L("Елегантни вечери", "Fine dining")
        case .work: return L("Работа", "Work")
        case .fitness: return L("Фитнес", "Fitness")
        case .beach: return L("Плажа", "Beach")
        case .hiking: return L("Планина", "Hiking")
        case .nightlife: return L("Ноќен живот", "Nightlife")
        }
    }

    var subtitle: String {
        switch self {
        case .photo: return L("Instagram и спомени", "Instagram and memories")
        case .walking: return L("Град пеш, тури", "City on foot, tours")
        case .dining: return L("Ресторани, настани", "Restaurants, events")
        case .work: return L("Лаптоп и состаноци", "Laptop and meetings")
        case .fitness: return L("Тренинг на пат", "Training on the go")
        case .beach: return L("Сонце и море", "Sun and sea")
        case .hiking: return L("Патеки и природа", "Trails and nature")
        case .nightlife: return L("Барови и забава", "Bars and parties")
        }
    }

    var icon: String {
        switch self {
        case .photo: return "camera"
        case .walking: return "figure.walk"
        case .dining: return "fork.knife"
        case .work: return "laptopcomputer"
        case .fitness: return "dumbbell"
        case .beach: return "beach.umbrella"
        case .hiking: return "mountain.2"
        case .nightlife: return "sparkles"
        }
    }
}

enum TravelerStyle: String, Codable, CaseIterable, Identifiable {
    case woman, man, neutral

    var id: String { rawValue }

    var title: String {
        switch self {
        case .woman: return L("Жена", "Woman")
        case .man: return L("Маж", "Man")
        case .neutral: return L("Неутрално", "Neutral")
        }
    }
}

// MARK: - Предмети

enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case documents, clothing, shoes, toiletries, health, electronics, accessories, activity, journey

    var id: String { rawValue }

    var title: String {
        switch self {
        case .documents: return L("Документи", "Documents")
        case .clothing: return L("Облека", "Clothing")
        case .shoes: return L("Обувки", "Shoes")
        case .toiletries: return L("Хигиена и козметика", "Toiletries")
        case .health: return L("Здравје", "Health")
        case .electronics: return L("Електроника", "Electronics")
        case .accessories: return L("Додатоци", "Accessories")
        case .activity: return L("За активностите", "For your activities")
        case .journey: return L("За патот", "For the journey")
        }
    }

    var icon: String {
        switch self {
        case .documents: return "doc.text"
        case .clothing: return "tshirt"
        case .shoes: return "shoeprints.fill"
        case .toiletries: return "drop"
        case .health: return "cross.case"
        case .electronics: return "bolt"
        case .accessories: return "eyeglasses"
        case .activity: return "sparkles"
        case .journey: return "map"
        }
    }
}

struct PackingItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var category: ItemCategory
    var quantity: Int
    var note: String?
    var isPacked: Bool = false
    var unitVolume: Double
    var unitWeight: Double
    var wornCount: Int = 0
    var isCustom: Bool = false
    /// Клуч од каталогот - името се преведува при приказ.
    var key: String?
    var noteKey: String?
    /// Само за делот „Заедно“: кој го носи (id на сопатник).
    /// nil = локално „јас“, кај патување со акаунти „уште не е одлучено“.
    var assignee: UUID?
    /// Бројката е рачно сменета - новата прогноза повеќе не ја менува.
    var quantityEdited: Bool?
    /// Редот е додаден сам, бидејќи го има во аутфитите (пр. сукња) - бројката ја следи гардеробата.
    var fromOutfits: Bool?

    /// Парчиња во торбата (без облеченото).
    var bagUnits: Int { max(0, quantity - wornCount) }

    var isShareable: Bool { key.map { Catalog.isShareable($0) } ?? false }

    var displayName: String {
        if let key, let translated = Catalog.name(key) { return translated }
        return name
    }

    var displayNote: String? {
        if let noteKey, let translated = Catalog.note(noteKey) { return translated }
        return note
    }

    /// Идентитет за споредба (клуч ако има, инаку име).
    var identity: String { (key ?? name).lowercased() }

    var detailText: String? {
        var parts: [String] = []
        if wornCount > 0 {
            if wornCount == quantity {
                parts.append(L("на тебе на пат", "wear it on the way"))
            } else {
                parts.append(L("\(wornCount) на тебе на пат", "\(wornCount) worn on the way"))
            }
        }
        if let note = displayNote, !note.isEmpty { parts.append(note) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

struct ChecklistItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var icon: String
    var isDone: Bool = false
    var key: String?

    var displayTitle: String {
        if let key, let translated = Catalog.exitTitle(key) { return translated }
        return title
    }
}

// MARK: - Време

enum WeatherSource: String, Codable {
    case forecast, lastYear, mixed, climate, none

    var label: String {
        switch self {
        case .forecast: return L("Прогноза", "Forecast")
        case .lastYear: return L("Лани*", "Last year*")
        case .mixed: return L("Прогноза + лани*", "Forecast + last year*")
        case .climate: return L("Проценка~", "Estimate~")
        case .none: return L("Нема податоци", "No data")
        }
    }

    /// Ознака според тоа што навистина има во деновите (прогноза, лани*, проценка~).
    static func describe(_ days: [WeatherDay]) -> String {
        guard !days.isEmpty else { return WeatherSource.none.label }
        var parts: [String] = []
        if days.contains(where: { !$0.isEstimate }) { parts.append(L("Прогноза", "Forecast")) }
        if days.contains(where: \.isLastYear) { parts.append(parts.isEmpty ? L("Лани*", "Last year*") : L("лани*", "last year*")) }
        if days.contains(where: \.isClimate) { parts.append(parts.isEmpty ? L("Проценка~", "Estimate~") : L("проценка~", "estimate~")) }
        return parts.joined(separator: " + ")
    }
}

struct WeatherDay: Codable, Hashable, Identifiable {
    var date: Date
    var maxTemp: Double
    var minTemp: Double
    var rainChance: Int?
    var precipitation: Double?
    var code: Int
    /// true = истиот ден лани (проценка), не прогноза.
    var fromLastYear: Bool?
    /// Градот (кај патување низ повеќе градови).
    var place: String?
    /// true = климатска проценка (нема податоци за денот) - само за приказ, листата не се гради од неа.
    var fromClimate: Bool? = nil

    var id: Date { date }
    var isLastYear: Bool { fromLastYear ?? false }
    var isClimate: Bool { fromClimate ?? false }
    var isEstimate: Bool { isLastYear || isClimate }

    var icon: String {
        switch code {
        case 0: return "sun.max"
        case 1, 2: return "cloud.sun"
        case 3: return "cloud"
        case 45, 48: return "cloud.fog"
        case 51...57: return "cloud.drizzle"
        case 61...67, 80...82: return "cloud.rain"
        case 71...77, 85, 86: return "cloud.snow"
        case 95...99: return "cloud.bolt.rain"
        default: return "cloud.sun"
        }
    }

    var isSnow: Bool { (71...77).contains(code) || code == 85 || code == 86 }

    var isRainy: Bool {
        if let rainChance { return rainChance >= 40 }
        if let precipitation { return precipitation >= 1 }
        return (51...67).contains(code) || (80...82).contains(code) || code >= 95
    }
}

struct WeatherSummary {
    var minTemp: Double?
    var maxTemp: Double?
    var maxRainChance: Int?
    var rainyDays: Int
    var hasSnow: Bool

    init(days: [WeatherDay]) {
        minTemp = days.map(\.minTemp).min()
        maxTemp = days.map(\.maxTemp).max()
        maxRainChance = days.compactMap(\.rainChance).max()
        rainyDays = days.filter(\.isRainy).count
        hasSnow = days.contains(where: \.isSnow)
    }

    var hasData: Bool { minTemp != nil }

    var shortText: String? {
        guard let minTemp, let maxTemp else { return nil }
        return "\(Int(maxTemp.rounded()))°/\(Int(minTemp.rounded()))°"
    }
}

// MARK: - Сопатник

struct Companion: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    /// Акаунт на Valise (ако го има).
    var uid: String?
    /// Клуч на поканата (p_… или e_…) додека не се регистрира.
    var inviteKey: String?

    var hasAccount: Bool { uid != nil }

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

// MARK: - Град во патувањето (повеќе градови, Premium)

/// Сопатник и неговите градови и датуми.
struct CompanionPlan: Identifiable {
    let companion: Companion
    let plan: MemberPlan
    var id: UUID { companion.id }
}

/// Нечии градови и датуми во заедничко патување.
struct MemberPlan: Codable, Hashable {
    var origin: Place?
    var stops: [TripStop]
    var startDate: Date
    var endDate: Date

    /// „Скопје → Солун → Атина“
    var routeText: String {
        var names: [String] = []
        if let origin { names.append(origin.name) }
        for stop in stops where names.last != stop.place.name { names.append(stop.place.name) }
        return names.joined(separator: " → ")
    }

    var dateText: String { MemberPlan.range(startDate, endDate) }

    static func range(_ start: Date, _ end: Date) -> String {
        let cal = Calendar.current
        let day = DateFormatter()
        day.locale = AppLanguage.current.locale
        day.setLocalizedDateFormatFromTemplate("d")
        let full = DateFormatter()
        full.locale = AppLanguage.current.locale
        full.setLocalizedDateFormatFromTemplate("d MMM")
        if cal.isDate(start, inSameDayAs: end) { return full.string(from: start) }
        if cal.isDate(start, equalTo: end, toGranularity: .month) {
            return "\(day.string(from: start))–\(full.string(from: end))"
        }
        return "\(full.string(from: start)) – \(full.string(from: end))"
    }

    /// Во кој град е тој ден (или nil ако тогаш не е на патувањето).
    func city(on date: Date) -> String? {
        let d = date.startOfDay
        guard startDate.startOfDay <= d, d <= endDate.startOfDay else { return nil }
        let index = stops.lastIndex(where: { $0.startDate.startOfDay <= d && d <= $0.endDate.startOfDay })
            ?? stops.lastIndex(where: { $0.startDate.startOfDay <= d })
        return index.map { stops[$0].place.name } ?? stops.first?.place.name
    }

    /// Кога сме заедно: деновите што се преклопуваат и градовите каде сме двајцата истиот ден.
    func overlap(with other: MemberPlan) -> (start: Date, end: Date, cities: [String])? {
        let start = max(startDate.startOfDay, other.startDate.startOfDay)
        let end = min(endDate.startOfDay, other.endDate.startOfDay)
        guard start <= end else { return nil }
        var cities: [String] = []
        var day = start
        while day <= end {
            if let mine = city(on: day), let theirs = other.city(on: day), mine == theirs, !cities.contains(mine) {
                cities.append(mine)
            }
            day = day.adding(days: 1)
        }
        return (start, end, cities)
    }

    func sameRoute(as other: MemberPlan) -> Bool {
        origin?.id == other.origin?.id
            && stops.map(\.place.id) == other.stops.map(\.place.id)
            && Calendar.current.isDate(startDate, inSameDayAs: other.startDate)
            && Calendar.current.isDate(endDate, inSameDayAs: other.endDate)
    }
}

struct TripStop: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var place: Place
    var startDate: Date
    var endDate: Date
    /// Перална машина во сместувањето во овој град.
    var hasLaundry: Bool = false

    var dayCount: Int {
        let diff = Calendar.current.dateComponents([.day], from: startDate.startOfDay, to: endDate.startOfDay).day ?? 0
        return max(1, diff + 1)
    }
}

// MARK: - Патување

struct Trip: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var origin: Place?
    var destination: Place
    var startDate: Date
    var endDate: Date
    var transport: Transport
    var airlineID: String?
    /// Главниот (најголемиот) багаж - за компатибилност со постарите верзии.
    var bag: BagSpec
    /// Сите багажи на патувањето (пр. мала торба + кабински + 2 чекирани).
    var bags: [BagSpec]?
    var activities: [Activity]
    var style: TravelerStyle
    var hasLaundry: Bool
    /// Мојата лична листа.
    var items: [PackingItem] = []
    /// Заедничките работи (шампон, паста…) - со избор кој носи. nil = нема делот.
    var together: [PackingItem]?
    var exitChecklist: [ChecklistItem] = []
    var weather: [WeatherDay] = []
    var weatherSource: WeatherSource = .none
    var weatherUpdatedAt: Date?
    var dismissedSuggestions: [String] = []
    var tint: Int = 0
    var createdAt: Date = Date()
    var companions: [Companion]?
    /// Заедничко патување (Firebase).
    var ownerUID: String?
    var memberUIDs: [String]?
    /// Стар запис (1.8): еден аутфит по ден. Се префрла во `outfitDays`.
    var outfitPlan: [String: UUID]?
    /// Аутфити по ден ("yyyy-MM-dd" → повеќе аутфити). Лично, не се синхронизира.
    var outfitDays: [String: [UUID]]?
    /// Парчиња од гардеробата што веќе се спакувани.
    var outfitPacked: [UUID]?
    /// Градовите по ред (Premium). nil или еден = патување во еден град (`destination`).
    var stops: [TripStop]?
    /// Своето име на патувањето (по избор). Без него - „Париз“ / „Грција“ автоматски.
    var name: String?
    /// Заедничко патување: јас сум си го избрал својот багаж и стил (не се тие на сопственикот).
    /// Само на телефонот - во облакот се чуваат во `personal.{uid}`.
    var ownBags: Bool?
    /// Заедничко патување: имам свои градови и датуми (тргам од друго место, доаѓам подоцна…).
    /// Без ова - ги следам градовите и датумите на тој што го направил патувањето.
    var ownPlan: Bool?
    /// Градовите и датумите на другите во заедничкото патување (uid → план). Само за приказ, од облакот.
    var memberPlans: [String: MemberPlan]?
    /// Децата и миленичињата на патувањето, секое со своја листа (Premium). Лично - го гледа само тој што ќе го избереш.
    var family: [TripFamilyMember]?
    /// Аутфити по денови за децата и миленичињата (id на член → ден → аутфити). Лично.
    var familyOutfitDays: [String: [String: [UUID]]]?
    /// Спакувани парчиња од нивните аутфити (id на член → парчиња). Лично.
    var familyOutfitPacked: [String: [UUID]]?
    /// План по денови: места за посета, сликање, пазарење, сместување (Premium). Кај заедничко патување го гледаат сите.
    var places: [TripPlace]?

    // MARK: Градови и име

    /// Сите градови по ред; кај обично патување - само дестинацијата.
    var allStops: [TripStop] {
        if let stops, !stops.isEmpty { return stops }
        return [TripStop(place: destination, startDate: startDate, endDate: endDate, hasLaundry: hasLaundry)]
    }

    var isMultiStop: Bool { (stops?.count ?? 0) > 1 }

    /// Мојот план (градови и датуми) - за споредба со другите во заедничко патување.
    var myPlan: MemberPlan {
        MemberPlan(origin: origin, stops: allStops, startDate: startDate, endDate: endDate)
    }

    /// Другите патници со нивниот план (ако го знаеме), по редот на сопатниците.
    var travelerPlans: [CompanionPlan] {
        guard let plans = memberPlans else { return [] }
        return travelers.compactMap { companion in
            guard let uid = companion.uid, let plan = plans[uid] else { return nil }
            return CompanionPlan(companion: companion, plan: plan)
        }
    }

    /// Во кој град си тој ден (на ден на преселба - новиот град, таму спиеш).
    func stopIndex(on date: Date) -> Int {
        let day = date.startOfDay
        let list = allStops
        if let index = list.lastIndex(where: { $0.startDate.startOfDay <= day && day <= $0.endDate.startOfDay }) {
            return index
        }
        return list.lastIndex(where: { $0.startDate.startOfDay <= day }) ?? 0
    }

    func stop(on date: Date) -> TripStop {
        allStops[stopIndex(on: date)]
    }

    /// Имиња на државите по ред, без повторување (на јазикот на апликацијата).
    var countryNames: [String] {
        var names: [String] = []
        for stop in allStops {
            let name = AppLanguage.current.locale.localizedString(forRegionCode: stop.place.countryCode) ?? stop.place.country
            if !names.contains(name) { names.append(name) }
        }
        return names
    }

    /// Каде одиш: „Париз“; повеќе градови во една држава - „Грција“; повеќе држави - „Грција и Италија“.
    var placeSummary: String {
        guard isMultiStop else { return destination.name }
        return Trip.joined(countryNames)
    }

    /// Името: своето, или автоматско - „Патување во Париз“ / „Greece trip“.
    var title: String {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return autoTitle
    }

    var autoTitle: String {
        L("Патување во \(placeSummary)", "\(placeSummary) trip")
    }

    /// „Солун → Лефкада → Миконос“
    var stopsText: String {
        allStops.map(\.place.name).joined(separator: " → ")
    }

    /// На картата: „Солун +2“.
    var destinationLabel: String {
        isMultiStop ? "\(destination.name) +\(allStops.count - 1)" : destination.name
    }

    /// За споредба дали прогнозата важи (исти градови и датуми).
    var weatherBasisKey: String {
        allStops.map { "\($0.place.id)-\($0.startDate.startOfDay.timeIntervalSince1970)-\($0.endDate.startOfDay.timeIntervalSince1970)" }
            .joined(separator: "|")
    }

    /// „Грција“, „Грција и Италија“, „Грција, Италија и Хрватска“.
    static func joined(_ names: [String]) -> String {
        guard names.count > 1, let last = names.last else { return names.first ?? "" }
        let head = names.dropLast().joined(separator: ", ")
        return head + L(" и ", " & ") + last
    }

    /// Синхронизирано со акаунт.
    var isCloud: Bool { ownerUID != nil }

    /// Дали јас сум сопственик (или локално патување).
    var isMine: Bool { ownerUID == nil || ownerUID == Session.uid }

    /// Мојот запис меѓу учесниците (само кај заедничко патување).
    var myCompanionID: UUID? {
        guard let uid = Session.uid else { return nil }
        return companions?.first { $0.uid == uid }?.id
    }

    /// Другите патници (без мене).
    var travelers: [Companion] {
        (companions ?? []).filter { $0.uid == nil || $0.uid != Session.uid }
    }

    func companionName(_ id: UUID?) -> String? {
        guard let id else { return nil }
        return travelers.first { $0.id == id }?.firstName
    }

    /// Заедничките работи.
    var togetherItems: [PackingItem] { together ?? [] }

    /// Дали заедничкиот предмет го носам јас.
    func isMine(_ item: PackingItem) -> Bool {
        if isCloud { return item.assignee != nil && item.assignee == myCompanionID }
        return item.assignee == nil
    }

    /// Мојата листа + заедничкото што го носам јас + листите на децата и миленичињата.
    var myItems: [PackingItem] { items + togetherItems.filter { isMine($0) } + familyItems }

    /// Заеднички работи за кои уште не е одлучено кој носи.
    var undecidedCount: Int {
        isCloud ? togetherItems.filter { $0.assignee == nil }.count : 0
    }

    /// Имиња за картата: јас + сопатниците.
    func passengerNames(me: String) -> [String] {
        let first = me.split(separator: " ").first.map(String.init) ?? me
        return ([first] + travelers.map(\.firstName)).filter { !$0.isEmpty }
    }

    var dayCount: Int {
        let diff = Calendar.current.dateComponents([.day], from: startDate.startOfDay, to: endDate.startOfDay).day ?? 0
        return max(1, diff + 1)
    }

    var nightCount: Int { max(0, dayCount - 1) }

    var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Date().startOfDay, to: startDate.startOfDay).day ?? 0
    }

    var isPast: Bool { endDate.startOfDay < Date().startOfDay }
    var isOngoing: Bool { daysUntil <= 0 && !isPast }

    var countdownText: String {
        if isPast { return L("Завршено", "Completed") }
        if isOngoing { return daysUntil == 0 ? L("Денес", "Today") : L("Во тек", "Now") }
        if daysUntil == 1 { return L("Утре", "Tomorrow") }
        return L("За \(Fmt.days(daysUntil))", "In \(Fmt.days(daysUntil))")
    }

    var packedCount: Int { myItems.filter(\.isPacked).count }
    var totalCount: Int { myItems.count }
    var progress: Double { totalCount == 0 ? 0 : Double(packedCount) / Double(totalCount) }

    var airline: Airline? { Airlines.find(airlineID) }

    var isInternational: Bool {
        let home = (origin?.countryCode ?? "MK").uppercased()
        return allStops.contains { $0.place.countryCode.uppercased() != home }
    }

    var originCode: String { origin?.code ?? "---" }
    var destinationCode: String { destination.code }

    var packedVolume: Double {
        myItems.reduce(0) { $0 + Double($1.bagUnits) * $1.unitVolume }
    }

    // MARK: Багажи (може повеќе)

    var allBags: [BagSpec] {
        if let bags, !bags.isEmpty { return bags }
        return [bag]
    }

    var totalUsableVolume: Double {
        allBags.reduce(0) { $0 + $1.usableVolume }
    }

    /// Збир на дозволените тежини - само ако секој багаж има ограничување.
    var totalWeightLimit: Double? {
        let limits = allBags.compactMap(\.weightLimit)
        guard limits.count == allBags.count, !limits.isEmpty else { return nil }
        return limits.reduce(0, +)
    }

    var hasCheckedBag: Bool { allBags.contains { $0.kind == .checked } }

    /// „Мала торба + Кабински куфер ×2“
    var bagsTitle: String {
        var groups: [(title: String, count: Int)] = []
        for spec in allBags {
            let title = spec.displayTitle
            if let index = groups.firstIndex(where: { $0.title == title }) {
                groups[index].count += 1
            } else {
                groups.append((title: title, count: 1))
            }
        }
        return groups.map { $0.count > 1 ? "\($0.title) ×\($0.count)" : $0.title }.joined(separator: " + ")
    }

    var packedWeight: Double {
        let tare = allBags.reduce(0) { $0 + $1.tare }
        return myItems.reduce(tare) { $0 + Double($1.bagUnits) * $1.unitWeight }
    }

    var fillRatio: Double {
        let capacity = totalUsableVolume
        return capacity > 0 ? packedVolume / capacity : 0
    }

    var weightRatio: Double? {
        guard let limit = totalWeightLimit, limit > 0 else { return nil }
        return packedWeight / limit
    }

    var weatherSummary: WeatherSummary { WeatherSummary(days: weather) }

    var routeText: String {
        if let origin { return "\(origin.name) → \(stopsText)" }
        return stopsText
    }

    var shareText: String {
        var lines: [String] = []
        lines.append("✈︎ \(originCode) → \(destinationCode) · \(title) \(destination.flag)")
        if isMultiStop { lines.append(stopsText) }
        lines.append("\(Fmt.range(startDate, endDate)) · \(Fmt.days(dayCount))")
        lines.append(L("Багаж", "Bag") + ": \(bag.displayTitle) (\(bag.limitText))")
        if !togetherItems.isEmpty {
            lines.append("")
            lines.append(L("ЗАЕДНО", "TOGETHER"))
            for item in togetherItems {
                let box = item.isPacked ? "☑︎" : "☐"
                let qty = item.quantity > 1 ? " ×\(item.quantity)" : ""
                let who: String
                if isMine(item) {
                    who = L(" (јас)", " (me)")
                } else if let name = companionName(item.assignee) {
                    who = " (\(name))"
                } else {
                    who = " (?)"
                }
                lines.append("\(box) \(item.displayName)\(qty)\(who)")
            }
        }
        for category in ItemCategory.allCases {
            let group = items.filter { $0.category == category }
            guard !group.isEmpty else { continue }
            lines.append("")
            lines.append(category.title.uppercased())
            for item in group {
                let box = item.isPacked ? "☑︎" : "☐"
                let qty = item.quantity > 1 ? " ×\(item.quantity)" : ""
                lines.append("\(box) \(item.displayName)\(qty)")
            }
        }
        for member in family ?? [] where !member.items.isEmpty && PremiumStore.cachedIsPremium {
            lines.append("")
            lines.append(member.name.uppercased())
            for item in member.sortedItems {
                let box = item.isPacked ? "☑︎" : "☐"
                let qty = item.quantity > 1 ? " ×\(item.quantity)" : ""
                lines.append("\(box) \(item.displayName)\(qty)")
            }
        }
        lines.append("")
        lines.append(L("Спакувано со Tripdrobe", "Packed with Tripdrobe"))
        return lines.joined(separator: "\n")
    }

    /// Порака за сопатник: што носи тој/таа.
    func shareText(for companion: Companion, from me: String) -> String {
        let mine = togetherItems.filter { $0.assignee == companion.id }
        var lines: [String] = []
        lines.append(L("Здраво \(companion.firstName)! ✈︎ \(placeSummary), \(Fmt.range(startDate, endDate))",
                       "Hi \(companion.firstName)! ✈︎ \(placeSummary), \(Fmt.range(startDate, endDate))"))
        lines.append("")
        if mine.isEmpty {
            lines.append(L("Уште немаме поделено кој што носи. Ова е заедничкото:", "We haven't split anything yet. Here's what we share:"))
            for item in (togetherItems.isEmpty ? items : togetherItems).prefix(40) {
                let qty = item.quantity > 1 ? " ×\(item.quantity)" : ""
                lines.append("• \(item.displayName)\(qty)")
            }
        } else {
            lines.append(L("Ова го носиш ти, јас останатото:", "You're bringing these, I've got the rest:"))
            for item in mine {
                let qty = item.quantity > 1 ? " ×\(item.quantity)" : ""
                lines.append("☐ \(item.displayName)\(qty)")
            }
        }
        lines.append("")
        let sender = me.split(separator: " ").first.map(String.init) ?? me
        lines.append(L("- \(sender), преку Tripdrobe", "- \(sender), via Tripdrobe"))
        return lines.joined(separator: "\n")
    }
}
