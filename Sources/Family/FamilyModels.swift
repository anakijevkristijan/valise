import Foundation

// MARK: - „Моето семејство“ (Premium)

/// Дете или милениче што патува со тебе.
enum FamilyKind: String, Codable, CaseIterable, Identifiable {
    case child, pet

    var id: String { rawValue }
}

enum PetType: String, Codable, CaseIterable, Identifiable {
    case dog, cat, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dog: return L("Куче", "Dog")
        case .cat: return L("Мачка", "Cat")
        case .other: return L("Друго милениче", "Other pet")
        }
    }

    var icon: String {
        switch self {
        case .dog: return "dog"
        case .cat: return "cat"
        case .other: return "pawprint"
        }
    }
}

/// Возрасна група на детето - од неа зависи листата (пелени, играчки, таблет…).
enum AgeGroup: Int, CaseIterable {
    case baby, toddler, small, school, teen

    init(age: Int) {
        switch age {
        case ..<1: self = .baby
        case 1...2: self = .toddler
        case 3...6: self = .small
        case 7...12: self = .school
        default: self = .teen
        }
    }

    var title: String {
        switch self {
        case .baby: return L("Бебе", "Baby")
        case .toddler: return L("Мало дете", "Toddler")
        case .small: return L("Предучилишно дете", "Preschooler")
        case .school: return L("Школарец", "School-age child")
        case .teen: return L("Тинејџер", "Teenager")
        }
    }

    /// Детската облека е помала: волумен и тежина во однос на возрасен.
    var sizeFactor: Double {
        switch self {
        case .baby: return 0.4
        case .toddler: return 0.5
        case .small: return 0.65
        case .school: return 0.85
        case .teen: return 1
        }
    }
}

/// Член од „Моето семејство“ - се внесува еднаш, во Профил.
struct FamilyMember: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var kind: FamilyKind
    var name: String
    /// Дете: година и месец на раѓање - возраста се пресметува за денот на патувањето.
    var birthYear: Int?
    var birthMonth: Int?
    var petType: PetType?
    var createdAt: Date = Date()

    var isChild: Bool { kind == .child }

    /// Полни години на одреден ден.
    func age(on date: Date = Date()) -> Int? {
        guard kind == .child, let birthYear else { return nil }
        return FamilyText.age(birthYear: birthYear, birthMonth: birthMonth ?? 1, on: date)
    }

    var icon: String { kind == .child ? "figure.child" : (petType ?? .other).icon }

    /// „4 години“ / „Куче“
    var subtitle: String {
        if kind == .pet { return (petType ?? .other).title }
        guard let age = age() else { return L("Дете", "Child") }
        return FamilyText.age(age)
    }
}

/// Детето или миленичето во едно патување: неговата листа за пакување.
/// Лично (како аутфитите) - во облакот е во `users/{uid}/tripPlans`, не кај сопатниците.
struct TripFamilyMember: Codable, Identifiable, Hashable {
    /// Исто како `FamilyMember.id`.
    var id: UUID
    var kind: FamilyKind
    var name: String
    /// Возраст на детето на почетокот на патувањето.
    var age: Int?
    var petType: PetType?
    var items: [PackingItem] = []
    /// Тргнатите предмети - не се враќаат при нова прогноза или уредување.
    var dismissed: [String]?

    init(member: FamilyMember, on date: Date) {
        id = member.id
        kind = member.kind
        name = member.name
        age = member.age(on: date)
        petType = member.petType
    }

    /// Името, возраста или видот сменети во Профил.
    mutating func update(from member: FamilyMember, on date: Date) {
        name = member.name
        age = member.age(on: date)
        petType = member.petType
    }

    var ageGroup: AgeGroup { AgeGroup(age: age ?? 5) }

    var icon: String { kind == .child ? "figure.child" : (petType ?? .other).icon }

    var subtitle: String {
        if kind == .pet { return (petType ?? .other).title }
        guard let age else { return L("Дете", "Child") }
        return FamilyText.age(age)
    }

    var packedCount: Int { items.filter(\.isPacked).count }

    /// По редот на категориите (документи, облека, обувки…).
    var sortedItems: [PackingItem] {
        let order = Dictionary(uniqueKeysWithValues: ItemCategory.allCases.enumerated().map { ($0.element, $0.offset) })
        return items.enumerated()
            .sorted { (order[$0.element.category] ?? 0, $0.offset) < (order[$1.element.category] ?? 0, $1.offset) }
            .map(\.element)
    }
}

enum FamilyText {
    /// „под 1 година“, „1 година“, „4 години“
    static func age(_ years: Int) -> String {
        switch years {
        case ..<1: return L("под 1 година", "under 1")
        case 1: return L("1 година", "1 year old")
        default: return L("\(years) години", "\(years) years old")
        }
    }

    static func age(birthYear: Int, birthMonth: Int, on date: Date) -> Int {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
        guard let year = parts.year, let month = parts.month else { return 0 }
        var years = year - birthYear
        if month < birthMonth { years -= 1 }
        return max(0, years)
    }

    /// „Ана, Лука и Макс“
    static func names(_ list: [String]) -> String {
        guard list.count > 1, let last = list.last else { return list.first ?? "" }
        return list.dropLast().joined(separator: ", ") + L(" и ", " and ") + last
    }
}

extension Trip {
    /// Предметите на децата и миленичињата (Premium) - се бројат во багажот и во „спакувано“.
    var familyItems: [PackingItem] {
        guard PremiumStore.cachedIsPremium else { return [] }
        return (family ?? []).flatMap(\.items)
    }

    var hasFamily: Bool { !(family ?? []).isEmpty }
}
