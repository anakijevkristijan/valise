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
        "outfitPlan", "outfitDays", "outfitPacked", "ownBags", "ownPlan", "memberPlans"
    ]

    /// Секој член има свои: багаж и стил (жена/маж). Во облакот: `personal.{uid}`.
    /// Сопственикот ги пишува и горе (за постари верзии и како почеток за новите членови).
    static let memberKeys: [String] = ["bag", "bags", "style"]

    /// Градовите и датумите. Горе се на тој што го направил патувањето; член што ги сменил
    /// ги има свои во `personal.{uid}` — тие не ги менуваат другите, а другите не ги менуваат нив.
    static let planKeys: [String] = ["origin", "destination", "startDate", "endDate", "stops",
                                     "transport", "airlineID", "hasLaundry"]

    static func encode(_ trip: Trip, myUID: String) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(trip),
              var dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        for key in personalKeys { dict.removeValue(forKey: key) }

        let mine = (dict["items"] as? [[String: Any]]) ?? []
        dict.removeValue(forKey: "items")
        dict["lists"] = [myUID: itemMap(mine)]

        // Мојот багаж и стил — само ако се мои (сопственик, или член што ги избрал);
        // моите градови и датуми — кај член само ако ги сменил (инаку ги следи сопственикот)
        let isOwner = trip.ownerUID == nil || trip.ownerUID == myUID
        var personal: [String: Any] = [:]
        if isOwner || trip.ownBags == true {
            for key in memberKeys { if let value = dict[key] { personal[key] = value } }
        }
        if !isOwner && trip.ownPlan == true {
            for key in planKeys { if let value = dict[key] { personal[key] = value } }
        }
        if !personal.isEmpty {
            dict["personal"] = [myUID: personal]
        }
        if !isOwner {
            // Член никогаш не ги менува горните полиња (тие се на сопственикот)
            for key in memberKeys + planKeys { dict.removeValue(forKey: key) }
        }

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

        // Мојот багаж и стил; ако уште не сум ги избрал — багажот на сопственикот, стил неутрален
        let allPersonal = (dict["personal"] as? [String: Any]) ?? [:]
        let personal = allPersonal[myUID] as? [String: Any]
        dict.removeValue(forKey: "personal")
        let ownerUID = dict["ownerUID"] as? String
        let isOwner = ownerUID == myUID
        let hasOwnBags = personal?["bag"] != nil
        if let personal, hasOwnBags {
            // Само моите (пр. ако имам еден багаж, не смее да остане листата багажи на сопственикот)
            for key in memberKeys { dict.removeValue(forKey: key) }
            for key in memberKeys { if let value = personal[key] { dict[key] = value } }
        } else if !isOwner {
            dict["style"] = TravelerStyle.neutral.rawValue
        }

        // Градовите и датумите на сопственикот (горе) и на членовите што имаат свои
        var ownerPlanFields: [String: Any] = [:]
        for key in planKeys { if let value = dict[key] { ownerPlanFields[key] = value } }
        let ownerPlan = plan(from: ownerPlanFields)
        var plans: [String: MemberPlan] = [:]
        if let ownerUID, ownerUID != myUID, let ownerPlan { plans[ownerUID] = ownerPlan }
        for uid in (dict["memberUIDs"] as? [String]) ?? [] where uid != myUID && uid != ownerUID {
            let theirs = (allPersonal[uid] as? [String: Any]).flatMap { $0["startDate"] != nil ? plan(from: $0) : nil }
            if let found = theirs ?? ownerPlan { plans[uid] = found }
        }
        // Мојот план: мој ако сум го сменил, инаку тој на сопственикот
        let hasOwnPlan = !isOwner && personal?["startDate"] != nil
        if hasOwnPlan, let personal {
            for key in planKeys { dict.removeValue(forKey: key) }
            for key in planKeys { if let value = personal[key] { dict[key] = value } }
        }

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
            trip.outfitDays = local.outfitDays
            trip.outfitPacked = local.outfitPacked
        } else {
            trip.exitChecklist = PackingEngine.defaultExitChecklist()
        }
        trip.ownBags = isOwner || hasOwnBags
        trip.ownPlan = hasOwnPlan ? true : nil
        trip.memberPlans = plans.isEmpty ? nil : plans
        return (trip, hasMyList)
    }

    /// Поле од облакот → план (градови и датуми). Датумите се како ги запишува JSONEncoder.
    private static func plan(from fields: [String: Any]) -> MemberPlan? {
        guard let start = fields["startDate"], let end = fields["endDate"], let destination = fields["destination"] else { return nil }
        struct Raw: Decodable {
            var origin: Place?
            var destination: Place
            var startDate: Date
            var endDate: Date
            var stops: [TripStop]?
            var hasLaundry: Bool?
        }
        var raw: [String: Any] = ["startDate": start, "endDate": end, "destination": destination]
        if let origin = fields["origin"] { raw["origin"] = origin }
        if let stops = fields["stops"] { raw["stops"] = stops }
        guard JSONSerialization.isValidJSONObject(raw),
              let json = try? JSONSerialization.data(withJSONObject: raw),
              let decoded = try? JSONDecoder().decode(Raw.self, from: json) else { return nil }
        let stops = (decoded.stops?.isEmpty == false) ? decoded.stops!
            : [TripStop(place: decoded.destination, startDate: decoded.startDate, endDate: decoded.endDate)]
        return MemberPlan(origin: decoded.origin, stops: stops, startDate: decoded.startDate, endDate: decoded.endDate)
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

        let topKeys = Set(o.keys).union(n.keys).subtracting(["lists", "together", "personal"])
        for key in topKeys where !same(o[key], n[key]) {
            result[key] = n[key] ?? FieldValue.delete()
        }

        // Мојот багаж и стил (само мојот дел, не на другите)
        let oldPersonal = (o["personal"] as? [String: Any])?[myUID]
        let newPersonal = (n["personal"] as? [String: Any])?[myUID]
        if let newPersonal, !same(oldPersonal, newPersonal) {
            result["personal.\(myUID)"] = newPersonal
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
        data["editedBy"] = uid   // за известувањата: кој ја направи промената
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
                "updatedAt": Date().timeIntervalSince1970,
                "editedBy": uid
            ])
        }
    }

    func push(old: Trip, new: Trip) {
        guard new.isCloud else { return }
        var changes = CloudCodec.updates(old: old, new: new, myUID: uid)
        guard !changes.isEmpty else { return }
        changes["editedBy"] = uid   // за известувањата: кој ја направи промената
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

    /// При бришење на акаунтот: профилот и клучевите за пребарување.
    func deleteProfile(keys: [String]) async {
        // И клучевите запишани во профилот (бројот можеби не е на овој телефон по повторна најава)
        var keys = Set(keys)
        if let profile = try? await db.collection("users").document(uid).getDocument().data() {
            if let hash = profile["phoneHash"] as? String { keys.insert("p_" + hash) }
            if let hash = profile["emailHash"] as? String { keys.insert("e_" + hash) }
        }
        for key in keys {
            let doc = db.collection("lookup").document(key)
            if let existing = try? await doc.getDocument(), (existing.data()?["uid"] as? String) == uid {
                try? await doc.delete()
            }
        }
        try? await db.collection("users").document(uid).delete()
    }

    /// Ги регистрира моите клучеви за пријателите да можат да ме најдат.
    /// Број што е веќе на друг акаунт не се презема (ниту поканите за него). Враќа кои клучеви се мои.
    @discardableResult
    func registerProfile(name: String, phone: String? = nil, phoneKey: String?, emailKey: String?) async -> Set<String> {
        // Прво клучевите — правилата бараат бројот во профилот да е мој во /lookup
        var mine: Set<String> = []
        for key in [phoneKey, emailKey].compactMap({ $0 }) {
            let doc = db.collection("lookup").document(key)
            if let existing = try? await doc.getDocument(), existing.exists {
                if (existing.data()?["uid"] as? String) == uid { mine.insert(key) }
                continue // зафатен од друг акаунт
            }
            if (try? await doc.setData(["uid": uid])) != nil { mine.insert(key) }
        }

        let userRef = db.collection("users").document(uid)
        var user: [String: Any] = ["name": name]
        if let phoneKey {
            let previous = (try? await userRef.getDocument())?.data()?["phoneHash"] as? String
            if mine.contains(phoneKey) {
                user["phoneHash"] = PhoneID.bareHash(phoneKey)
                // Самиот број — во профилот што го гледа само сопственикот, за да се врати по повторна најава
                if let phone { user["phone"] = phone }
                // Сменет број: стариот се ослободува за друг акаунт
                if let previous, "p_" + previous != phoneKey { await release("p_" + previous) }
            } else if previous == PhoneID.bareHash(phoneKey) {
                // Стар запис со туѓ број — се трга
                user["phoneHash"] = FieldValue.delete()
                user["phone"] = FieldValue.delete()
            }
        }
        if let emailKey, mine.contains(emailKey) { user["emailHash"] = PhoneID.bareHash(emailKey) }
        try? await userRef.setData(user, merge: true)
        return mine
    }

    /// Бројот е тргнат од профилот: пријателите повеќе не те наоѓаат по него, а може да го внесе друг.
    func removePhone() async {
        let userRef = db.collection("users").document(uid)
        if let previous = (try? await userRef.getDocument())?.data()?["phoneHash"] as? String {
            await release("p_" + previous)
        }
        try? await userRef.setData(["phoneHash": FieldValue.delete(), "phone": FieldValue.delete()], merge: true)
    }

    /// Клучот за пребарување се брише само ако е мој.
    private func release(_ key: String) async {
        let doc = db.collection("lookup").document(key)
        if let existing = try? await doc.getDocument(), (existing.data()?["uid"] as? String) == uid {
            try? await doc.delete()
        }
    }

    /// Покана за некој што уште нема акаунт — чека додека не се регистрира.
    func createInvites(trip: Trip, keys: [String], fromName: String) async {
        for key in keys {
            try? await db.collection("invites").document(key)
                .collection("trips").document(trip.id.uuidString)
                .setData([
                    "fromName": fromName,
                    "destination": trip.placeSummary,
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
                        "updatedAt": Date().timeIntervalSince1970,
                        "editedBy": uid
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
                        try await tripRef.updateData(["companions": list, "editedBy": uid])
                    }
                } catch {
                    print("Valise: join failed — \(error)")
                }
                try? await invite.reference.delete()
            }
        }
    }
}
