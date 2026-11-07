import SwiftUI
import UIKit

/// Слики за App Store: демо-патувања и демо-гардероба во симулатор (.github/workflows/screenshots.yml).
/// Работи само во Debug изградба и само со аргументот -TripdrobeScreenshots.
/// Во TestFlight и App Store (Release) `isOn` е секогаш false и ништо од ова не се извршува.
enum ScreenshotMode {

    #if DEBUG
    static let isOn = ProcessInfo.processInfo.arguments.contains("-TripdrobeScreenshots")
    #else
    static let isOn = false
    #endif

    /// Екранот што се слика:
    /// home, trip, weather, outfits, bags, packing, day, story, wardrobe, looks,
    /// language, name, age, settings, new (ново патување), offer (понуда за Premium),
    /// friends (сопатници со свои датуми), exit („Пред излез“), dates (календар), edit-bags (багаж).
    static var screen: String {
        guard isOn else { return "" }
        return argument("-screen") ?? "home"
    }

    /// Кој чекор од апликацијата: language → избор на јазик, name → име, age → возраст; инаку почетна.
    static var stage: Int {
        switch screen {
        case "language": return 0
        case "name": return 1
        case "age": return 4
        default: return 3
        }
    }

    /// 0 = Патувања, 1 = Гардероба.
    static var tab: Int {
        ["wardrobe", "looks"].contains(screen) ? 1 : 0
    }

    /// Дали веднаш се отвора главното демо-патување.
    static var opensTrip: Bool {
        ["trip", "friends", "weather", "outfits", "bags", "packing", "exit", "day", "story", "dates", "edit-bags"].contains(screen)
    }

    /// До кој дел од патувањето се лизга екранот.
    static var anchor: String? {
        switch screen {
        case "friends": return "shot-friends"
        case "weather": return "shot-weather"
        case "outfits", "day": return "shot-outfits"
        case "bags": return "shot-bags"
        case "packing", "exit": return "shot-packing"
        default: return nil
        }
    }

    /// Главното демо-патување (Париз).
    private(set) static var heroTripID: UUID?

    private static func argument(_ name: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    // MARK: Подготовка (пред да се создадат складиштата)

    static func prepareDefaults() {
        guard isOn else { return }
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "languageChosen")
        // -lang de → апликацијата на тој јазик (проверка на преводите); стандардно англиски
        let language = argument("-lang").flatMap { AppLanguage(rawValue: $0) } ?? .en
        defaults.set(language.rawValue, forKey: AppLanguage.storageKey)
        defaults.set(argument("-name") ?? "Emma", forKey: "userName")
        defaults.set(true, forKey: AgeGateView.verifiedKey)
        defaults.set(true, forKey: PhoneStepView.askedKey)
        defaults.set(true, forKey: "premiumUnlocked")
        defaults.set(argument("-theme") ?? Palette.classic.id, forKey: Theme.storageKey)
        defaults.set(HomeView.PassFilter.upcoming.rawValue, forKey: "homeFilter")
    }

    // MARK: Демо-податоци

    static func seed(trips store: TripStore, wardrobe: WardrobeStore) {
        guard isOn else { return }
        store.wipeLocal()
        wardrobe.wipeLocal()

        let looks = seedWardrobe(wardrobe)

        let newYork = Place(id: 5128581, name: "New York", region: "New York", country: "United States",
                            countryCode: "US", latitude: 40.7143, longitude: -74.006, timezone: "America/New_York")
        let paris = Place(id: 2988507, name: "Paris", region: "Île-de-France", country: "France",
                          countryCode: "FR", latitude: 48.8534, longitude: 2.3488, timezone: "Europe/Paris")
        let lisbon = Place(id: 2267057, name: "Lisbon", region: "Lisbon", country: "Portugal",
                           countryCode: "PT", latitude: 38.7167, longitude: -9.1333, timezone: "Europe/Lisbon")
        let tokyo = Place(id: 1850147, name: "Tokyo", region: "Tokyo", country: "Japan",
                          countryCode: "JP", latitude: 35.6895, longitude: 139.6917, timezone: "Asia/Tokyo")
        let rome = Place(id: 3169070, name: "Rome", region: "Lazio", country: "Italy",
                         countryCode: "IT", latitude: 41.8919, longitude: 12.5113, timezone: "Europe/Rome")

        // Париз: 6 дена, со пријатели, свежо време (повеќе слоеви, помалку маици)
        var hero = makeTrip(from: newYork, to: paris, startIn: 6, days: 6, airline: "airfrance",
                            activities: [.photo, .walking, .dining, .nightlife], tint: 0,
                            highs: [14, 15, 12, 11, 13, 15], lows: [7, 8, 7, 5, 6, 8],
                            codes: [1, 0, 61, 3, 2, 0], rain: [10, 5, 70, 35, 15, 5], lastYear: false)
        hero.companions = [Companion(name: "Mia Laurent", uid: "demo-mia"),
                           Companion(name: "Leo Brooks", inviteKey: "p_demo")]
        // Мија доаѓа два дена подоцна, од Лондон — свои градови и датуми
        let london = Place(id: 2643743, name: "London", region: "England", country: "United Kingdom",
                           countryCode: "GB", latitude: 51.5085, longitude: -0.1257, timezone: "Europe/London")
        let miaStart = hero.startDate.adding(days: 2)
        hero.memberPlans = ["demo-mia": MemberPlan(origin: london,
                                                   stops: [TripStop(place: paris, startDate: miaStart, endDate: hero.endDate)],
                                                   startDate: miaStart, endDate: hero.endDate)]
        PackingEngine.ensureTogether(&hero)
        if var together = hero.together, let companions = hero.companions {
            for index in together.indices {
                switch index % 3 {
                case 1: together[index].assignee = companions[0].id
                case 2: together[index].assignee = companions[1].id
                default: together[index].assignee = nil
                }
                together[index].isPacked = index % 4 == 0
            }
            hero.together = together
        }
        for index in hero.items.indices where index % 5 < 2 {
            hero.items[index].isPacked = true
        }
        for index in hero.exitChecklist.indices where index < 3 {
            hero.exitChecklist[index].isDone = true
        }
        if !looks.isEmpty {
            var plan: [String: [UUID]] = [:]
            for (offset, date) in hero.days.enumerated() {
                var ids = [looks[offset % looks.count]]
                if offset == 1, looks.count > 1 { ids.append(looks[(offset + 1) % looks.count]) }
                plan[Trip.dayKey(date)] = ids
            }
            hero.outfitDays = plan
        }
        heroTripID = hero.id

        let lisbonTrip = makeTrip(from: newYork, to: lisbon, startIn: 24, days: 5, airline: "tap",
                                  activities: [.walking, .photo, .dining], tint: 1,
                                  highs: [17, 18, 16, 17, 18], lows: [11, 12, 10, 11, 12],
                                  codes: [0, 0, 1, 0, 2], rain: [0, 0, 5, 0, 10], lastYear: true)
        let tokyoTrip = makeTrip(from: newYork, to: tokyo, startIn: 52, days: 9, airline: "jal",
                                 activities: [.walking, .photo, .dining, .work], tint: 2,
                                 highs: [11, 12, 10, 9, 12, 11, 10, 9, 11], lows: [3, 4, 3, 2, 4, 3, 3, 2, 3],
                                 codes: [1, 2, 3, 61, 0, 1, 2, 3, 1], rain: [10, 20, 30, 60, 5, 10, 20, 30, 10],
                                 lastYear: true)
        let romeTrip = makeTrip(from: newYork, to: rome, startIn: 80, days: 5, airline: "ita",
                                activities: [.walking, .dining, .photo], tint: 3,
                                highs: [13, 14, 12, 13, 14], lows: [4, 5, 4, 3, 5],
                                codes: [0, 0, 1, 0, 0], rain: [0, 0, 5, 0, 0], lastYear: true)

        for trip in [hero, lisbonTrip, tokyoTrip, romeTrip] {
            store.add(trip)
        }
    }

