import Foundation
import FirebaseFirestore

// MARK: - Претворање Trip ⇄ Firestore

/// Патувањето се чува како еден документ во `trips/{id}`.
/// Предметите се мапа по id — за промена на едно поле без да се препишува целата листа.
enum CloudCodec {

    /// Лични работи што не се споделуваат (секој ги има свои).
    static let personalKeys: Set<String> = [
        "exitChecklist", "dismissedSuggestions", "weather", "weatherSource", "weatherUpdatedAt"
    ]

    static func encode(_ trip: Trip, myUID: String) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(trip),
              var dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        for key in personalKeys { dict.removeValue(forKey: key) }

        if let items = dict["items"] as? [[String: Any]] {
            var map: [String: Any] = [:]
            for (index, raw) in items.enumerated() {
                var item = raw
                guard let id = item["id"] as? String else { continue }
                let packed = (item["isPacked"] as? Bool) ?? false
                if item["packedBy"] == nil {
                    item["packedBy"] = packed ? [myUID] : []
                }
                item.removeValue(forKey: "isPacked")
                item["order"] = index
                map[id] = item
            }
            dict["items"] = map
        }
        return dict
    }

    /// Документ од Firestore → Trip, со моите лични работи од локалната копија.
    static func decode(_ data: [String: Any], local: Trip?, myUID: String) -> Trip? {
        guard var dict = sanitize(data) as? [String: Any] else { return nil }

        if let map = dict["items"] as? [String: Any] {
            let list = map.values
                .compactMap { $0 as? [String: Any] }
                .sorted { (($0["order"] as? Int) ?? 0) < (($1["order"] as? Int) ?? 0) }
                .map { raw -> [String: Any] in
                    var item = raw
                    item.removeValue(forKey: "order")
                    item["isPacked"] = false
                    return item
                }
            dict["items"] = list
        } else {
            dict["items"] = [Any]()
        }

        // Задолжителни полиња што не се во облакот
        dict["exitChecklist"] = [Any]()
        dict["dismissedSuggestions"] = [Any]()
        dict["weather"] = [Any]()
        dict["weatherSource"] = WeatherSource.none.rawValue

        guard JSONSerialization.isValidJSONObject(dict),
              let json = try? JSONSerialization.data(withJSONObject: dict),
              var trip = try? JSONDecoder().decode(Trip.self, from: json) else { return nil }

        // Спакувано — гледано од мене
        for i in trip.items.indices {
            let by = trip.items[i].packedBy ?? []
            trip.items[i].isPacked = trip.items[i].assignee == nil ? by.contains(myUID) : !by.isEmpty
        }

        if let local {
            trip.exitChecklist = local.exitChecklist
            trip.dismissedSuggestions = local.dismissedSuggestions
            trip.weather = local.weather
            trip.weatherSource = local.weatherSource
            trip.weatherUpdatedAt = local.weatherUpdatedAt
        } else {
            trip.exitChecklist = PackingEngine.defaultExitChecklist()
        }
        return trip
    }

    /// Само промените, како патеки на полиња (`items.<id>.quantity` …).
    static func updates(old: Trip, new: Trip, myUID: String) -> [AnyHashable: Any] {
        guard let o = encode(old, myUID: myUID), let n = encode(new, myUID: myUID) else { return [:] }
        var result: [AnyHashable: Any] = [:]

        let topKeys = Set(o.keys).union(n.keys).subtracting(["items"])
        for key in topKeys where !same(o[key], n[key]) {
            result[key] = n[key] ?? FieldValue.delete()
        }

        let oldItems = (o["items"] as? [String: Any]) ?? [:]
        let newItems = (n["items"] as? [String: Any]) ?? [:]
        for id in Set(oldItems.keys).union(newItems.keys) {
            guard let newItem = newItems[id] as? [String: Any] else {
                result["items.\(id)"] = FieldValue.delete()
                continue
            }
            guard let oldItem = oldItems[id] as? [String: Any] else {
                result["items.\(id)"] = newItem
                continue
            }
            let fields = Set(oldItem.keys).union(newItem.keys).subtracting(["packedBy"])
            for field in fields where !same(oldItem[field], newItem[field]) {
                result["items.\(id).\(field)"] = newItem[field] ?? FieldValue.delete()
            }
        }

        // Штиклирање: секој за себе, освен кога предметот е доделен некому
        let oldByID = Dictionary(old.items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for item in new.items {
            guard let before = oldByID[item.id], before.isPacked != item.isPacked else { continue }
            let path = "items.\(item.id.uuidString).packedBy"
            if item.isPacked {
                result[path] = FieldValue.arrayUnion([myUID])
            } else if item.assignee == nil {
                result[path] = FieldValue.arrayRemove([myUID])
            } else {
                result[path] = [String]()
            }
        }

        if !result.isEmpty {
            result["updatedAt"] = Date().timeIntervalSince1970
        }
        return result
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
                        if let trip = CloudCodec.decode(change.document.data(), local: local, myUID: self.uid) {
                            self.store?.applyRemote(trip)
                        }
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
    }

    func upload(_ trip: Trip) async {
        guard var data = CloudCodec.encode(trip, myUID: uid) else { return }
        data["updatedAt"] = Date().timeIntervalSince1970
        do {
            try await ref(trip.id).setData(data)
        } catch {
            print("Valise: upload failed — \(error)")
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
