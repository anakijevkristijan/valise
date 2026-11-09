import Foundation

/// „Моето семејство“: децата и миленичињата се внесуваат еднаш (Профил), а секое патување само избира кој оди.
/// Се чува на телефонот, а со акаунт и во `users/{uid}/family` (го гледа само сопственикот).
/// При одјава се брише од телефонот.
final class FamilyStore: ObservableObject {
    static let shared = FamilyStore()
    static let storageKey = "familyMembers"

    /// Прво децата, па миленичињата - по редот на додавање.
    @Published private(set) var members: [FamilyMember] = []

    /// Поврзано кога си најавен.
    weak var cloud: PersonalCloud?

    private init() {
        load()
    }

    var children: [FamilyMember] { members.filter { $0.kind == .child } }
    var pets: [FamilyMember] { members.filter { $0.kind == .pet } }

    func member(_ id: UUID?) -> FamilyMember? {
        guard let id else { return nil }
        return members.first { $0.id == id }
    }

    // MARK: Промени

    func save(_ member: FamilyMember) {
        var copy = member
        copy.name = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = members.firstIndex(where: { $0.id == copy.id }) {
            members[index] = copy
        } else {
            members.append(copy)
        }
        sortAndPersist()
        cloud?.pushFamily(copy)
    }

    func delete(_ id: UUID) {
        guard members.contains(where: { $0.id == id }) else { return }
        members.removeAll { $0.id == id }
        sortAndPersist()
        cloud?.deleteFamily(id)
    }

    // MARK: Облак

    func applyRemote(_ member: FamilyMember) {
        if let index = members.firstIndex(where: { $0.id == member.id }) {
            guard members[index] != member else { return }
            members[index] = member
        } else {
            members.append(member)
        }
        sortAndPersist()
    }

    func removeRemote(_ id: UUID) {
        guard members.contains(where: { $0.id == id }) else { return }
        members.removeAll { $0.id == id }
        sortAndPersist()
    }

    /// По одјава: од телефонот (останува на акаунтот).
    func wipeLocal() {
        members = []
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    // MARK: Диск

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let saved = try? JSONDecoder().decode([FamilyMember].self, from: data) else { return }
        members = Self.sorted(saved)
    }

    private func sortAndPersist() {
        members = Self.sorted(members)
        if let data = try? JSONEncoder().encode(members) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private static func sorted(_ list: [FamilyMember]) -> [FamilyMember] {
        list.sorted { ($0.kind == .child ? 0 : 1, $0.createdAt) < ($1.kind == .child ? 0 : 1, $1.createdAt) }
    }
}
