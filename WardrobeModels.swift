import Foundation

// MARK: - Сезона

enum Season: String, Codable, CaseIterable, Identifiable {
    case spring, summer, autumn, winter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spring: return L("Пролет", "Spring")
        case .summer: return L("Лето", "Summer")
        case .autumn: return L("Есен", "Autumn")
        case .winter: return L("Зима", "Winter")
        }
    }

    var icon: String {
        switch self {
        case .spring: return "camera.macro"
        case .summer: return "sun.max"
        case .autumn: return "leaf"
        case .winter: return "snowflake"
        }
    }

    static func of(_ date: Date) -> Season {
        switch Calendar.current.component(.month, from: date) {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }

    static var current: Season { of(Date()) }
}

// MARK: - Категорија

enum WardrobeCategory: String, Codable, CaseIterable, Identifiable {
    case outerwear, top, dress, bottom, shoes, bag, accessory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .outerwear: return L("Јакни и палта", "Coats and jackets")
        case .top: return L("Горни делови", "Tops")
        case .dress: return L("Фустани", "Dresses")
        case .bottom: return L("Панталони и сукњи", "Trousers and skirts")
        case .shoes: return L("Обувки", "Shoes")
        case .bag: return L("Торби", "Bags")
        case .accessory: return L("Додатоци", "Accessories")
        }
    }

    var shortTitle: String {
        switch self {
        case .outerwear: return L("Јакна", "Jacket")
        case .top: return L("Горно", "Top")
        case .dress: return L("Фустан", "Dress")
        case .bottom: return L("Долно", "Bottom")
        case .shoes: return L("Обувки", "Shoes")
        case .bag: return L("Торба", "Bag")
        case .accessory: return L("Додаток", "Accessory")
        }
    }

    /// „3 горни дела“, „1 фустан“, „2 пара обувки“…
    func count(_ n: Int) -> String {
        let one = n == 1
        switch self {
        case .outerwear: return one ? L("1 јакна", "1 jacket") : L("\(n) јакни", "\(n) jackets")
        case .top: return one ? L("1 горен дел", "1 top") : L("\(n) горни дела", "\(n) tops")
        case .dress: return one ? L("1 фустан", "1 dress") : L("\(n) фустани", "\(n) dresses")
        case .bottom: return one ? L("1 долен дел", "1 bottom") : L("\(n) долни дела", "\(n) bottoms")
        case .shoes: return one ? L("1 пар обувки", "1 pair of shoes") : L("\(n) пара обувки", "\(n) pairs of shoes")
        case .bag: return one ? L("1 торба", "1 bag") : L("\(n) торби", "\(n) bags")
        case .accessory: return one ? L("1 додаток", "1 accessory") : L("\(n) додатоци", "\(n) accessories")
        }
    }

    /// Општите предмети од листата за пакување што ги покрива оваа категорија.
    var packingKeys: [String] {
        switch self {
        case .top: return ["tshirts", "longSleeves", "shirt", "sweater"]
        case .bottom: return ["trousers", "shorts", "longTrousers", "smartTrousers"]
        case .dress: return ["dress", "eveningDress"]
        case .outerwear: return ["lightJacket", "warmJacket"]
        case .shoes: return ["sneakers", "sandals", "smartShoes", "dressShoes", "trainingShoes", "hikingBoots"]
        default: return []
        }
    }

    /// Приближен волумен во куфер (литри, свиткано).
    var volume: Double {
        switch self {
        case .outerwear: return 5.0
        case .top: return 1.2
        case .dress: return 1.8
        case .bottom: return 2.0
        case .shoes: return 3.5
        case .bag: return 2.5
        case .accessory: return 0.3
        }
    }

    /// Приближна тежина (kg).
    var weight: Double {
        switch self {
        case .outerwear: return 0.9
        case .top: return 0.2
        case .dress: return 0.35
        case .bottom: return 0.5
        case .shoes: return 0.8
        case .bag: return 0.5
        case .accessory: return 0.1
        }
    }
}

// MARK: - Цел од листата наспроти аутфитите

