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
}

// MARK: - Превоз

enum Transport: String, Codable, CaseIterable, Identifiable {
    case plane, car, train, bus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plane: return "Авион"
        case .car: return "Кола"
        case .train: return "Воз"
        case .bus: return "Автобус"
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

    /// Волумен во литри.
    var volume: Double { height * width * depth / 1000 }

    /// Реално искористлив простор (ѕидови, патенти, облини).
    var usableVolume: Double { volume * 0.88 }

    var dimensionText: String {
        "\(Fmt.number(height)) × \(Fmt.number(width)) × \(Fmt.number(depth)) cm"
    }

    var limitText: String {
        var parts = [dimensionText]
        if let weightLimit { parts.append("до \(Fmt.number(weightLimit)) kg") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Активности и стил

enum Activity: String, Codable, CaseIterable, Identifiable {
    case photo, walking, dining, work, fitness, beach, hiking, nightlife

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photo: return "Сликање"
        case .walking: return "Прошетки"
        case .dining: return "Елегантни вечери"
        case .work: return "Работа"
        case .fitness: return "Фитнес"
        case .beach: return "Плажа"
        case .hiking: return "Планина"
        case .nightlife: return "Ноќен живот"
        }
    }

    var subtitle: String {
        switch self {
        case .photo: return "Instagram и спомени"
        case .walking: return "Град пеш, тури"
        case .dining: return "Ресторани, настани"
        case .work: return "Лаптоп и состаноци"
        case .fitness: return "Тренинг на пат"
        case .beach: return "Сонце и море"
        case .hiking: return "Патеки и природа"
        case .nightlife: return "Барови и забава"
        }
    }

    var icon: String {
        switch self {
        case .photo: return "camera"
        case .walking: return "figure.walk"
        case .dining: return "wineglass"
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
        case .woman: return "Жена"
        case .man: return "Маж"
        case .neutral: return "Неутрално"
        }
    }
}

// MARK: - Предмети

enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case documents, clothing, shoes, toiletries, health, electronics, accessories, activity, journey

    var id: String { rawValue }

    var title: String {
        switch self {
        case .documents: return "Документи"
        case .clothing: return "Облека"
        case .shoes: return "Обувки"
        case .toiletries: return "Хигиена и козметика"
        case .health: return "Здравје"
        case .electronics: return "Електроника"
        case .accessories: return "Додатоци"
        case .activity: return "За активностите"
        case .journey: return "За патот"
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
    /// Литри по парче (спакувано/свиткано).
    var unitVolume: Double
    /// Килограми по парче.
    var unitWeight: Double
    /// Колку парчиња ги носиш на себе на пат (не влегуваат во багажот).
    var wornCount: Int = 0
    var isCustom: Bool = false

    var bagUnits: Int { max(0, quantity - wornCount) }

    var detailText: String? {
        var parts: [String] = []
        if wornCount > 0 { parts.append(wornCount == quantity ? "на тебе на пат" : "\(wornCount) на тебе на пат") }
        if let note, !note.isEmpty { parts.append(note) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

struct ChecklistItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var icon: String
    var isDone: Bool = false
}

// MARK: - Време

enum WeatherSource: String, Codable {
    case forecast, lastYear, none

    var label: String {
        switch self {
        case .forecast: return "Прогноза"
        case .lastYear: return "Проценка според лани"
        case .none: return "Нема податоци"
        }
    }
}

struct WeatherDay: Codable, Hashable, Identifiable {
    var date: Date
    var maxTemp: Double
    var minTemp: Double
    var rainChance: Int?
    var precipitation: Double?
    var code: Int

    var id: Date { date }

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
        return "\(Int(maxTemp.rounded()))° / \(Int(minTemp.rounded()))°"
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
    var bag: BagSpec
    var activities: [Activity]
    var style: TravelerStyle
    var hasLaundry: Bool
    var items: [PackingItem] = []
    var exitChecklist: [ChecklistItem] = []
    var weather: [WeatherDay] = []
    var weatherSource: WeatherSource = .none
    var weatherUpdatedAt: Date?
    var dismissedSuggestions: [String] = []
    var tint: Int = 0
    var createdAt: Date = Date()

    // Траење
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
        if isPast { return "Завршено" }
        if isOngoing { return daysUntil == 0 ? "Денес" : "Во тек" }
        if daysUntil == 1 { return "Утре" }
        return "За \(Fmt.days(daysUntil))"
    }

    // Пакување
    var packedCount: Int { items.filter(\.isPacked).count }
    var progress: Double { items.isEmpty ? 0 : Double(packedCount) / Double(items.count) }

    var airline: Airline? { Airlines.find(airlineID) }

    var isInternational: Bool {
        guard let origin else { return destination.countryCode.uppercased() != "MK" }
        return origin.countryCode.uppercased() != destination.countryCode.uppercased()
    }

    // Багаж
    var packedVolume: Double {
        items.reduce(0) { $0 + Double($1.bagUnits) * $1.unitVolume }
    }

    var packedWeight: Double {
        items.reduce(bag.kind.tare) { $0 + Double($1.bagUnits) * $1.unitWeight }
    }

    var fillRatio: Double {
        bag.usableVolume > 0 ? packedVolume / bag.usableVolume : 0
    }

    var weightRatio: Double? {
        guard let limit = bag.weightLimit, limit > 0 else { return nil }
        return packedWeight / limit
    }

    var weatherSummary: WeatherSummary { WeatherSummary(days: weather) }

    var routeText: String {
        if let origin { return "\(origin.name) → \(destination.name)" }
        return destination.name
    }

    var shareText: String {
        var lines: [String] = []
        lines.append("🧳 \(destination.name), \(destination.country) \(destination.flag)")
        lines.append("\(Fmt.range(startDate, endDate)) · \(Fmt.days(dayCount))")
        lines.append("Багаж: \(bag.title) (\(bag.limitText))")
        for category in ItemCategory.allCases {
            let group = items.filter { $0.category == category }
            guard !group.isEmpty else { continue }
            lines.append("")
            lines.append(category.title.uppercased())
            for item in group {
                let box = item.isPacked ? "☑︎" : "☐"
                let qty = item.quantity > 1 ? " ×\(item.quantity)" : ""
                lines.append("\(box) \(item.name)\(qty)")
            }
        }
        lines.append("")
        lines.append("Спакувано со Valise")
        return lines.joined(separator: "\n")
    }
}
