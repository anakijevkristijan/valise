import Foundation
import UIKit
import FirebaseFirestore

/// Лични податоци на акаунтот — само ги гледа сопственикот:
/// users/{uid}/wardrobe   — парчиња (со сликата)
/// users/{uid}/outfits    — аутфити
/// users/{uid}/tripPlans  — аутфити по денови и што е спакувано, по патување
///
/// При најава: она што е во облакот доаѓа на телефонот, а она што е само на телефонот се качува.
/// При одјава ништо не се брише од телефонот.
final class PersonalCloud {
    let uid: String
    private let db = Firestore.firestore()
    private weak var wardrobe: WardrobeStore?
    private weak var trips: TripStore?

    private var listeners: [ListenerRegistration] = []
    private var mergedItems = false
    private var mergedOutfits = false
    private var mergedPlans = false

    struct Plan: Equatable {
        var days: [String: [UUID]]
        var packed: [UUID]
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

    // MARK: Старт / стоп

    func start() {
        wardrobe?.cloud = self
        trips?.personal = self
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
    }

    func stop() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        if wardrobe?.cloud === self {
            wardrobe?.cloud = nil
            wardrobe?.cloudState = .off
        }
        if trips?.personal === self { trips?.personal = nil }
    }

    private func failed(_ error: Error?) {
        if let error { print("Valise: personal cloud — \(error)") }
        wardrobe?.cloudState = .failed
    }

    private func synced() {
        wardrobe?.cloudState = .synced
    }

    // MARK: Парчиња

    private func handleItems(_ snapshot: QuerySnapshot) {
        guard let wardrobe else { return }
        // Качувај го она што е само на телефонот — откако облакот навистина одговорил.
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
        return fields
    }

    private static func item(from data: [String: Any], id: UUID) -> WardrobeItem? {
        guard let name = data["name"] as? String,
              let categoryRaw = data["category"] as? String,
              let category = WardrobeCategory(rawValue: categoryRaw) else { return nil }
        let seasons = (data["seasons"] as? [String] ?? []).compactMap(Season.init(rawValue:))
        let created = (data["createdAt"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
        let isPhoto = (data["isPhoto"] as? Bool) == true ? true : nil
        return WardrobeItem(id: id, name: name, category: category, seasons: seasons, createdAt: created, isPhoto: isPhoto)
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
                wardrobe.applyRemote(Outfit(id: id, name: name, itemIDs: ids, createdAt: created))
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
        outfitsRef.document(outfit.id.uuidString).setData([
            "name": outfit.name,
            "itemIDs": outfit.itemIDs.map(\.uuidString),
            "createdAt": outfit.createdAt.timeIntervalSince1970
        ]) { [weak self] error in
            if let error { self?.failed(error) } else { self?.synced() }
        }
    }

    func deleteOutfit(_ id: UUID) {
        outfitsRef.document(id.uuidString).delete { [weak self] error in
            if let error { self?.failed(error) }
        }
    }

    // MARK: План по денови (по патување)

    private func handlePlans(_ snapshot: QuerySnapshot) {
        guard let trips else { return }

        for document in snapshot.documents {
            guard let id = UUID(uuidString: document.documentID) else { continue }
            plans[id] = Self.plan(from: document.data())
        }
        for change in snapshot.documentChanges where change.type == .removed {
            if let id = UUID(uuidString: change.document.documentID) { plans.removeValue(forKey: id) }
        }

        if !mergedPlans {
            // Патување без локален план → земи го од облакот.
            for trip in trips.trips where !Self.hasPlan(trip) {
                if let plan = plans[trip.id] {
                    trips.setPlanFromCloud(trip.id, days: plan.days, packed: plan.packed)
                }
            }
            // Првиот вистински одговор од облакот: локалните планови што ги нема горе се качуваат.
            if !snapshot.metadata.isFromCache {
                mergedPlans = true
                for trip in trips.trips where Self.hasPlan(trip) && plans[trip.id] != Self.plan(of: trip) {
                    pushPlan(trip)
                }
            }
            return
        }

        // Промена од друг телефон
        for change in snapshot.documentChanges where change.type != .removed {
            if change.document.metadata.hasPendingWrites { continue }
            guard let id = UUID(uuidString: change.document.documentID),
                  let plan = plans[id],
                  let trip = trips.trip(id),
                  Self.plan(of: trip) != plan else { continue }
            trips.setPlanFromCloud(id, days: plan.days, packed: plan.packed)
        }
    }

    func pushPlan(_ trip: Trip) {
        let plan = Self.plan(of: trip)
        plans[trip.id] = plan
        var days: [String: [String]] = [:]
        for (key, ids) in plan.days { days[key] = ids.map(\.uuidString) }
        plansRef.document(trip.id.uuidString).setData([
            "outfitDays": days,
            "outfitPacked": plan.packed.map(\.uuidString),
            "updatedAt": Date().timeIntervalSince1970
        ]) { [weak self] error in
            if let error { self?.failed(error) }
        }
    }

    func cachedPlan(_ id: UUID) -> Plan? { plans[id] }

    /// При бришење на акаунтот: сè лично од облакот (на телефонот останува).
    func deleteEverything() async {
        for collection in [itemsRef, outfitsRef, plansRef] {
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

    private static func hasPlan(_ trip: Trip) -> Bool {
        trip.outfitDays != nil || trip.outfitPlan != nil || !(trip.outfitPacked ?? []).isEmpty
    }

    private static func plan(of trip: Trip) -> Plan {
        var days: [String: [UUID]] = [:]
        for date in trip.days {
            let key = Trip.dayKey(date)
            let ids = trip.outfitIDs(forKey: key)
            if !ids.isEmpty { days[key] = ids }
        }
        // И денови надвор од датумите (ако патувањето е скратено) — да не се изгубат
        for (key, ids) in trip.outfitDays ?? [:] where days[key] == nil && !ids.isEmpty {
            days[key] = ids
        }
        return Plan(days: days, packed: trip.outfitPacked ?? [])
    }

    private static func plan(from data: [String: Any]) -> Plan {
        var days: [String: [UUID]] = [:]
        for (key, value) in data["outfitDays"] as? [String: Any] ?? [:] {
            let ids = (value as? [String] ?? []).compactMap(UUID.init(uuidString:))
            if !ids.isEmpty { days[key] = ids }
        }
        let packed = (data["outfitPacked"] as? [String] ?? []).compactMap(UUID.init(uuidString:))
        return Plan(days: days, packed: packed)
    }
}