/// Листата предлага `need` (пр. 5 маици), аутфитите имаат `have` различни парчиња од тој вид.
struct ClothingTarget: Identifiable {
    let category: WardrobeCategory
    let need: Int
    let have: Int

    var id: String { category.rawValue }
    var missing: Int { max(0, need - have) }
    var over: Int { max(0, have - need) }
    var isMet: Bool { have >= need }

    enum Status { case under, exact, over }
    var status: Status { have < need ? .under : (have == need ? .exact : .over) }

    /// „Горни дела 3/5“
    var label: String { "\(category.shortPlural) \(have)/\(need)" }

    /// Поединечни редови во листата: колку од аутфитите паѓаат на секој предмет.
    struct Share {
        let have: Int
        let need: Int
    }
}

extension WardrobeCategory {
    /// Кратко, во множина — за ознаки „Горни дела 3/5“.
    var shortPlural: String {
        switch self {
        case .outerwear: return L("Јакни", "Jackets")
        case .top: return L("Горни дела", "Tops")
        case .dress: return L("Фустани", "Dresses")
        case .bottom: return L("Долни дела", "Bottoms")
        case .shoes: return L("Обувки", "Shoes")
        case .bag: return L("Торби", "Bags")
        case .accessory: return L("Додатоци", "Accessories")
        }
    }
}

// MARK: - Парче облека

struct WardrobeItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var category: WardrobeCategory
    var seasons: [Season]
    var createdAt: Date = Date()
    /// true = исечена слика (со позадина), не стикер.
    var isPhoto: Bool?

    var imageName: String { id.uuidString + ".png" }

    func fits(_ season: Season?) -> Bool {
        guard let season else { return true }
        return seasons.isEmpty || seasons.contains(season)
    }
}

// MARK: - Аутфит

struct Outfit: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var itemIDs: [UUID]
    var createdAt: Date = Date()
}

// MARK: - План по денови (во патувањето)

extension Trip {
    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    /// Секој ден од патувањето.
    var days: [Date] {
        (0..<dayCount).map { startDate.startOfDay.adding(days: $0) }
    }

    var season: Season { Season.of(startDate) }

    /// Сите аутфити за денот (по редослед).
    func outfitIDs(on date: Date) -> [UUID] {
        outfitIDs(forKey: Trip.dayKey(date))
    }

    func outfitIDs(forKey key: String) -> [UUID] {
        if let list = outfitDays?[key] { return list }
        if let single = outfitPlan?[key] { return [single] }
        return []
    }

    /// Секое „облекување“ на патувањето: (ден, аутфит). Ист аутфит на два дена = два пати.
    var outfitSlots: [(day: String, outfitID: UUID)] {
        days.flatMap { date -> [(day: String, outfitID: UUID)] in
            let key = Trip.dayKey(date)
            return outfitIDs(forKey: key).map { (day: key, outfitID: $0) }
        }
    }

    var hasOutfits: Bool { !outfitSlots.isEmpty }

    /// Го префрла стариот запис (еден аутфит по ден) во новиот.
    mutating func migrateOutfitPlan() {
        guard let old = outfitPlan else { return }
        var days = outfitDays ?? [:]
        for (key, id) in old where days[key] == nil {
            days[key] = [id]
        }
        outfitDays = days
        outfitPlan = nil
    }

    mutating func setOutfits(_ ids: [UUID], forKey key: String) {
        migrateOutfitPlan()
        var days = outfitDays ?? [:]
        if ids.isEmpty {
            days.removeValue(forKey: key)
        } else {
            days[key] = ids
        }
        outfitDays = days.isEmpty ? nil : days
    }

    mutating func addOutfit(_ id: UUID, forKey key: String) {
        var list = outfitIDs(forKey: key)
        guard !list.contains(id) else { return }
        list.append(id)
        setOutfits(list, forKey: key)
    }

    mutating func removeOutfit(_ id: UUID, forKey key: String) {
        setOutfits(outfitIDs(forKey: key).filter { $0 != id }, forKey: key)
    }
}
