import Foundation
import UIKit
import ImageIO

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
                return L("Облеката е околу \(volume) L, а во „\(bagName)“ има место за околу \(room) L облека. Повтори панталони, јакна или обувки - не мора секој ден ново парче.",
                         "Your clothes take about \(volume) L, but “\(bagName)” fits about \(room) L of clothing. Repeat trousers, a jacket or shoes - you don't need a new piece every day.")
            }
            return L("\(pieces) парчиња е многу за \(Fmt.days(days)). Препорака: до \(recommended). Комбинирај ги парчињата во повеќе аутфити.",
                     "\(pieces) pieces is a lot for \(Fmt.days(days)). Suggested: up to \(recommended). Mix pieces into more outfits.")
        case .tight:
            return L("Речиси полно. Уште некое повторување и ќе има место за сувенири.",
                     "Almost full. A few more repeats and there's room for souvenirs.")
        case .ok:
            if repeated > 0 {
                return L("\(repeated) парчиња се повторуваат - паметно спакувано.",
                         "\(repeated) pieces are repeated - smart packing.")
            }
            return L("Има место. Повторувај парчиња за уште полесен куфер.",
                     "Plenty of room. Repeat pieces for an even lighter bag.")
        }
    }

    /// „Јакната и обувките ги облекуваш на пат“
    var travelNote: String? {
        guard !wornOnTravel.isEmpty else { return nil }
        let names = wornOnTravel.map(\.name).joined(separator: L(" и ", " and "))
        return L("Не се бројат во куферот: \(names) - облечи ги на пат.",
                 "Not counted in the bag: \(names) - wear them while travelling.")
    }
}

