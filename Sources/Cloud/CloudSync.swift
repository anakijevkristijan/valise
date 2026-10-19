import Foundation
import FirebaseFirestore

// MARK: - Претворање Trip ⇄ Firestore

/// Едно патување = еден документ `trips/{id}`:
/// • заеднички податоци (дестинација, датуми, сопатници…)
/// • `together` — заедничките работи, синхронизирани кај сите (кој носи + спакувано)
/// • `lists.{uid}` — личната листа на секој патник; секој ја гледа само својата
enum CloudCodec {

    /// Лични работи што воопшто не одат во облакот.
    static let personalKeys: Set<String> = [
        "exitChecklist", "dismissedSuggestions", "weather", "weatherSource", "weatherUpdatedAt",
        "outfitPlan", "outfitPacked"
    ]

    static func encode(_ trip: Trip, myUID: String) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(trip),
              var dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        for key in personalKeys { dict.removeValue(forKey: key) }

        let mine = (dict["items"] as? [[String: Any]]) ?? []
        dict.removeValue(forKey: "items")
        dict["lists"] = [myUID: itemMap(mine)]

        if let together = dict["together"] as? [[String: Any]] {
            dict["together"] = itemMap(together)
        }
        return dict
    }

    private static func itemMap(_ items: [[String: Any]]) -> [String: Any] {
        var map: [String: Any] = [:]
        for (index, raw) in items.enumerated() {
            guard let id = raw["id"] as? String else { continue }
            var item = raw
            item["order"] = index
            map[id] = item
        }
        return map
    }

    private static func itemList(_ map: Any?) -> [[String: Any]] {
        guard let map = map as? [String: Any] else { return [] }
        return map.values
            .compactMap { $0 as? [String: Any] }
            .sorted { (($0["order"] as? Int) ?? 0) < (($1["order"] as? Int) ?? 0) }
            .map { raw in
                var item = raw
                item.removeValue(forKey: "order")
                return item
            }
    }

    /// Документ од Firestore → Trip (мојата листа + заедничкото), со моите лични работи од телефонот.
    /// `hasMyList` = false кога штотуку сум се приклучил и уште немам своја листа.
    static func decode(_ data: [String: Any], local: Trip?, myUID: String) -> (trip: Trip, hasMyList: Bool)? {
        guard var dict = sanitize(data) as? [String: Any] else { return nil }

        let lists = dict["lists"] as? [String: Any]
        let hasMyList = lists?[myUID] != nil
        dict["items"] = itemList(lists?[myUID])
        dict.removeValue(forKey: "lists")

        if dict["together"] != nil {
            dict["together"] = itemList(dict["together"])
        }

        // Задолжителни полиња што не се во облакот
        dict["exitChecklist"] = [Any]()
        dict["dismissedSuggestions"] = [Any]()
        dict["weather"] = [Any]()
        dict["weatherSource"] = WeatherSource.none.rawValue

        guard JSONSerialization.isValidJSONObject(dict),
              let json = try? JSONSerialization.data(withJSONObject: dict),
              var trip = try? JSONDecoder().decode(Trip.self, from: json) else { return nil }

        if let local {
            trip.exitChecklist = local.exitChecklist
            trip.dismissedSuggestions = local.dismissedSuggestions
            trip.weather = local.weather
            trip.weatherSource = local.weatherSource
            trip.weatherUpdatedAt = local.weatherUpdatedAt
            trip.outfitPlan = local.outfitPlan
            trip.outfitPacked = local.outfitPacked
        } else {
            trip.exitChecklist = PackingEngine.defaultExitChecklist()
        }
        return (trip, hasMyList)
    }

    /// Мојата листа како мапа (за прво качување кога ќе се приклучам).
    static func listMap(_ items: [PackingItem]) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(items),
              let list = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return [:] }
        return itemMap(list)
    }

    /// Само промените, како патеки на полиња (`together.<id>.assignee`, `lists.<uid>.<id>.isPacked` …).
    static func updates(old: Trip, new: Trip, myUID: String) -> [AnyHashable: Any] {
        guard let o = encode(old, myUID: myUID), let n = encode(new, myUID: myUID) else { return [:] }
        var result: [AnyHashable: Any] = [:]

        let topKeys = Set(o.keys).union(n.keys).subtracting(["lists", "together"])
        for key in topKeys where !same(o[key], n[key]) {
            result[key] = n[key] ?? FieldValue.delete()
        }

        let oldMine = ((o["lists"] as? [String: Any])?[myUID] as? [String: Any]) ?? [:]
        let newMine = ((n["lists"] as? [String: Any])?[myUID] as? [String: Any]) ?? [:]
        diffMap(prefix: "lists.\(myUID)", old: oldMine, new: newMine, into: &result)

        switch (o["together"] as? [String: Any], n["together"] as? [String: Any]) {
        case let (oldTogether?, newTogether?):
            diffMap(prefix: "together", old: oldTogether, new: newTogether, into: &result)
        case (nil, let newTogether?):
            result["together"] = newTogether
        case (_?, nil):
            result["together"] = FieldValue.delete()
        case (nil, nil):
            break
        }

        if !result.isEmpty {
            result["updatedAt"] = Date().timeIntervalSince1970
        }
        return result
    }

    private static func diffMap(prefix: String, old: [String: Any], new: [String: Any], into result: inout [AnyHashable: Any]) {
        for id in Set(old.keys).union(new.keys) {
            guard let newItem = new[id] as? [String: Any] else {
                result["\(prefix).\(id)"] = FieldValue.delete()
                continue
            }
            guard let oldItem = old[id] as? [String: Any] else {
                result["\(prefix).\(id)"] = newItem
                continue
            }
            for field in Set(oldItem.keys).union(newItem.keys) where !same(oldItem[field], newItem[field]) {
                result["\(prefix).\(id).\(field)"] = newItem[field] ?? FieldValue.delete()
            }
        }
    }

    private static func same(_ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case (nil, _), (_, nil): return false
        case let (x?, y?):
            if let x = x as? NSObject, let y = y as? NSObject { return x.isEqual(y) }
            return false
        }
    }

    /// Firestore вредности → чист JSON (Timestamp → секунди, итн.).
    private static func sanitize(_ value: Any) -> Any? {
        switch value {
        case let dict as [String: Any]:
            var out: [String: Any] = [:]
            for (k, v) in dict { if let clean = sanitize(v) { out[k] = clean } }
            return out
        case let array as [Any]:
            return array.compactMap { sanitize($0) }
        case let timestamp as Timestamp:
            return timestamp.dateValue().timeIntervalSince1970
        case is String, is NSNumber, is NSNull:
            return value
        default:
            return nil
        }
    }
}

