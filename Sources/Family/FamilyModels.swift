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

/// Со кого се споделува листата на детето: избран сопатник.
enum FamilyRole: String, Codable, CaseIterable, Identifiable {
    case mother, father, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mother: return L("Мајка", "Mother")
        case .father: return L("Татко", "Father")
        case .other: return L("Друг", "Someone else")
        }
    }
}

struct FamilyShare: Codable, Hashable, Identifiable {
    /// Акаунтот на сопатникот.
    var uid: String
    var name: String
    var role: FamilyRole

    var id: String { uid }
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
    /// Со кого е споделена листата (мајка, татко или друг сопатник што ќе го избереш). Празно = само јас.
    var shares: [FamilyShare]?
    /// Кога листата ми е споделена мене: чие е детето (nil = мое).
    var ownerUID: String?
    var ownerName: String?

    var isShared: Bool { !(shares ?? []).isEmpty }
    /// Мое дете/милениче (не споделено од друг).
    var isMine: Bool { ownerUID == nil || ownerUID == Session.uid }

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
    /// Само моите - листа што некој ми ја споделил не оди во мојот багаж.
    var familyItems: [PackingItem] {
        guard PremiumStore.cachedIsPremium else { return [] }
        return myFamily.flatMap(\.items)
    }

    var hasFamily: Bool { !(family ?? []).isEmpty }

    /// Моите деца и миленичиња во патувањето (без тие што некој ми ги споделил).
    var myFamily: [TripFamilyMember] { (family ?? []).filter(\.isMine) }

    /// Листи што некој друг (пр. другиот родител) ми ги споделил мене.
    var sharedWithMe: [TripFamilyMember] { (family ?? []).filter { !$0.isMine } }

    /// Сопатникот е тргнат од патувањето → повеќе не ја гледа ниту листата на детето.
    mutating func dropFamilyShares(with uid: String) {
        guard var list = family else { return }
        for index in list.indices where list[index].isMine {
            let kept = (list[index].shares ?? []).filter { $0.uid != uid }
            list[index].shares = kept.isEmpty ? nil : kept
        }
        family = list
    }

    /// Споделувањето важи само за сопатници што се уште во патувањето.
    mutating func pruneFamilyShares() {
        guard var list = family else { return }
        let valid = Set((companions ?? []).compactMap(\.uid))
        for index in list.indices where list[index].isMine {
            let kept = (list[index].shares ?? []).filter { valid.contains($0.uid) }
            list[index].shares = kept.isEmpty ? nil : kept
        }
        family = list
    }

    // MARK: Аутфити по денови за дете или милениче

    /// Патувањето „низ очите“ на член од семејството: неговите аутфити по денови и неговите спакувани парчиња.
    /// Така истите екрани (денови, аутфити за ден) работат и за мене и за децата. nil = јас.
    func projected(for person: UUID?) -> Trip {
        guard let person else { return self }
        var copy = self
        copy.outfitPlan = nil
        copy.outfitDays = familyOutfitDays?[person.uuidString]
        copy.outfitPacked = familyOutfitPacked?[person.uuidString]
        // Неговата листа, не мојата (за „листата наспроти аутфитите“ да не ги меша)
        copy.items = family?.first { $0.id == person }?.items ?? []
        copy.together = nil
        return copy
    }

    mutating func addOutfit(_ id: UUID, forKey key: String, person: UUID?) {
        guard let person else { addOutfit(id, forKey: key); return }
        var all = familyOutfitDays ?? [:]
        var days = all[person.uuidString] ?? [:]
        var list = days[key] ?? []
        if !list.contains(id) { list.append(id) }
        days[key] = list
        all[person.uuidString] = days
        familyOutfitDays = all
    }

    mutating func removeOutfit(_ id: UUID, forKey key: String, person: UUID?) {
        guard let person else { removeOutfit(id, forKey: key); return }
        var all = familyOutfitDays ?? [:]
        var days = all[person.uuidString] ?? [:]
        var list = days[key] ?? []
        list.removeAll { $0 == id }
        days[key] = list.isEmpty ? nil : list
        all[person.uuidString] = days.isEmpty ? nil : days
        familyOutfitDays = all.isEmpty ? nil : all
    }

    /// Парче од аутфитите на детето: спакувано / не.
    mutating func toggleOutfitPacked(_ item: UUID, person: UUID) {
        var all = familyOutfitPacked ?? [:]
        var list = all[person.uuidString] ?? []
        if list.contains(item) {
            list.removeAll { $0 == item }
        } else {
            list.append(item)
        }
        all[person.uuidString] = list.isEmpty ? nil : list
        familyOutfitPacked = all.isEmpty ? nil : all
    }
}
