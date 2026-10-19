import Foundation
import UIKit

/// Колку облека носиш според аутфитите и дали ќе собере.
struct OutfitLoad {
    enum Level { case ok, tight, over }

    var pieces: Int
    var repeated: Int
    var outfits: Int
    /// Без јакната и обувките што ги облекуваш на пат.
    var packedVolume: Double
    var packedWeight: Double
    /// Дел од куферот предвиден за облека (литри).
    var capacity: Double
    /// Колку парчиња се разумни за должината на патувањето.
    var recommended: Int
    var wornOnTravel: [WardrobeItem]
    var days: Int
    var bagName: String

    var ratio: Double { capacity > 0 ? packedVolume / capacity : 0 }

    var level: Level {
        if pieces == 0 { return .ok }
        if ratio > 1 || pieces > recommended + recommended / 2 { return .over }
        if ratio > 0.8 || pieces > recommended { return .tight }
        return .ok
    }

    var headline: String {
        switch level {
        case .over: return L("Премногу облека", "Too many clothes")
        case .tight: return L("Тесно", "Getting tight")
        case .ok: return L("Супер мерка", "Just right")
        }
    }

    var advice: String {
        let volume = Int(packedVolume.rounded())
        let room = Int(capacity.rounded())
        switch level {
        case .over:
            if ratio > 1 {
                return L("Облеката е околу \(volume) L, а во „\(bagName)“ има место за околу \(room) L облека. Повтори панталони, јакна или обувки — не мора секој ден ново парче.",
                         "Your clothes take about \(volume) L, but “\(bagName)” fits about \(room) L of clothing. Repeat trousers, a jacket or shoes — you don't need a new piece every day.")
            }
            return L("\(pieces) парчиња е многу за \(Fmt.days(days)). Препорака: до \(recommended). Комбинирај ги парчињата во повеќе аутфити.",
                     "\(pieces) pieces is a lot for \(Fmt.days(days)). Suggested: up to \(recommended). Mix pieces into more outfits.")
        case .tight:
            return L("Речиси полно. Уште некое повторување и ќе има место за сувенири.",
                     "Almost full. A few more repeats and there's room for souvenirs.")
        case .ok:
            if repeated > 0 {
                return L("\(repeated) парчиња се повторуваат — паметно спакувано.",
                         "\(repeated) pieces are repeated — smart packing.")
            }
            return L("Има место. Повторувај парчиња за уште полесен куфер.",
                     "Plenty of room. Repeat pieces for an even lighter bag.")
        }
    }

    /// „Јакната и обувките ги облекуваш на пат“
    var travelNote: String? {
        guard !wornOnTravel.isEmpty else { return nil }
        let names = wornOnTravel.map(\.name).joined(separator: L(" и ", " and "))
        return L("Не се бројат во куферот: \(names) — облечи ги на пат.",
                 "Not counted in the bag: \(names) — wear them while travelling.")
    }
}

/// Гардероба: парчиња (стикери) и аутфити. Се чува локално на телефонот.
final class WardrobeStore: ObservableObject {
    @Published private(set) var items: [WardrobeItem] = []
    @Published private(set) var outfits: [Outfit] = []

    private struct Saved: Codable {
        var items: [WardrobeItem]
        var outfits: [Outfit]
    }

    private let fileURL: URL
    private let folder: URL
    private let cache = NSCache<NSString, UIImage>()

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("valise-wardrobe.json")
        folder = docs.appendingPathComponent("wardrobe", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        load()
    }

    // MARK: Читање

    func item(_ id: UUID) -> WardrobeItem? {
        items.first { $0.id == id }
    }

    func outfit(_ id: UUID?) -> Outfit? {
        guard let id else { return nil }
        return outfits.first { $0.id == id }
    }

    func items(in outfit: Outfit) -> [WardrobeItem] {
        outfit.itemIDs.compactMap { item($0) }
    }

