import Foundation
import UIKit

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

    // MARK: Колку пати е облечено на патувањето

    /// Колку други денови од патувањето го содржат ова парче.
    func usage(of itemID: UUID, in trip: Trip, excluding day: String? = nil) -> Int {
        (trip.outfitPlan ?? [:]).reduce(0) { count, entry in
            guard entry.key != day, let outfit = outfit(entry.value) else { return count }
            return outfit.itemIDs.contains(itemID) ? count + 1 : count
        }
    }

    /// Сите различни парчиња што се во планираните аутфити, со број на денови.
    func plannedItems(for trip: Trip) -> [(item: WardrobeItem, days: Int)] {
        var counts: [UUID: Int] = [:]
        for outfitID in (trip.outfitPlan ?? [:]).values {
            guard let outfit = outfit(outfitID) else { continue }
            for id in Set(outfit.itemIDs) { counts[id, default: 0] += 1 }
        }
        return counts.compactMap { id, days in item(id).map { (item: $0, days: days) } }
            .sorted { lhs, rhs in
                let a = WardrobeCategory.allCases.firstIndex(of: lhs.item.category) ?? 0
                let b = WardrobeCategory.allCases.firstIndex(of: rhs.item.category) ?? 0
                return a == b ? lhs.item.name < rhs.item.name : a < b
            }
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
        guard let item = item(id) else { return }
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