    private static func makeTrip(from origin: Place, to destination: Place, startIn: Int, days: Int,
                                 airline airlineID: String, activities: [Activity], tint: Int,
                                 highs: [Double], lows: [Double], codes: [Int], rain: [Int],
                                 lastYear: Bool) -> Trip {
        let start = Date().startOfDay.adding(days: startIn)
        let end = start.adding(days: days - 1)
        let included = Airlines.find(airlineID)?.bags.filter(\.isFree) ?? []
        let bags = included.isEmpty ? Array((Airlines.find(airlineID)?.bags ?? []).prefix(1)) : included
        let primary = bags.max { $0.volume < $1.volume }
            ?? BagSpec(title: "Cabin bag", height: 55, width: 40, depth: 20, weightLimit: 10, kind: .cabin)

        var trip = Trip(origin: origin,
                        destination: destination,
                        startDate: start,
                        endDate: end,
                        transport: .plane,
                        airlineID: airlineID,
                        bag: primary,
                        activities: Activity.allCases.filter { activities.contains($0) },
                        style: .woman,
                        hasLaundry: false)
        trip.bags = bags.isEmpty ? nil : bags
        trip.weather = (0..<days).map { index in
            WeatherDay(date: start.adding(days: index),
                       maxTemp: highs[index % highs.count],
                       minTemp: lows[index % lows.count],
                       rainChance: rain[index % rain.count],
                       precipitation: rain[index % rain.count] >= 50 ? 3.0 : 0.0,
                       code: codes[index % codes.count],
                       fromLastYear: lastYear)
        }
        trip.weatherSource = lastYear ? .lastYear : .forecast
        trip.weatherUpdatedAt = Date()
        trip.tint = tint
        trip.items = PackingEngine.generate(for: trip)
        trip.exitChecklist = PackingEngine.defaultExitChecklist()
        return trip
    }

    /// Гардероба од Documents/demo-wardrobe (manifest.json + PNG стикери), ако ја има.
    /// Ги враќа аутфитите по редослед.
    private static func seedWardrobe(_ wardrobe: WardrobeStore) -> [UUID] {
        struct Manifest: Decodable {
            struct Piece: Decodable {
                let file: String
                let name: String
                let category: WardrobeCategory
                let seasons: [Season]?
                /// Вид (маица, џемпер…), по избор — инаку се погодува од името.
                let kind: WardrobeKind?
            }
            struct Look: Decodable {
                let name: String
                let pieces: [String]
            }
            let pieces: [Piece]
            let outfits: [Look]
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("demo-wardrobe", isDirectory: true)
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("manifest.json")),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return [] }

        var idsByFile: [String: UUID] = [:]
        for piece in manifest.pieces {
            guard let image = UIImage(contentsOfFile: folder.appendingPathComponent(piece.file).path) else { continue }
            let item = WardrobeItem(name: piece.name, category: piece.kind?.category ?? piece.category,
                                    seasons: piece.seasons ?? [], kindID: piece.kind?.rawValue).migratedKind()
            wardrobe.add(item, image: image)
            idsByFile[piece.file] = item.id
        }

        var looks: [UUID] = []
        for look in manifest.outfits {
            let ids = look.pieces.compactMap { idsByFile[$0] }
            guard !ids.isEmpty else { continue }
            let outfit = Outfit(name: look.name, itemIDs: ids)
            wardrobe.save(outfit: outfit)
            looks.append(outfit.id)
        }
        wardrobe.cloudState = .synced
        return looks
    }
}