/// Гардероба: парчиња (стикери) и аутфити. Се чува локално на телефонот.
final class WardrobeStore: ObservableObject {
    @Published private(set) var items: [WardrobeItem] = [] {
        didSet { itemIndex = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }) }
    }
    @Published private(set) var outfits: [Outfit] = [] {
        didSet { outfitIndex = Dictionary(outfits.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }) }
    }

    /// Брзо пребарување по id (наместо низ цела листа).
    private var itemIndex: [UUID: WardrobeItem] = [:]
    private var outfitIndex: [UUID: Outfit] = [:]

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
        itemIndex[id]
    }

    func outfit(_ id: UUID?) -> Outfit? {
        guard let id else { return nil }
        return outfitIndex[id]
    }

    func items(in outfit: Outfit) -> [WardrobeItem] {
        outfit.itemIDs.compactMap { item($0) }
    }

    /// Мала верзија за мрежи, колажи и листи - многу побрзо од целата слика.
    func thumbnail(for item: WardrobeItem) -> UIImage? {
        let key = ("thumb-" + item.imageName) as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let url = folder.appendingPathComponent(item.imageName) as CFURL
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 520
        ]
        guard let source = CGImageSourceCreateWithURL(url, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return image(for: item)
        }
        let thumb = UIImage(cgImage: cgImage)
        cache.setObject(thumb, forKey: key)
        return thumb
    }

    func image(for item: WardrobeItem) -> UIImage? {
        let key = item.imageName as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(item.imageName)),
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    /// Парчињата од групата, подредени по вид (маици, па џемпери…), најновите први.
    func items(in category: WardrobeCategory, season: Season?) -> [WardrobeItem] {
        items.filter { $0.category == category && $0.fits(season) }
            .sorted { lhs, rhs in
                let a = Self.kindOrder(lhs), b = Self.kindOrder(rhs)
                return a == b ? lhs.createdAt > rhs.createdAt : a < b
            }
    }

    /// Редослед по вид (без вид - на крај).
    static func kindOrder(_ item: WardrobeItem) -> Int {
        item.effectiveKind.flatMap { WardrobeKind.allCases.firstIndex(of: $0) } ?? WardrobeKind.allCases.count
    }

    /// Парчиња што уште немаат вид (стара облека што не можеше да се погоди од името).
    var itemsNeedingKind: [WardrobeItem] {
        items.filter(\.needsKind).sorted { $0.createdAt > $1.createdAt }
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
    /// `excludingOutfit` - не ги брои појавувањата на тој аутфит (кога се уредува).
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
                if a != b { return a < b }
                let x = Self.kindOrder(lhs.item), y = Self.kindOrder(rhs.item)
                return x == y ? lhs.item.name < rhs.item.name : x < y
            }
    }

    // MARK: Листата за пакување наспроти аутфитите

    /// За секој ред од листата (маици 5, џемпер / дуксер 2…): колку предлага листата
    /// и колку различни парчиња од аутфитите се бројат токму таму (џемперот - во џемпери, не во маици).
    /// `extra` - парчиња избрани во составувачот (уште не зачувани).
    func targets(for trip: Trip, extra: [UUID] = [], excludingOutfit: UUID? = nil) -> [ClothingTarget] {
        var pieceIDs = Set(wearCounts(for: trip, excludingOutfit: excludingOutfit).keys)
        for id in extra where item(id) != nil { pieceIDs.insert(id) }
        let pieces = pieceIDs.compactMap { item($0) }.sorted { $0.createdAt < $1.createdAt }

        // Колку предлага листата, по ред (само редовите што гардеробата може да ги покрие)
        var need: [String: Int] = [:]
        var order: [String] = []
        for row in trip.items {
            guard let key = row.key, WardrobeKind.coveredKeys.contains(key) else { continue }
            if need[key] == nil { order.append(key) }
            need[key, default: 0] += row.quantity
        }

        // Секое парче во својот ред; ако видот има два можни реда (панталони / долги панталони) - прво во оној што не е полн
        var have: [String: Int] = [:]
        for piece in pieces {
            let candidates = piece.packingKeys.filter { need[$0] != nil }
            guard let first = candidates.first else { continue }
            let key = candidates.first { have[$0, default: 0] < need[$0, default: 0] } ?? first
            have[key, default: 0] += 1
        }

        return order.compactMap { key in
            let wanted = need[key] ?? 0
            let planned = have[key] ?? 0
            // Облека и обувки секогаш; додатоците (очила, накит…) само ако се во некој аутфит
            guard wanted > 0, WardrobeKind.coreKeys.contains(key) || planned > 0 else { return nil }
            return ClothingTarget(key: key, need: wanted, have: planned)
        }
    }

    /// Колку од аутфитите паѓа на секој ред во листата (пр. „Маици“ 3/5, „Џемпер / дуксер“ 1/2).
    func shares(for trip: Trip) -> [UUID: ClothingTarget.Share] {
        var result: [UUID: ClothingTarget.Share] = [:]
        for target in targets(for: trip) {
            let rows = trip.items.filter { $0.key == target.key }
            var remaining = target.have
            for (index, row) in rows.enumerated() {
                let isLast = index == rows.count - 1
                let share = isLast ? remaining : min(remaining, row.quantity)
                remaining -= share
                result[row.id] = ClothingTarget.Share(have: share, need: row.quantity)
            }
        }
        return result
    }

    /// Колку облека ќе носиш и дали собира во куферот.
    /// `extra` - парчиња што уште не се зачувани (во составувачот).
    func load(for trip: Trip, extra: [UUID] = [], excludingOutfit: UUID? = nil) -> OutfitLoad {
        var counts = wearCounts(for: trip, excludingOutfit: excludingOutfit)
        for id in Set(extra) where item(id) != nil {
            counts[id, default: 0] += 1
        }
        let pieces = counts.keys.compactMap { item($0) }.sorted { $0.createdAt < $1.createdAt }

        // Најобемната јакна и најобемните обувки ги облекуваш на пат.
        var worn: [WardrobeItem] = []
        if let jacket = pieces.filter({ $0.category == .outerwear }).max(by: { $0.volume < $1.volume }) { worn.append(jacket) }
        if let shoes = pieces.filter({ $0.category == .shoes }).max(by: { $0.volume < $1.volume }) { worn.append(shoes) }
        let packed = pieces.filter { piece in !worn.contains { $0.id == piece.id } }

        let slotCount = trip.outfitSlots.filter { $0.outfitID != excludingOutfit && outfit($0.outfitID) != nil }.count
            + (extra.isEmpty ? 0 : 1)
        let days = trip.hasLaundry ? min(trip.dayCount, 7) : trip.dayCount

        return OutfitLoad(pieces: pieces.count,
                          repeated: counts.values.filter { $0 > 1 }.count,
                          outfits: slotCount,
                          packedVolume: packed.reduce(0) { $0 + $1.volume },
                          packedWeight: packed.reduce(0) { $0 + $1.weight },
                          capacity: trip.totalUsableVolume * 0.6,
                          recommended: days + max(3, days / 2 + 2),
                          wornOnTravel: worn,
                          days: trip.dayCount,
                          bagName: trip.bagsTitle)
    }

    // MARK: Редови во листата што ги бараат аутфитите

    /// Се менува кога ќе се сменат парчињата во аутфитите на патувањето (или редовите во листата).
    func outfitRowSignature(for trip: Trip) -> String {
        let pieces = wearCounts(for: trip).keys.compactMap { item($0) }
            .map { "\($0.id.uuidString):\($0.effectiveKind?.rawValue ?? $0.category.rawValue)" }
            .sorted()
        let rows = trip.items.map { "\($0.key ?? $0.name):\($0.fromOutfits == true ? 1 : 0)" }.sorted()
        return pieces.joined(separator: ",") + "|" + rows.joined(separator: ",")
    }

    /// Аутфитите имаат парче што листата го нема (пр. сукња, или џемпер на летно патување) → редот сам се додава,
    /// со толку колку што има во аутфитите. Таквите редови сами се ажурираат и тргаат;
    /// штом бројката се смени рачно, стануваат обичен ред. Избришан ред не се враќа.
    @discardableResult
    func syncOutfitRows(_ trip: inout Trip) -> Bool {
        let pieces = wearCounts(for: trip).keys.compactMap { item($0) }
        let normalKeys = Set(trip.items.filter { $0.fromOutfits != true }.compactMap(\.key)
                             + trip.togetherItems.compactMap(\.key))

        var needed: [String: (count: Int, kind: WardrobeKind)] = [:]
        for piece in pieces {
            guard let kind = piece.effectiveKind, let rowKey = kind.newRowKey else { continue }
            if kind.packingKeys.contains(where: { normalKeys.contains($0) }) { continue }
            let current = needed[rowKey]?.count ?? 0
            needed[rowKey] = (count: current + 1, kind: kind)
        }

        var items = trip.items
        var changed = false

        // Постојните редови од аутфитите: нова бројка, или се тргаат ако повеќе не требаат
        for index in items.indices.reversed() where items[index].fromOutfits == true {
            let key = items[index].key ?? ""
            if let entry = needed[key] {
                if items[index].quantity != entry.count {
                    items[index].quantity = entry.count
                    changed = true
                }
                needed.removeValue(forKey: key)
            } else if !items[index].isPacked {
                items.remove(at: index)
                changed = true
            }
        }

        // Нови редови
        let dismissed = Set(trip.dismissedSuggestions.map { $0.lowercased() })
        for (key, entry) in needed.sorted(by: { $0.key < $1.key }) where !dismissed.contains(key.lowercased()) {
            let row = PackingItem(name: Catalog.name(key) ?? entry.kind.title,
                                  category: entry.kind.rowCategory,
                                  quantity: entry.count,
                                  unitVolume: entry.kind.volume,
                                  unitWeight: entry.kind.weight,
                                  key: key,
                                  quantityEdited: true,
                                  fromOutfits: true)
            if let last = items.lastIndex(where: { $0.category == row.category }) {
                items.insert(row, at: last + 1)
            } else {
                items.append(row)
            }
            changed = true
        }

        if changed { trip.items = items }
        return changed
    }

    // MARK: Промени - парчиња

    func add(_ item: WardrobeItem, image: UIImage) {
        // Помал стикер = побрза мрежа и помалку место (провидноста останува).
        let stored = max(image.size.width, image.size.height) > 1000 ? image.normalized(maxSide: 1000) : image
        if let data = stored.pngData() {
            try? data.write(to: folder.appendingPathComponent(item.imageName), options: .atomic)
            cache.setObject(stored, forKey: item.imageName as NSString)
        }
        items.append(item)
        save()
        cloud?.pushItem(item, withImage: true)
    }

    func update(_ item: WardrobeItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        save()
        cloud?.pushItem(item, withImage: false)
    }

    func delete(_ id: UUID) {
        guard let item = self.item(id) else { return }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(item.imageName))
        cache.removeObject(forKey: item.imageName as NSString)
        cache.removeObject(forKey: ("thumb-" + item.imageName) as NSString)
        items.removeAll { $0.id == id }
        var changed: [Outfit] = []
        for index in outfits.indices where outfits[index].itemIDs.contains(id) {
            outfits[index].itemIDs.removeAll { $0 == id }
            changed.append(outfits[index])
        }
        save()
        cloud?.deleteItem(id)
        changed.forEach { cloud?.pushOutfit($0) }
    }

    // MARK: Промени - аутфити

    func save(outfit: Outfit) {
        if let index = outfits.firstIndex(where: { $0.id == outfit.id }) {
            outfits[index] = outfit
        } else {
            outfits.append(outfit)
        }
        save()
        cloud?.pushOutfit(outfit)
    }

    func deleteOutfit(_ id: UUID) {
        outfits.removeAll { $0.id == id }
        save()
        cloud?.deleteOutfit(id)
    }

    // MARK: Облак (акаунт)

    /// Поврзано кога си најавен - секоја промена се зачувува и на акаунтот.
    weak var cloud: PersonalCloud?

    enum CloudState: Equatable {
        case off        // не си најавен - само на телефонот
        case syncing
        case synced
        case failed     // пр. правилата во Firebase не се ажурирани
    }

    @Published var cloudState: CloudState = .off

    /// Парче дојдено од облакот (друг телефон или после повторна најава).
    func applyRemote(_ incoming: WardrobeItem, imageData: Data?) {
        // Од постара верзија (без вид): видот се погодува исто како на овој телефон
        let item = incoming.migratedKind()
        let url = folder.appendingPathComponent(item.imageName)
        if let imageData, !FileManager.default.fileExists(atPath: url.path) {
            try? imageData.write(to: url, options: .atomic)
            cache.removeObject(forKey: item.imageName as NSString)
        }
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            guard items[index] != item else { return }
            items[index] = item
        } else {
            items.append(item)
        }
        save()
    }

    func removeRemoteItem(_ id: UUID) {
        guard let item = self.item(id) else { return }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(item.imageName))
        cache.removeObject(forKey: item.imageName as NSString)
        cache.removeObject(forKey: ("thumb-" + item.imageName) as NSString)
        items.removeAll { $0.id == id }
        save()
    }

    func applyRemote(_ outfit: Outfit) {
        if let index = outfits.firstIndex(where: { $0.id == outfit.id }) {
            guard outfits[index] != outfit else { return }
            outfits[index] = outfit
        } else {
            outfits.append(outfit)
        }
        save()
    }

    func removeRemoteOutfit(_ id: UUID) {
        guard outfits.contains(where: { $0.id == id }) else { return }
        outfits.removeAll { $0.id == id }
        save()
    }

    /// По одјава: гардеробата се брише од телефонот (останува на акаунтот).
    func wipeLocal() {
        items = []
        outfits = []
        cache.removeAllObjects()
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        save()
    }

    /// Сликата смалена за облакот (документ во Firestore е најмногу 1 MB).
    func cloudImageData(for item: WardrobeItem) -> Data? {
        guard let image = self.image(for: item) else { return nil }
        for side in [720, 600, 480, 380, 300] as [CGFloat] {
            let scaled = max(image.size.width, image.size.height) > side ? image.normalized(maxSide: side) : image
            if let data = scaled.pngData(), data.count < 700_000 {
                return data
            }
        }
        return nil
    }

    // MARK: Диск

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        // Постоечката облека добива вид (маица, џемпер, сукња…) според името
        let migrated = saved.items.map { $0.migratedKind() }
        items = migrated
        outfits = saved.outfits
        // (за секој случај - набљудувачите не секогаш се викаат за време на init)
        itemIndex = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        outfitIndex = Dictionary(outfits.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if migrated != saved.items { save() }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(Saved(items: items, outfits: outfits))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Valise: wardrobe save failed - \(error)")
        }
    }
}
