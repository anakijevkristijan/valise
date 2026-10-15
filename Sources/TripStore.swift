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

    // MARK: Промени

    func add(_ trip: Trip) {
        trips.append(trip)
        save()
    }

    func mutate(_ id: UUID, _ change: (inout Trip) -> Void) {
        guard let index = trips.firstIndex(where: { $0.id == id }) else { return }
        change(&trips[index])
        save()
    }

    func delete(_ id: UUID) {
        trips.removeAll { $0.id == id }
        save()
    }

    func deleteAll() {
        trips.removeAll()
        save()
    }

    // MARK: Прогноза — се освежува при секое отворање

    /// Освежи го времето за едно патување. Двојни повици во иста минута се прескокнуваат.
    @MainActor
    func refreshWeather(_ id: UUID, force: Bool = false) async {
        guard let current = self.trip(id), !current.isPast else { return }
        if !force, let updated = current.weatherUpdatedAt, Date().timeIntervalSince(updated) < 60 { return }
        guard !refreshing.contains(id) else { return }
        refreshing.insert(id)
        defer { refreshing.remove(id) }

        let result = await WeatherService.fetchWeather(for: current.destination, from: current.startDate, to: current.endDate)
        guard !result.days.isEmpty else { return }
        mutate(id) {
            $0.weather = result.days
            $0.weatherSource = result.source
            $0.weatherUpdatedAt = Date()
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
