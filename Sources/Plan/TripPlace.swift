import Foundation

// MARK: - План по денови (Premium): места за посета, сликање, пазарење, каде се спие…

enum PlaceKind: String, Codable, CaseIterable, Identifiable {
    case sight, photo, shopping, food, stay, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sight: return L("Посета", "Sight")
        case .photo: return L("Сликање", "Photo spot")
        case .shopping: return L("Пазарење", "Shopping")
        case .food: return L("Храна и пиење", "Food and drinks")
        case .stay: return L("Сместување", "Stay")
        case .other: return L("Друго", "Other")
        }
    }

    var icon: String {
        switch self {
        case .sight: return "building.columns"
        case .photo: return "camera"
        case .shopping: return "bag"
        case .food: return "fork.knife"
        case .stay: return "bed.double"
        case .other: return "mappin"
        }
    }
}

/// Едно место во планот. Без ден = „кога било“ (листа со желби).
struct TripPlace: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var kind: PlaceKind
    var title: String
    /// Адреса, кварт или што било што помага да се најде.
    var address: String?
    /// Ден ("yyyy-MM-dd"); nil = кога било.
    var dayKey: String?
    /// Час (минути од полноќ); nil = без час.
    var minutes: Int?
    var note: String?
    var isDone: Bool = false

    /// „10:30“
    var timeText: String? {
        guard let minutes else { return nil }
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    /// За „Отвори во Мапи“.
    func mapsURL(city: String) -> URL? {
        let query = [title, address ?? "", city].filter { !$0.isEmpty }.joined(separator: ", ")
        var parts = URLComponents(string: "https://maps.apple.com/")
        parts?.queryItems = [URLQueryItem(name: "q", value: query)]
        return parts?.url
    }
}

extension Trip {
    var allPlaces: [TripPlace] { places ?? [] }

    /// Местата за еден ден, по час (без час - на крај, по редот на додавање).
    func places(on date: Date) -> [TripPlace] {
        places(forKey: Trip.dayKey(date))
    }

    func places(forKey key: String) -> [TripPlace] {
        allPlaces.enumerated()
            .filter { $0.element.dayKey == key }
            .sorted { ($0.element.minutes ?? 9999, $0.offset) < ($1.element.minutes ?? 9999, $1.offset) }
            .map(\.element)
    }

    /// Без ден, или со ден што веќе не е во патувањето (ако се сменети датумите).
    var unscheduledPlaces: [TripPlace] {
        let keys = Set(days.map { Trip.dayKey($0) })
        return allPlaces.filter { place in
            guard let key = place.dayKey else { return true }
            return !keys.contains(key)
        }
    }

    mutating func save(place: TripPlace) {
        var list = places ?? []
        if let index = list.firstIndex(where: { $0.id == place.id }) {
            list[index] = place
        } else {
            list.append(place)
        }
        places = list
    }

    mutating func removePlace(_ id: UUID) {
        var list = places ?? []
        list.removeAll { $0.id == id }
        places = list.isEmpty ? nil : list
    }
}

// MARK: - Свој багаж наспроти правилата на авиокомпанијата

enum OwnBagCheck: Equatable {
    /// Собира како кабински.
    case cabin(String)
    /// Поголем од кабинскиот - мора да се чекира.
    case mustCheck(cabin: String)
    /// Поголем и од чекираниот - се плаќа вонгабаритен багаж.
    case oversize(checked: String)

    var isWarning: Bool {
        if case .cabin = self { return false }
        return true
    }

    func text(airline: String) -> String {
        switch self {
        case .cabin(let size):
            return L("Собира како кабински багаж кај \(airline) (\(size)).", "Fits as a cabin bag on \(airline) (\(size)).")
        case .mustCheck(let size):
            return L("Поголем е од кабинскиот багаж кај \(airline) (\(size)) - на аеродром ќе мора да го чекираш.",
                     "Bigger than \(airline)'s cabin bag (\(size)) - you'll have to check it in at the airport.")
        case .oversize(let size):
            return L("Поголем е и од чекираниот багаж кај \(airline) (\(size)) - очекувај доплата на аеродром.",
                     "Bigger than \(airline)'s checked bag too (\(size)) - expect an extra fee at the airport.")
        }
    }

    /// Дали `bag` собира во `limit` (може и свртен).
    static func fits(_ bag: BagSpec, into limit: BagSpec) -> Bool {
        let a = [bag.height, bag.width, bag.depth].sorted()
        let b = [limit.height, limit.width, limit.depth].sorted()
        return zip(a, b).allSatisfy { $0 <= $1 + 0.5 }
    }

    /// Својот багаж спореден со најголемиот кабински и чекиран багаж на авиокомпанијата.
    static func check(_ bag: BagSpec, airline: Airline) -> OwnBagCheck? {
        let cabins = airline.bags.filter { $0.kind == .cabin }
        let personals = airline.bags.filter { $0.kind == .personal }
        let biggest: ([BagSpec]) -> BagSpec? = { list in list.max { $0.volume < $1.volume } }
        guard let cabin = biggest(cabins) ?? biggest(personals) else { return nil }
        if fits(bag, into: cabin) { return .cabin(cabin.dimensionText) }
        guard let checked = biggest(airline.bags.filter { $0.kind == .checked }) else {
            return .mustCheck(cabin: cabin.dimensionText)
        }
        return fits(bag, into: checked) ? .mustCheck(cabin: cabin.dimensionText) : .oversize(checked: checked.dimensionText)
    }
}

extension Trip {
    /// Предупредувања за своите багажи (сопствени димензии) кај избраната авиокомпанија.
    var ownBagWarnings: [String] {
        guard transport == .plane, let airline = Airlines.find(airlineID) else { return [] }
        var seen: Set<String> = []
        var result: [String] = []
        for bag in allBags where bag.kind == .custom {
            guard let check = OwnBagCheck.check(bag, airline: airline), check.isWarning else { continue }
            let text = check.text(airline: airline.name)
            if seen.insert(text).inserted { result.append(text) }
        }
        return result
    }
}

// MARK: - Запаметен свој багаж

/// Последните сопствени димензии - за следното патување да не се внесуваат пак. Само на телефонот.
enum OwnBagMemory {
    private static let key = "ownBag"

    static func load() -> BagSpec? {
        guard let data = UserDefaults.standard.data(forKey: key),
              var bag = try? JSONDecoder().decode(BagSpec.self, from: data),
              bag.height > 0, bag.width > 0, bag.depth > 0 else { return nil }
        bag.kind = .custom
        bag.key = "custom"
        return bag
    }

    static func save(_ bag: BagSpec) {
        guard bag.kind == .custom, let data = try? JSONEncoder().encode(bag) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func wipe() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
