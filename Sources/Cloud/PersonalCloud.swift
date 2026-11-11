import Foundation
import UIKit
import FirebaseFirestore

/// Лични податоци на акаунтот - само ги гледа сопственикот:
/// users/{uid}/wardrobe   - парчиња (со сликата)
/// users/{uid}/outfits    - аутфити
/// users/{uid}/tripPlans  - по патување: аутфити по денови, спакувано, „пред излез“, листите на децата и миленичињата
/// users/{uid}/family     - „Моето семејство“: деца и миленичиња
///
/// При најава: сè од облакот доаѓа на телефонот (а она што е само на телефонот се качува).
/// При одјава телефонот се празни - податоците остануваат тука, на акаунтот.
final class PersonalCloud {
    let uid: String
    private let db = Firestore.firestore()
    private weak var wardrobe: WardrobeStore?
    private weak var trips: TripStore?

    private var listeners: [ListenerRegistration] = []
    private var mergedItems = false
    private var mergedOutfits = false
    private var mergedPlans = false
    private var mergedFamily = false

    /// Лично за едно патување: аутфити по денови, што е спакувано, „пред излез“, скриени предлози.
    struct Plan: Equatable {
        var days: [String: [UUID]]
        var packed: [UUID]
        var exit: [ChecklistItem]?
        var dismissed: [String]?
        /// nil = постар запис (без делот за семејство) - тогаш не се менува.
        var family: [TripFamilyMember]?
        /// Аутфити по денови и спакувани парчиња за децата и миленичињата. nil = постар запис.
        var kids: KidsOutfits?
    }

    struct KidsOutfits: Codable, Equatable {
        var days: [String: [String: [UUID]]]
        var packed: [String: [UUID]]
    }

    /// Последно познат план по патување (за патувања што ќе стигнат подоцна).
    private(set) var plans: [UUID: Plan] = [:]

    init(uid: String, wardrobe: WardrobeStore, trips: TripStore) {
        self.uid = uid
        self.wardrobe = wardrobe
        self.trips = trips
    }

    private var home: DocumentReference { db.collection("users").document(uid) }
    private var itemsRef: CollectionReference { home.collection("wardrobe") }
    private var outfitsRef: CollectionReference { home.collection("outfits") }
    private var plansRef: CollectionReference { home.collection("tripPlans") }
    private var familyRef: CollectionReference { home.collection("family") }

    // MARK: Старт / стоп

