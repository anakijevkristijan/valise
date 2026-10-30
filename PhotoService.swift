import UIKit
import Vision

/// Автор и лиценца на фотографија од Wikimedia Commons (мора да се наведат).
struct PhotoCredit: Codable, Hashable {
    let author: String
    let license: String

    var text: String {
        L("Фото: \(author) · \(license) · Wikimedia Commons", "Photo: \(author) · \(license) · Wikimedia Commons")
    }
}

/// Фотографии од дестинацијата, бесплатно и без клуч:
/// Wikidata (според GeoNames ID) → главна слика (P18) + категорија на Wikimedia Commons (P373).
/// Сè се чува во меморија и на диск.
/// Секоја слика се проверува на самиот телефон (Vision) — ако има лице или човек, не се прикажува.
enum PhotoService {

    private static let userAgent = "Tripdrobe/2.6 (iOS travel packing app)"
    private static let maxCandidates = 48
    /// Колку проверени фотографии бараме за Story (секогаш истиот број ако ги има).
    static let storyTarget = 8

    /// Во меморија најмногу неколку десетици слики (системот сам ослободува кога треба).
    private static let imageMemory: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 24
        return cache
    }()
    @MainActor private static var rejected: Set<String> = PhotoService.loadRejected()
    @MainActor private static var candidateMemory: [Int: [URL]] = [:]
    @MainActor private static var credits: [String: PhotoCredit] = PhotoService.loadCredits()

    /// Автор и лиценца (за потпис на сликата).
    @MainActor static func credit(for url: URL) -> PhotoCredit? {
        credits[url.absoluteString]
    }

    @MainActor private static func remember(credits new: [String: PhotoCredit]) {
        guard !new.isEmpty else { return }
        credits.merge(new) { _, latest in latest }
        if let data = try? JSONEncoder().encode(credits) {
            try? data.write(to: creditsFile, options: .atomic)
        }
    }

    private static var creditsFile: URL {
        cacheFolder.appendingPathComponent("credits.json")
    }

    private static func loadCredits() -> [String: PhotoCredit] {
        guard let data = try? Data(contentsOf: creditsFile),
              let saved = try? JSONDecoder().decode([String: PhotoCredit].self, from: data) else { return [:] }
        return saved
    }

    // MARK: Јавно

    /// Главната фотографија: првата од кандидатите без луѓе.
    static func photo(for place: Place) async -> UIImage? {
        for url in loadVerified(place.id).prefix(3) {
            if let loaded = await PhotoService.image(at: url) { return loaded }
        }
        for url in await candidates(for: place).prefix(8) {
            if let loaded = await PhotoService.image(at: url) { return loaded }
        }
        return nil
    }

    /// Фотографија, но најмногу `timeout` секунди чекање.
    static func photo(for place: Place, timeout: Double) async -> UIImage? {
        await withTaskGroup(of: UIImage?.self) { group in
            group.addTask { await PhotoService.photo(for: place) }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// Листа со фотографии за дестинацијата (главната прва).
    /// Извори (паралелно): Wikidata главна слика, категорија на Commons, пребарување по име, фотографии околу координатите.
    static func candidates(for place: Place) async -> [URL] {
        if let cached = await cachedCandidates(place.id) { return cached }
        if let saved = loadSavedCandidates(place.id), saved.count >= storyTarget {
            await remember(saved, for: place.id)
            return saved
        }

        async let geo = geoImages(latitude: place.latitude, longitude: place.longitude)
        // GeoNames бројка постои само за места од Open-Meteo (позитивен id); кај Apple Maps — пребарување по име
        var entity: String? = nil
        if place.id > 0 { entity = await entityID(geonamesID: place.id) }

        var main: URL?
        var fromCategory: [URL] = []
        var fromSearch: [URL] = []
        if let entity {
            async let mainFile = claimString(entity: entity, property: "P18")
            async let category = claimString(entity: entity, property: "P373")
            async let label = englishLabel(entity: entity)
            let (file, cat, name) = await (mainFile, category, label)
            if let file { main = await fileImage(file) }
            async let catImages = categoryImages(cat)
            async let searched = searchImages(name ?? place.name)
            fromCategory = await catImages
            fromSearch = await searched
        } else {
            fromSearch = await searchImages(place.name)
        }
        let nearby = await geo

        // Наизменично од секој извор — разновидно, а не 20 слики од иста зграда.
        var urls: [URL] = []
        var seen = Set<String>()
        func add(_ url: URL) {
            let key = url.lastPathComponent.lowercased()
            guard urls.count < maxCandidates, !seen.contains(key) else { return }
            seen.insert(key)
            urls.append(url)
        }
        if let main { add(main) }
        let sources = [fromCategory, fromSearch, nearby]
        let longest = sources.map(\.count).max() ?? 0
        for index in 0..<longest {
            for source in sources where index < source.count {
                add(source[index])
            }
        }

        if !urls.isEmpty {
            await remember(urls, for: place.id)
            saveCandidates(urls, for: place.id)
        }
        return urls
    }

    /// Проверени фотографии (без луѓе) — до `target`, паралелно, и секогаш истите следниот пат.
    /// `onFound` се вика за секоја проверена слика веднаш штом е готова.
    static func verifiedPhotos(for place: Place,
                               target: Int = storyTarget,
                               onFound: @escaping @MainActor (URL, UIImage) -> Void) async -> [URL] {
        var verified: [URL] = []

        // 1. Веќе проверени (од диск) — веднаш
        for url in loadVerified(place.id) {
            guard verified.count < target, let loaded = await PhotoService.image(at: url) else { continue }
            verified.append(url)
            await onFound(url, loaded)
        }
        if verified.count >= target { return verified }

        // 2. Нови кандидати, по 4 истовремено, додека не стигнеме до целта
        let tried = Set(verified)
        var pending = await candidates(for: place).filter { !tried.contains($0) }.makeIterator()

        await withTaskGroup(of: (URL, UIImage?).self) { group in
            for _ in 0..<4 {
                guard let url = pending.next() else { break }
                group.addTask { (url, await PhotoService.image(at: url)) }
            }
            while let result = await group.next() {
                if let loaded = result.1 {
                    verified.append(result.0)
                    await onFound(result.0, loaded)
                    saveVerified(verified, for: place.id)
                    if verified.count >= target {
                        group.cancelAll()
                        break
                    }
                }
                if let url = pending.next() {
                    group.addTask { (url, await PhotoService.image(at: url)) }
                }
            }
        }
        return verified
    }

    /// Однапред (кога се отвора патувањето) — Story потоа се отвора веднаш.
    static func prefetchStory(for place: Place) async {
        _ = await verifiedPhotos(for: place) { _, _ in }
    }

    /// Една фотографија од URL (кеширана). nil ако не се вчита или ако на неа има луѓе.
    static func image(at url: URL) async -> UIImage? {
        if await isRejected(url) { return nil }
        if let cached = await cachedImage(url) { return cached }
        let file = cacheFile(for: url)
        if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
            await remember(image, for: url)
            return image
        }
        guard let data = await get(url, timeout: 12), let image = UIImage(data: data) else { return nil }
        if await containsPeople(image) {
            await reject(url)
            return nil
        }
        try? data.write(to: file, options: .atomic)
        await remember(image, for: url)
        return image
    }

    // MARK: Без луѓе (Vision, на телефонот)

    /// true ако има лице (било која големина) или човечка фигура поголема од ~1.5% од сликата.
    static func containsPeople(_ image: UIImage) async -> Bool {
        guard let cgImage = image.cgImage else { return false }
        return await Task.detached(priority: .userInitiated) { () -> Bool in
            let faces = VNDetectFaceRectanglesRequest()
            let humans = VNDetectHumanRectanglesRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([faces, humans])
            } catch {
                return false
            }
            if let found = faces.results, !found.isEmpty { return true }
            let people = (humans.results ?? []).filter { observation in
                observation.confidence > 0.3 &&
                observation.boundingBox.width * observation.boundingBox.height > 0.015
            }
            return !people.isEmpty
        }.value
    }

    @MainActor private static func isRejected(_ url: URL) -> Bool {
        rejected.contains(url.absoluteString)
    }

    @MainActor private static func reject(_ url: URL) {
        rejected.insert(url.absoluteString)
        if let data = try? JSONEncoder().encode(Array(rejected)) {
            try? data.write(to: rejectedFile, options: .atomic)
        }
    }

    private static var rejectedFile: URL {
        cacheFolder.appendingPathComponent("rejected.json")
    }

    private static func loadRejected() -> Set<String> {
        guard let data = try? Data(contentsOf: rejectedFile),
              let list = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(list)
    }

    // MARK: Wikidata

    private struct SearchResponse: Decodable {
        struct Query: Decodable {
            struct Hit: Decodable { let title: String }
            let search: [Hit]
        }
        let query: Query?
    }

    private struct ClaimsResponse: Decodable {
        struct Claim: Decodable {
            struct Snak: Decodable {
                struct DataValue: Decodable { let value: String? }
                let datavalue: DataValue?
            }
            let mainsnak: Snak
        }
        let claims: [String: [Claim]]?
    }

    private struct LabelsResponse: Decodable {
        struct Entity: Decodable {
            struct Label: Decodable { let value: String }
            let labels: [String: Label]?
        }
        let entities: [String: Entity]?
    }

    private static func entityID(geonamesID: Int) async -> String? {
        let url = api("https://www.wikidata.org/w/api.php", [
            "action": "query", "list": "search",
            "srsearch": "haswbstatement:P1566=\(geonamesID)",
            "srlimit": "1", "format": "json"
        ])
        guard let url, let data = await get(url, timeout: 6),
              let decoded = try? JSONDecoder().decode(SearchResponse.self, from: data) else { return nil }
        return decoded.query?.search.first?.title
    }

    private static func claimString(entity: String, property: String) async -> String? {
        let url = api("https://www.wikidata.org/w/api.php", [
            "action": "wbgetclaims", "entity": entity, "property": property, "format": "json"
        ])
        guard let url, let data = await get(url, timeout: 6),
              let decoded = try? JSONDecoder().decode(ClaimsResponse.self, from: data) else { return nil }
        return decoded.claims?[property]?.first?.mainsnak.datavalue?.value
    }

    private static func englishLabel(entity: String) async -> String? {
        let url = api("https://www.wikidata.org/w/api.php", [
            "action": "wbgetentities", "ids": entity, "props": "labels", "languages": "en", "format": "json"
        ])
        guard let url, let data = await get(url, timeout: 6),
              let decoded = try? JSONDecoder().decode(LabelsResponse.self, from: data) else { return nil }
        return decoded.entities?[entity]?.labels?["en"]?.value
    }

    // MARK: Wikimedia Commons

    private struct CommonsResponse: Decodable {
        struct Query: Decodable {
            struct Page: Decodable {
                struct Info: Decodable {
                    let thumburl: String?
                    let width: Int?
                    let height: Int?
                    let mime: String?
                    let extmetadata: [String: Meta]?
                }
                /// Вредност од extmetadata (само текст; друго се игнорира).
                struct Meta: Decodable {
                    let value: String?
                    private enum CodingKeys: String, CodingKey { case value }
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        value = try? container.decode(String.self, forKey: .value)
                    }
                }
                let title: String?
                let imageinfo: [Info]?
            }
            let pages: [Page]?
        }
        let query: Query?
    }

    private static func categoryImages(_ category: String?) async -> [URL] {
        guard let category else { return [] }
        let url = api("https://commons.wikimedia.org/w/api.php", [
            "action": "query", "generator": "categorymembers",
            "gcmtitle": "Category:\(category)", "gcmtype": "file", "gcmlimit": "40",
            "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata", "iiextmetadatafilter": "Artist|LicenseShortName", "iiurlwidth": "1280",
            "format": "json", "formatversion": "2"
        ])
        return await commonsImages(url)
    }

    private static func searchImages(_ term: String) async -> [URL] {
        let url = api("https://commons.wikimedia.org/w/api.php", [
            "action": "query", "generator": "search", "gsrnamespace": "6",
            "gsrsearch": "\"\(term)\" filetype:bitmap", "gsrlimit": "30",
            "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata", "iiextmetadatafilter": "Artist|LicenseShortName", "iiurlwidth": "1280",
            "format": "json", "formatversion": "2"
        ])
        return await commonsImages(url)
    }

    /// Фотографии снимени околу дестинацијата (до 10 km).
    private static func geoImages(latitude: Double, longitude: Double) async -> [URL] {
        let url = api("https://commons.wikimedia.org/w/api.php", [
            "action": "query", "generator": "geosearch",
            "ggscoord": "\(latitude)|\(longitude)", "ggsradius": "10000",
            "ggsnamespace": "6", "ggslimit": "50",
            "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata", "iiextmetadatafilter": "Artist|LicenseShortName", "iiurlwidth": "1280",
            "format": "json", "formatversion": "2"
        ])
        return await commonsImages(url)
    }

    private static let excluded = [
        "map", "flag", "coat", "logo", "emblem", "plan", "diagram", "karta", "grb", "zname",
        "portrait", "people", "person", "selfie", "wedding", "festival", "concert", "family",
        "man ", "woman", "girl", "boy", "child", "kids", "crowd", "tourists", "player", "team",
        "mayor", "president", "minister", "meeting", "visit", "ceremony", "parade", "protest"
    ]

    private static func commonsImages(_ url: URL?) async -> [URL] {
        guard let url, let data = await get(url, timeout: 8),
              let decoded = try? JSONDecoder().decode(CommonsResponse.self, from: data) else { return [] }
        var found: [URL] = []
        var newCredits: [String: PhotoCredit] = [:]
        for page in decoded.query?.pages ?? [] {
            guard let info = page.imageinfo?.first,
                  info.mime == "image/jpeg",
                  (info.width ?? 0) >= 900,
                  (info.height ?? 0) >= 600,
                  let thumb = info.thumburl,
                  let imageURL = URL(string: thumb) else { continue }
            let title = (page.title ?? "").lowercased()
            if excluded.contains(where: { title.contains($0) }) { continue }
            found.append(imageURL)
            newCredits[imageURL.absoluteString] = credit(from: info)
        }
        await remember(credits: newCredits)
        return found
    }

    /// Една датотека по име (главната слика од Wikidata) — со автор и лиценца.
    private static func fileImage(_ fileName: String) async -> URL? {
        let url = api("https://commons.wikimedia.org/w/api.php", [
            "action": "query", "titles": "File:\(fileName)",
            "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata",
            "iiextmetadatafilter": "Artist|LicenseShortName", "iiurlwidth": "1280",
            "format": "json", "formatversion": "2"
        ])
        return await commonsImages(url).first
    }

    private static func credit(from info: CommonsResponse.Query.Page.Info) -> PhotoCredit {
        let rawAuthor = info.extmetadata?["Artist"]?.value ?? ""
        var author = rawAuthor
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if author.isEmpty { author = L("непознат автор", "unknown author") }
        if author.count > 42 { author = String(author.prefix(40)) + "…" }
        let license = info.extmetadata?["LicenseShortName"]?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "CC"
        return PhotoCredit(author: author, license: license.isEmpty ? "CC" : license)
    }


    // MARK: Помошни

    private static func api(_ base: String, _ params: [String: String]) -> URL? {
        guard var components = URLComponents(string: base) else { return nil }
        components.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components.url
    }

    private static func get(_ url: URL, timeout: Double) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        guard let result = try? await URLSession.shared.data(for: request),
              let http = result.1 as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else { return nil }
        return result.0
    }

    @MainActor private static func cachedImage(_ url: URL) -> UIImage? { imageMemory.object(forKey: url as NSURL) }
    @MainActor private static func remember(_ image: UIImage, for url: URL) { imageMemory.setObject(image, forKey: url as NSURL) }
    @MainActor private static func cachedCandidates(_ id: Int) -> [URL]? { candidateMemory[id] }
    @MainActor private static func remember(_ urls: [URL], for id: Int) { candidateMemory[id] = urls }

    private static var cacheFolder: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("photos-v2", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func cacheFile(for url: URL) -> URL {
        var hash: UInt64 = 5381
        for byte in url.absoluteString.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
        return cacheFolder.appendingPathComponent(String(hash, radix: 16) + ".jpg")
    }

    private static func listFile(_ id: Int) -> URL {
        cacheFolder.appendingPathComponent("list-v4-\(id).json")
    }

    private static func verifiedFile(_ id: Int) -> URL {
        cacheFolder.appendingPathComponent("verified-v2-\(id).json")
    }

    private static func saveVerified(_ urls: [URL], for id: Int) {
        if let data = try? JSONEncoder().encode(urls.map(\.absoluteString)) {
            try? data.write(to: verifiedFile(id), options: .atomic)
        }
    }

    private static func loadVerified(_ id: Int) -> [URL] {
        guard let data = try? Data(contentsOf: verifiedFile(id)),
              let strings = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return strings.compactMap(URL.init(string:))
    }

    private static func saveCandidates(_ urls: [URL], for id: Int) {
        let strings = urls.map(\.absoluteString)
        if let data = try? JSONEncoder().encode(strings) {
            try? data.write(to: listFile(id), options: .atomic)
        }
    }

    private static func loadSavedCandidates(_ id: Int) -> [URL]? {
        guard let data = try? Data(contentsOf: listFile(id)),
              let strings = try? JSONDecoder().decode([String].self, from: data) else { return nil }
        return strings.compactMap(URL.init(string:))
    }
}
