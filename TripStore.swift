import Foundation
import SwiftUI

/// Локално, офлајн складирање на патувањата (JSON во Documents).
final class TripStore: ObservableObject {
    @Published private(set) var trips: [Trip] = []

    private let fileURL: URL
    private var refreshing: Set<UUID> = []

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("valise-trips.json")
        load()
    }

    // MARK: Читање

    var upcoming: [Trip] {
        trips.filter { !$0.isPast }.sorted { $0.startDate < $1.startDate }
    }

    var past: [Trip] {
        trips.filter(\.isPast).sorted { $0.startDate > $1.startDate }
    }

    func trip(_ id: UUID) -> Trip? {
        trips.first { $0.id == id }
    }

    // MARK: Облак

    private(set) var cloud: CloudSync?

    /// Лични податоци на акаунтот (аутфити по денови) — поставено од PersonalCloud.
    weak var personal: PersonalCloud?

    var isSignedIn: Bool { cloud != nil }

    /// По најава: слушај ги заедничките патувања и качи ги локалните.
    func startSync(uid: String) {
        guard cloud?.uid != uid else { return }
        cloud?.stop()
        let sync = CloudSync(uid: uid, store: self)
        cloud = sync
        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        for index in trips.indices where trips[index].ownerUID == nil {
            sync.claim(&trips[index], myName: name)
            let trip = trips[index]
            Task { await sync.upload(trip) }
        }
        save()
        sync.start()
        objectWillChange.send()
    }

    /// По одјава: туѓите патувања се тргаат од телефонот, моите остануваат.
    func stopSync(previousUID: String?) {
        cloud?.stop()
        cloud = nil
        if let previousUID {
            trips.removeAll { $0.ownerUID != nil && $0.ownerUID != previousUID }
        }
        save()
        objectWillChange.send()
    }

    /// Промена што дошла од облакот (без повторно качување).
    func applyRemote(_ trip: Trip) {
        var incoming = trip
        // Моите лични работи за патувањето (аутфити, спакувано, пред излез) — од акаунтот
        if let plan = personal?.cachedPlan(trip.id) {
            Self.overlay(plan, on: &incoming)
        }
        if let index = trips.firstIndex(where: { $0.id == incoming.id }) {
            if trips[index] != incoming { trips[index] = incoming }
        } else {
            trips.append(incoming)
        }
        save()
    }

    /// Лични податоци дојдени од акаунтот (без повторно качување).
    func applyPersonal(_ id: UUID, plan: PersonalCloud.Plan) {
        guard let index = trips.firstIndex(where: { $0.id == id }) else { return }
        var trip = trips[index]
        Self.overlay(plan, on: &trip)
        guard trip != trips[index] else { return }
        trips[index] = trip
        save()
    }

    private static func overlay(_ plan: PersonalCloud.Plan, on trip: inout Trip) {
        trip.outfitPlan = nil
        trip.outfitDays = plan.days.isEmpty ? nil : plan.days
        trip.outfitPacked = plan.packed.isEmpty ? nil : plan.packed
        if let exit = plan.exit, !exit.isEmpty { trip.exitChecklist = exit }
        if let dismissed = plan.dismissed { trip.dismissedSuggestions = dismissed }
    }

    func removeLocal(_ id: UUID) {
        guard trips.contains(where: { $0.id == id }) else { return }
        trips.removeAll { $0.id == id }
        save()
    }

    // MARK: Промени

    func add(_ trip: Trip) {
        var newTrip = trip
        if let cloud {
            cloud.claim(&newTrip, myName: UserDefaults.standard.string(forKey: "userName") ?? "")
        }
        trips.append(newTrip)
        save()
        if let cloud {
            let uploaded = newTrip
            Task { await cloud.upload(uploaded) }
        }
    }

    func mutate(_ id: UUID, _ change: (inout Trip) -> Void) {
        guard let index = trips.firstIndex(where: { $0.id == id }) else { return }
        let before = trips[index]
        change(&trips[index])
        save()
        cloud?.push(old: before, new: trips[index])
        let after = trips[index]
        if before.outfitDays != after.outfitDays || before.outfitPlan != after.outfitPlan
            || before.outfitPacked != after.outfitPacked || before.exitChecklist != after.exitChecklist
            || before.dismissedSuggestions != after.dismissedSuggestions {
            personal?.pushPlan(after)
        }
    }

    func delete(_ id: UUID) {
        guard let trip = self.trip(id) else { return }
        trips.removeAll { $0.id == id }
        save()
        if let cloud {
            Task { await cloud.removeOrLeave(trip) }
        }
        personal?.deletePlan(id)
    }

    /// По одјава: ништо лично не останува на телефонот (сè е на акаунтот).
    func wipeLocal() {
        trips.removeAll()
        refreshing.removeAll()
        save()
        objectWillChange.send()
    }

    func deleteAll() {
        let all = trips
        trips.removeAll()
        save()
        if let cloud {
            Task { for trip in all { await cloud.removeOrLeave(trip) } }
        }
    }

    // MARK: Покана на сопатник

    enum InviteOutcome {
        case joined(String)
        case alreadyIn(String)
        case invited(String, String)
        case isYou
        case failed
    }

    /// Пријател од контакти: ако има акаунт — веднаш е во патувањето; ако нема — покана што го чека.
    @MainActor
    func invite(name: String, phones: [String], emails: [String], to tripID: UUID) async -> InviteOutcome {
        guard let cloud, let current = trip(tripID) else { return .failed }

        let phoneKeys = phones.compactMap { PhoneID.normalize($0) }.map { PhoneID.phoneKey($0) }
        let emailKeys = emails.map { PhoneID.emailKey($0) }
        let keys = Array(Set(phoneKeys)) + Array(Set(emailKeys))
        guard !keys.isEmpty else { return .failed }

        if !current.isCloud, let index = trips.firstIndex(where: { $0.id == tripID }) {
            cloud.claim(&trips[index], myName: UserDefaults.standard.string(forKey: "userName") ?? "")
            save()
        }
        if let latest = trip(tripID), latest.ownerUID == cloud.uid { await cloud.upload(latest) }

        if let uid = await cloud.lookup(keys: keys) {
            if uid == cloud.uid { return .isYou }
            if trip(tripID)?.memberUIDs?.contains(uid) == true { return .alreadyIn(name) }
            mutate(tripID) { t in
                var list = t.companions ?? []
                list.append(Companion(name: name, uid: uid))
                t.companions = list
                var members = t.memberUIDs ?? []
                if !members.contains(uid) { members.append(uid) }
                t.memberUIDs = members
                PackingEngine.ensureTogether(&t)
            }
            return .joined(name)
        }

        mutate(tripID) { t in
            var list = t.companions ?? []
            list.append(Companion(name: name, inviteKey: keys.first))
            t.companions = list
            PackingEngine.ensureTogether(&t)
        }
        let me = UserDefaults.standard.string(forKey: "userName") ?? ""
        if let latest = trip(tripID) {
            await cloud.createInvites(trip: latest, keys: keys, fromName: me)
        }
        return .invited(name, Self.inviteMessage(friend: name, trip: current, me: me))
    }

    /// Порака за пријател што уште нема Valise.
    static func inviteMessage(friend name: String, trip: Trip, me: String) -> String {
        let first = name.split(separator: " ").first.map(String.init) ?? name
        let range = Fmt.range(trip.startDate, trip.endDate)
        return L("Здраво \(first)! ✈︎ Патувам за \(trip.placeSummary) (\(range)) и те додадов во Tripdrobe. Симни ја апликацијата и регистрирај се со твојот број — патувањето и листата ќе те чекаат. — \(me)",
                 "Hi \(first)! ✈︎ I'm going to \(trip.placeSummary) (\(range)) and added you on Tripdrobe. Get the app and sign up with your number — the trip and packing list will be waiting. — \(me)")
    }

    // MARK: Прогноза — се освежува при секое отворање

    /// Освежи го времето за едно патување.
    /// Автоматски најмногу на секои 2 часа (патување подалеку од прогнозата — еднаш дневно),
    /// за да остане во бесплатните 500.000 барања месечно на Apple Weather. „Повлечи надолу“ секогаш освежува.
    @MainActor
    func refreshWeather(_ id: UUID, force: Bool = false) async {
        guard PremiumStore.cachedIsPremium else { return }   // прогнозата е Premium
        guard let current = self.trip(id), !current.isPast else { return }
        if !force, let updated = current.weatherUpdatedAt,
           Date().timeIntervalSince(updated) < Self.autoRefreshInterval(for: current) { return }
        guard !refreshing.contains(id) else { return }
        refreshing.insert(id)
        defer { refreshing.remove(id) }

        let result = await WeatherService.fetchWeather(for: current.allStops)
        guard !result.days.isEmpty else { return }
        // Ако сега не стигнало нешто (пр. без интернет), не ги губи вистинските податоци од претходно:
        // наместо климатска проценка (~) за тој ден останува старата прогноза / лани.
        let previous = Dictionary(current.weather.filter { !$0.isClimate }.map { ($0.date.startOfDay, $0) },
                                  uniquingKeysWith: { first, _ in first })
        let merged = result.days.map { day -> WeatherDay in
            guard day.isClimate, let old = previous[day.date.startOfDay], old.place == day.place else { return day }
            return old
        }
        let gotData = result.days.contains { !$0.isClimate }
        mutate(id) {
            $0.weather = merged
            $0.weatherSource = result.source
            // Само проценка (ништо не стигнало) → не се смета за освежено, пак се пробува при следното отворање
            $0.weatherUpdatedAt = gotData ? Date() : nil
            // Маиците, долгите ракави, џемперите и јакните се усогласуваат со новата прогноза
            PackingEngine.syncWithWeather(&$0)
        }
    }

    private static func autoRefreshInterval(for trip: Trip) -> TimeInterval {
        // Дупки (~) во деновите што можат да имаат податоци → пак за 3 часа
        let checkable = trip.weather.prefix(WeatherService.maxTripDays)
        if checkable.contains(where: \.isClimate) { return 3 * 3600 }
        return trip.daysUntil > WeatherService.forecastHorizonDays ? 24 * 3600 : 2 * 3600
    }

    /// По купување Premium: паметни бројки во сите претстојни патувања (рачно сменетото останува).
    func applySmartQuantities() {
        for trip in upcoming {
            mutate(trip.id) { PackingEngine.applySmartQuantities(&$0) }
        }
    }

    /// При отворање на апликацијата и враќање во неа.
    @MainActor
    func refreshAllUpcoming() async {
        for trip in upcoming {
            await refreshWeather(trip.id)
        }
    }

    // MARK: Диск

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([Trip].self, from: data) {
            trips = decoded
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(trips)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Valise: save failed — \(error)")
        }
    }
}

/// Последниот град од кој тргна — за побрзо следно патување.
enum LastOrigin {
    private static let key = "lastOrigin"

    static func load() -> Place? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Place.self, from: data)
    }

    static func save(_ place: Place?) {
        guard let place, let data = try? JSONEncoder().encode(place) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