    func start() {
        wardrobe?.cloud = self
        trips?.personal = self
        FamilyStore.shared.cloud = self
        wardrobe?.cloudState = .syncing

        listeners.append(itemsRef.addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            guard let self else { return }
            guard let snapshot else { self.failed(error); return }
            self.handleItems(snapshot)
        })
        listeners.append(outfitsRef.addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            guard let self else { return }
            guard let snapshot else { self.failed(error); return }
            self.handleOutfits(snapshot)
        })
        listeners.append(plansRef.addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            guard let self else { return }
            guard let snapshot else { self.failed(error); return }
            self.handlePlans(snapshot)
        })
        listeners.append(familyRef.addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            guard let self else { return }
            guard let snapshot else { self.failed(error); return }
            self.handleFamily(snapshot)
        })
    }

    func stop() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        if wardrobe?.cloud === self {
            wardrobe?.cloud = nil
            wardrobe?.cloudState = .off
        }
        if trips?.personal === self { trips?.personal = nil }
        if FamilyStore.shared.cloud === self { FamilyStore.shared.cloud = nil }
    }

    private func failed(_ error: Error?) {
        if let error { print("Valise: personal cloud - \(error)") }
        wardrobe?.cloudState = .failed
    }

    private func synced() {
        wardrobe?.cloudState = .synced
    }

    // MARK: Парчиња

    private func handleItems(_ snapshot: QuerySnapshot) {
        guard let wardrobe else { return }
        // Качувај го она што е само на телефонот - откако облакот навистина одговорил.
        if !mergedItems && !snapshot.metadata.isFromCache {
            mergedItems = true
            let remote = Set(snapshot.documents.map(\.documentID))
            for item in wardrobe.items where !remote.contains(item.id.uuidString) {
                pushItem(item, withImage: true)
            }
        }
        for change in snapshot.documentChanges {
            if change.document.metadata.hasPendingWrites { continue }
            guard let id = UUID(uuidString: change.document.documentID) else { continue }
            switch change.type {
            case .added, .modified:
                let data = change.document.data()
                guard let item = Self.item(from: data, id: id) else { continue }
                wardrobe.applyRemote(item, imageData: data["image"] as? Data)
            case .removed:
                wardrobe.removeRemoteItem(id)
            @unknown default:
                break
            }
        }
        if mergedOutfits { synced() }
    }

    func pushItem(_ item: WardrobeItem, withImage: Bool) {
        let ref = itemsRef.document(item.id.uuidString)
        let base = Self.fields(for: item)
        let store = wardrobe
        wardrobe?.cloudState = .syncing
        // Сликата се смалува надвор од главната нишка.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var payload = base
            if withImage, let data = store?.cloudImageData(for: item) {
                payload["image"] = data
            }
            ref.setData(payload, merge: true) { error in
                DispatchQueue.main.async {
                    if let error { self?.failed(error) } else { self?.synced() }
                }
            }
        }
    }

    func deleteItem(_ id: UUID) {
        itemsRef.document(id.uuidString).delete { [weak self] error in
            if let error { self?.failed(error) }
        }
    }

    private static func fields(for item: WardrobeItem) -> [String: Any] {
        var fields: [String: Any] = [
            "name": item.name,
            "category": item.category.rawValue,
            "seasons": item.seasons.map(\.rawValue),
            "createdAt": item.createdAt.timeIntervalSince1970
        ]
        fields["isPhoto"] = item.isPhoto ?? false
        if let kindID = item.kindID { fields["kind"] = kindID }
        if let owner = item.ownerID { fields["owner"] = owner.uuidString }
        return fields
    }

    private static func item(from data: [String: Any], id: UUID) -> WardrobeItem? {
        guard let name = data["name"] as? String,
              let categoryRaw = data["category"] as? String,
              let category = WardrobeCategory(rawValue: categoryRaw) else { return nil }
        let seasons = (data["seasons"] as? [String] ?? []).compactMap(Season.init(rawValue:))
        let created = (data["createdAt"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
        let isPhoto = (data["isPhoto"] as? Bool) == true ? true : nil
        return WardrobeItem(id: id, name: name, category: category, seasons: seasons, createdAt: created,
                            isPhoto: isPhoto, kindID: data["kind"] as? String,
                            ownerID: (data["owner"] as? String).flatMap(UUID.init(uuidString:)))
    }

    // MARK: Аутфити

    private func handleOutfits(_ snapshot: QuerySnapshot) {
        guard let wardrobe else { return }
        if !mergedOutfits && !snapshot.metadata.isFromCache {
            mergedOutfits = true
            let remote = Set(snapshot.documents.map(\.documentID))
            for outfit in wardrobe.outfits where !remote.contains(outfit.id.uuidString) {
                pushOutfit(outfit)
            }
        }
        for change in snapshot.documentChanges {
            if change.document.metadata.hasPendingWrites { continue }
            guard let id = UUID(uuidString: change.document.documentID) else { continue }
            switch change.type {
            case .added, .modified:
                let data = change.document.data()
                guard let name = data["name"] as? String else { continue }
                let ids = (data["itemIDs"] as? [String] ?? []).compactMap(UUID.init(uuidString:))
                let created = (data["createdAt"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
                wardrobe.applyRemote(Outfit(id: id, name: name, itemIDs: ids, createdAt: created,
                                            ownerID: (data["owner"] as? String).flatMap(UUID.init(uuidString:)),
                                            layout: PieceLayout.layout(from: data["layout"])))
            case .removed:
                wardrobe.removeRemoteOutfit(id)
            @unknown default:
                break
            }
        }
        if mergedItems { synced() }
    }

    func pushOutfit(_ outfit: Outfit) {
        wardrobe?.cloudState = .syncing
        var fields: [String: Any] = [
            "name": outfit.name,
            "itemIDs": outfit.itemIDs.map(\.uuidString),
            "createdAt": outfit.createdAt.timeIntervalSince1970
        ]
        if let owner = outfit.ownerID { fields["owner"] = owner.uuidString }
        if let layout = outfit.layout, !layout.isEmpty { fields["layout"] = PieceLayout.fields(for: layout) }
        outfitsRef.document(outfit.id.uuidString).setData(fields) { [weak self] error in
            if let error { self?.failed(error) } else { self?.synced() }
        }
    }

    func deleteOutfit(_ id: UUID) {
        outfitsRef.document(id.uuidString).delete { [weak self] error in
            if let error { self?.failed(error) }
        }
    }

    // MARK: Лично по патување (аутфити, спакувано, пред излез)

    private func handlePlans(_ snapshot: QuerySnapshot) {
        guard let trips else { return }

        for document in snapshot.documents {
            guard let id = UUID(uuidString: document.documentID) else { continue }
            plans[id] = Self.plan(from: document.data())
        }
        for change in snapshot.documentChanges where change.type == .removed {
            if let id = UUID(uuidString: change.document.documentID) { plans.removeValue(forKey: id) }
        }

        // Облакот има предност (по најава телефонот е празен); моите промени што уште се качуваат се прескокнуваат.
        for change in snapshot.documentChanges where change.type != .removed {
            if change.document.metadata.hasPendingWrites { continue }
            guard let id = UUID(uuidString: change.document.documentID),
                  let plan = plans[id],
                  let trip = trips.trip(id),
                  Self.plan(of: trip) != plan else { continue }
            trips.applyPersonal(id, plan: plan)
        }

        // Првиот вистински одговор: патувањата што немаат лични податоци горе - качи ги.
        if !mergedPlans && !snapshot.metadata.isFromCache {
            mergedPlans = true
            for trip in trips.trips where plans[trip.id] == nil {
                pushPlan(trip)
            }
        }
    }

    func pushPlan(_ trip: Trip) {
        let plan = Self.plan(of: trip)
        plans[trip.id] = plan
        var days: [String: [String]] = [:]
        for (key, ids) in plan.days { days[key] = ids.map(\.uuidString) }
        var fields: [String: Any] = [
            "outfitDays": days,
            "outfitPacked": plan.packed.map(\.uuidString),
            "updatedAt": Date().timeIntervalSince1970
        ]
        if let exit = plan.exit,
           let data = try? JSONEncoder().encode(exit),
           let json = try? JSONSerialization.jsonObject(with: data) {
            fields["exitChecklist"] = json
        }
        if let dismissed = plan.dismissed {
            fields["dismissedSuggestions"] = dismissed
        }
        // Децата и миленичињата - секогаш (и празно), за бришењето да стигне до другиот телефон
        if let data = try? JSONEncoder().encode(plan.family ?? []),
           let json = try? JSONSerialization.jsonObject(with: data) {
            fields["family"] = json
        }
        if let kids = plan.kids,
           let data = try? JSONEncoder().encode(kids),
           let json = try? JSONSerialization.jsonObject(with: data) {
            fields["kidsOutfits"] = json
        }
        plansRef.document(trip.id.uuidString).setData(fields) { [weak self] error in
            if let error { self?.failed(error) }
        }
    }

    func cachedPlan(_ id: UUID) -> Plan? { plans[id] }

    /// При бришење на акаунтот: сè лично од облакот.
    func deleteEverything() async {
        for collection in [itemsRef, outfitsRef, plansRef, familyRef] {
            guard let snapshot = try? await collection.getDocuments() else { continue }
            for document in snapshot.documents {
                try? await document.reference.delete()
            }
        }
    }

    func deletePlan(_ id: UUID) {
        plans.removeValue(forKey: id)
        plansRef.document(id.uuidString).delete()
    }

    static func plan(of trip: Trip) -> Plan {
        var days: [String: [UUID]] = [:]
        for date in trip.days {
            let key = Trip.dayKey(date)
            let ids = trip.outfitIDs(forKey: key)
            if !ids.isEmpty { days[key] = ids }
        }
        // И денови надвор од датумите (ако патувањето е скратено) - да не се изгубат
        for (key, ids) in trip.outfitDays ?? [:] where days[key] == nil && !ids.isEmpty {
            days[key] = ids
        }
        return Plan(days: days,
                    packed: trip.outfitPacked ?? [],
                    exit: trip.exitChecklist,
                    dismissed: trip.dismissedSuggestions,
                    // Споделените листи живеат во патувањето (`kids`), не тука
                    family: (trip.family ?? []).filter { $0.isMine && !$0.isShared },
                    kids: KidsOutfits(days: trip.familyOutfitDays ?? [:], packed: trip.familyOutfitPacked ?? [:]))
    }

    private static func plan(from data: [String: Any]) -> Plan {
        var days: [String: [UUID]] = [:]
        for (key, value) in data["outfitDays"] as? [String: Any] ?? [:] {
            let ids = (value as? [String] ?? []).compactMap(UUID.init(uuidString:))
            if !ids.isEmpty { days[key] = ids }
        }
        let packed = (data["outfitPacked"] as? [String] ?? []).compactMap(UUID.init(uuidString:))
        var exit: [ChecklistItem]?
        if let raw = data["exitChecklist"],
           JSONSerialization.isValidJSONObject(raw),
           let json = try? JSONSerialization.data(withJSONObject: raw) {
            exit = try? JSONDecoder().decode([ChecklistItem].self, from: json)
        }
        let dismissed = data["dismissedSuggestions"] as? [String]
        var family: [TripFamilyMember]?
        if let raw = data["family"],
           JSONSerialization.isValidJSONObject(raw),
           let json = try? JSONSerialization.data(withJSONObject: raw) {
            family = try? JSONDecoder().decode([TripFamilyMember].self, from: json)
        }
        var kids: KidsOutfits?
        if let raw = data["kidsOutfits"],
           JSONSerialization.isValidJSONObject(raw),
           let json = try? JSONSerialization.data(withJSONObject: raw) {
            kids = try? JSONDecoder().decode(KidsOutfits.self, from: json)
        }
        return Plan(days: days, packed: packed, exit: exit, dismissed: dismissed, family: family, kids: kids)
    }

    // MARK: Моето семејство (деца и миленичиња)

    private func handleFamily(_ snapshot: QuerySnapshot) {
        let family = FamilyStore.shared
        // Она што е само на телефонот (внесено пред најава) - горе, откако облакот навистина одговорил
        if !mergedFamily && !snapshot.metadata.isFromCache {
            mergedFamily = true
            let remote = Set(snapshot.documents.map(\.documentID))
            for member in family.members where !remote.contains(member.id.uuidString) {
                pushFamily(member)
            }
        }
        for change in snapshot.documentChanges {
            if change.document.metadata.hasPendingWrites { continue }
            guard let id = UUID(uuidString: change.document.documentID) else { continue }
            switch change.type {
            case .added, .modified:
                if let member = Self.member(from: change.document.data(), id: id) {
                    family.applyRemote(member)
                }
            case .removed:
                family.removeRemote(id)
            @unknown default:
                break
            }
        }
    }

    func pushFamily(_ member: FamilyMember) {
        var fields: [String: Any] = [
            "kind": member.kind.rawValue,
            "name": member.name,
            "createdAt": member.createdAt.timeIntervalSince1970
        ]
        if let year = member.birthYear { fields["birthYear"] = year }
        if let month = member.birthMonth { fields["birthMonth"] = month }
        if let pet = member.petType { fields["petType"] = pet.rawValue }
        familyRef.document(member.id.uuidString).setData(fields) { [weak self] error in
            if let error { self?.failed(error) }
        }
    }

    func deleteFamily(_ id: UUID) {
        familyRef.document(id.uuidString).delete { [weak self] error in
            if let error { self?.failed(error) }
        }
    }

    private static func member(from data: [String: Any], id: UUID) -> FamilyMember? {
        guard let kindRaw = data["kind"] as? String, let kind = FamilyKind(rawValue: kindRaw),
              let name = data["name"] as? String else { return nil }
        let created = (data["createdAt"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
        return FamilyMember(id: id, kind: kind, name: name,
                            birthYear: (data["birthYear"] as? NSNumber)?.intValue,
                            birthMonth: (data["birthMonth"] as? NSNumber)?.intValue,
                            petType: (data["petType"] as? String).flatMap(PetType.init(rawValue:)),
                            createdAt: created)
    }
}