// MARK: - Синхронизација

final class CloudSync {
    let uid: String
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private weak var store: TripStore?

    init(uid: String, store: TripStore) {
        self.uid = uid
        self.store = store
    }

    private func ref(_ id: UUID) -> DocumentReference {
        db.collection("trips").document(id.uuidString)
    }

    // MARK: Слушање

    func start() {
        listener?.remove()
        listener = db.collection("trips")
            .whereField("memberUIDs", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else {
                    if let error { print("Valise: listener — \(error)") }
                    return
                }
                for change in snapshot.documentChanges {
                    guard let id = UUID(uuidString: change.document.documentID) else { continue }
                    switch change.type {
                    case .added, .modified:
                        let local = self.store?.trip(id)
                        guard let decoded = CloudCodec.decode(change.document.data(), local: local, myUID: self.uid) else { continue }
                        var trip = decoded.trip
                        if !decoded.hasMyList {
                            // Штотуку се приклучив: правам своја лична листа
                            if let existing = local?.items, !existing.isEmpty {
                                trip.items = existing.filter { !$0.isShareable }
                            } else {
                                trip.items = PackingEngine.personalList(for: trip)
                            }
                            self.uploadMyList(trip)
                        }
                        self.store?.applyRemote(trip)
                    case .removed:
                        self.store?.removeLocal(id)
                    @unknown default:
                        break
                    }
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    // MARK: Качување

    /// Локално патување станува мое заедничко патување.
    func claim(_ trip: inout Trip, myName: String) {
        guard trip.ownerUID == nil else { return }
        trip.ownerUID = uid
        trip.memberUIDs = [uid]
        var list = trip.companions ?? []
        if !list.contains(where: { $0.uid == uid }) {
            list.insert(Companion(name: myName.isEmpty ? "Me" : myName, uid: uid), at: 0)
        }
        trip.companions = list
        // Локално „nil = јас“ → кај акаунти го означуваме експлицитно
        if let me = list.first(where: { $0.uid == uid })?.id, let together = trip.together {
            trip.together = together.map { item in
                var copy = item
                if copy.assignee == nil { copy.assignee = me }
                return copy
            }
        }
    }

    /// Качување на целото патување (спојување — туѓите листи остануваат).
    func upload(_ trip: Trip) async {
        guard var data = CloudCodec.encode(trip, myUID: uid) else { return }
        data["updatedAt"] = Date().timeIntervalSince1970
        do {
            try await ref(trip.id).setData(data, merge: true)
        } catch {
            print("Valise: upload failed — \(error)")
        }
    }

    /// Само мојата лична листа.
    func uploadMyList(_ trip: Trip) {
        let map = CloudCodec.listMap(trip.items)
        Task {
            try? await ref(trip.id).updateData([
                "lists.\(uid)": map,
                "updatedAt": Date().timeIntervalSince1970
            ])
        }
    }

    func push(old: Trip, new: Trip) {
        guard new.isCloud else { return }
        let changes = CloudCodec.updates(old: old, new: new, myUID: uid)
        guard !changes.isEmpty else { return }
        Task {
            do {
                try await ref(new.id).updateData(changes)
            } catch {
                // Документот уште не постои → качи ја најновата верзија (само ако е мое)
                if let latest = store?.trip(new.id), latest.ownerUID == uid {
                    await upload(latest)
                }
            }
        }
    }

    /// Сопственикот брише; другите само излегуваат.
    func removeOrLeave(_ trip: Trip) async {
        guard trip.isCloud else { return }
        if trip.ownerUID == uid {
            try? await ref(trip.id).delete()
        } else {
            let remaining = (trip.companions ?? []).filter { $0.uid != uid }
            let encoded = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(remaining))) ?? []
            try? await ref(trip.id).updateData([
                "memberUIDs": FieldValue.arrayRemove([uid]),
                "companions": encoded,
                "lists.\(uid)": FieldValue.delete(),
                "updatedAt": Date().timeIntervalSince1970
            ])
        }
    }

    // MARK: Пријатели и покани

    /// Дали некој од клучевите (број/е-пошта) припаѓа на акаунт.
    func lookup(keys: [String]) async -> String? {
        for key in keys {
            if let snapshot = try? await db.collection("lookup").document(key).getDocument(),
               let found = snapshot.data()?["uid"] as? String {
                return found
            }
        }
        return nil
    }

    /// Ги регистрира моите клучеви за пријателите да можат да ме најдат.
    func registerProfile(name: String, phoneKey: String?, emailKey: String?) async {
        var user: [String: Any] = ["name": name]
        if let phoneKey { user["phoneHash"] = PhoneID.bareHash(phoneKey) }
        if let emailKey { user["emailHash"] = PhoneID.bareHash(emailKey) }
        try? await db.collection("users").document(uid).setData(user, merge: true)

        for key in [phoneKey, emailKey].compactMap({ $0 }) {
            let doc = db.collection("lookup").document(key)
            if let existing = try? await doc.getDocument(), existing.exists {
                if (existing.data()?["uid"] as? String) == uid { continue }
                continue // бројот веќе е зафатен од друг акаунт
            }
            try? await doc.setData(["uid": uid])
        }
    }

    /// Покана за некој што уште нема акаунт — чека додека не се регистрира.
    func createInvites(trip: Trip, keys: [String], fromName: String) async {
        for key in keys {
            try? await db.collection("invites").document(key)
                .collection("trips").document(trip.id.uuidString)
                .setData([
                    "fromName": fromName,
                    "destination": trip.destination.name,
                    "startDate": trip.startDate.timeIntervalSince1970,
                    "createdAt": Date().timeIntervalSince1970
                ])
        }
    }

    /// По најава: прифати ги поканите што ме чекаат.
    func joinPendingInvites(myKeys: [String], myName: String) async {
        for key in myKeys {
            guard let pending = try? await db.collection("invites").document(key).collection("trips").getDocuments() else { continue }
            for invite in pending.documents {
                let tripRef = db.collection("trips").document(invite.documentID)
                do {
                    try await tripRef.updateData([
                        "memberUIDs": FieldValue.arrayUnion([uid]),
                        "updatedAt": Date().timeIntervalSince1970
                    ])
                    // Мојот запис меѓу сопатниците добива акаунт
                    let snapshot = try await tripRef.getDocument()
                    if let raw = snapshot.data()?["companions"] as? [[String: Any]] {
                        var list = raw
                        var linked = false
                        for i in list.indices where (list[i]["inviteKey"] as? String) == key {
                            list[i]["uid"] = uid
                            list[i]["name"] = myName
                            list[i].removeValue(forKey: "inviteKey")
                            linked = true
                        }
                        if !linked {
                            list.append(["id": UUID().uuidString, "name": myName, "uid": uid])
                        }
                        try await tripRef.updateData(["companions": list])
                    }
                } catch {
                    print("Valise: join failed — \(error)")
                }
                try? await invite.reference.delete()
            }
        }
    }
}