    func image(for item: WardrobeItem) -> UIImage? {
        let key = item.imageName as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(item.imageName)),
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    func items(in category: WardrobeCategory, season: Season?) -> [WardrobeItem] {
        items.filter { $0.category == category && $0.fits(season) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func outfitFits(_ outfit: Outfit, _ season: Season?) -> Bool {
        guard let season else { return true }
        let parts = items(in: outfit)
        return parts.isEmpty || parts.contains { $0.fits(season) }
    }

    /// Во колку зачувани аутфити е парчето.
    func outfitCount(of itemID: UUID, excluding outfitID: UUID? = nil) -> Int {
        outfits.filter { $0.id != outfitID && $0.itemIDs.contains(itemID) }.count
    }

    // MARK: Колку пати е облечено на патувањето

    /// Колку пати парчето се облекува на патувањето (секој аутфит, секој ден = еднаш).
    /// `excludingOutfit` — не ги брои појавувањата на тој аутфит (кога се уредува).
    func usage(of itemID: UUID, in trip: Trip, excludingOutfit: UUID? = nil) -> Int {
        trip.outfitSlots.reduce(0) { count, slot in
            guard slot.outfitID != excludingOutfit, let outfit = self.outfit(slot.outfitID) else { return count }
            return outfit.itemIDs.contains(itemID) ? count + 1 : count
        }
    }

    /// Парчињата од аутфитот што веќе се облечени на патувањето (и колку пати).
    func repeats(in outfit: Outfit, trip: Trip) -> [(item: WardrobeItem, times: Int)] {
        items(in: outfit).compactMap { item in
            let times = usage(of: item.id, in: trip)
            return times > 0 ? (item: item, times: times) : nil
        }
    }

    /// Колку пати секое парче се облекува на патувањето.
    func wearCounts(for trip: Trip, excludingOutfit: UUID? = nil) -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for slot in trip.outfitSlots where slot.outfitID != excludingOutfit {
            guard let outfit = self.outfit(slot.outfitID) else { continue }
            for id in Set(outfit.itemIDs) where item(id) != nil {
                counts[id, default: 0] += 1
            }
        }
        return counts
    }

    /// Сите различни парчиња за пакување, со колку пати се облекуваат.
    func plannedItems(for trip: Trip) -> [(item: WardrobeItem, times: Int)] {
        wearCounts(for: trip)
            .compactMap { id, times in item(id).map { (item: $0, times: times) } }
            .sorted { lhs, rhs in
                let a = WardrobeCategory.allCases.firstIndex(of: lhs.item.category) ?? 0
                let b = WardrobeCategory.allCases.firstIndex(of: rhs.item.category) ?? 0
                return a == b ? lhs.item.name < rhs.item.name : a < b
            }
    }

    /// Колку облека ќе носиш и дали собира во куферот.
    /// `extra` — парчиња што уште не се зачувани (во составувачот).
    func load(for trip: Trip, extra: [UUID] = [], excludingOutfit: UUID? = nil) -> OutfitLoad {
        var counts = wearCounts(for: trip, excludingOutfit: excludingOutfit)
        for id in Set(extra) where item(id) != nil {
            counts[id, default: 0] += 1
        }
        let pieces = counts.keys.compactMap { item($0) }.sorted { $0.createdAt < $1.createdAt }

        // Најобемната јакна и едни обувки ги облекуваш на пат.
        var worn: [WardrobeItem] = []
        if let jacket = pieces.first(where: { $0.category == .outerwear }) { worn.append(jacket) }
        if let shoes = pieces.first(where: { $0.category == .shoes }) { worn.append(shoes) }
        let packed = pieces.filter { piece in !worn.contains { $0.id == piece.id } }

        let outfitCount = trip.outfitSlots.filter { $0.outfitID != excludingOutfit && outfit($0.outfitID) != nil }.count
            + (extra.isEmpty ? 0 : 1)
        let days = trip.hasLaundry ? min(trip.dayCount, 7) : trip.dayCount

        return OutfitLoad(pieces: pieces.count,
                          repeated: counts.values.filter { $0 > 1 }.count,
                          outfits: outfitCount,
                          packedVolume: packed.reduce(0) { $0 + $1.category.volume },
                          packedWeight: packed.reduce(0) { $0 + $1.category.weight },
                          capacity: trip.bag.usableVolume * 0.6,
                          recommended: days + max(3, days / 2 + 2),
                          wornOnTravel: worn,
                          days: trip.dayCount,
                          bagName: trip.bag.displayTitle)
    }

    // MARK: Промени — парчиња

    func add(_ item: WardrobeItem, image: UIImage) {
        // Помал стикер = побрза мрежа и помалку место (провидноста останува).
        let stored = max(image.size.width, image.size.height) > 1000 ? image.normalized(maxSide: 1000) : image
        if let data = stored.pngData() {
            try? data.write(to: folder.appendingPathComponent(item.imageName), options: .atomic)
            cache.setObject(stored, forKey: item.imageName as NSString)
        }
        items.append(item)
        save()
    }

    func update(_ item: WardrobeItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        save()
    }

    func delete(_ id: UUID) {
        guard let item = self.item(id) else { return }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(item.imageName))
        cache.removeObject(forKey: item.imageName as NSString)
        items.removeAll { $0.id == id }
        for index in outfits.indices {
            outfits[index].itemIDs.removeAll { $0 == id }
        }
        save()
    }

    // MARK: Промени — аутфити

    func save(outfit: Outfit) {
        if let index = outfits.firstIndex(where: { $0.id == outfit.id }) {
            outfits[index] = outfit
        } else {
            outfits.append(outfit)
        }
        save()
    }

    func deleteOutfit(_ id: UUID) {
        outfits.removeAll { $0.id == id }
        save()
    }

    // MARK: Диск

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        items = saved.items
        outfits = saved.outfits
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(Saved(items: items, outfits: outfits))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Valise: wardrobe save failed — \(error)")
        }
    }
}
