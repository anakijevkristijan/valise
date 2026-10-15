import UIKit

/// Фотографија од дестинацијата: Wikidata (според GeoNames ID) → слика од Wikimedia Commons.
/// Бесплатно, без клуч. Се чува во меморија и на диск по првото симнување.
enum PhotoService {

    private static let userAgent = "Valise/1.2 (iOS packing app)"
    private static var memory: [Int: UIImage] = [:]

    /// Фотографија, но најмногу `timeout` секунди чекање.
    static func photo(for place: Place, timeout: Double) async -> UIImage? {
        if let cached = memory[place.id] { return cached }
        return await withTaskGroup(of: UIImage?.self) { group in
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

    static func photo(for place: Place) async -> UIImage? {
        if let cached = memory[place.id] { return cached }

        let cacheFile = cacheURL(for: place.id)
        if let data = try? Data(contentsOf: cacheFile), let image = UIImage(data: data) {
            await remember(image, for: place.id)
            return image
        }

        guard let remote = await imageURL(geonamesID: place.id) else { return nil }
        guard let data = await get(remote, timeout: 10), let image = UIImage(data: data) else { return nil }
        try? data.write(to: cacheFile, options: .atomic)
        await remember(image, for: place.id)
        return image
    }

    @MainActor
    private static func remember(_ image: UIImage, for id: Int) {
        memory[id] = image
    }

    // MARK: Wikidata — брз пат (пребарување + тврдење), без SPARQL

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

    private static func imageURL(geonamesID: Int) async -> URL? {
        // 1) Wikidata елемент според GeoNames ID
        guard var search = URLComponents(string: "https://www.wikidata.org/w/api.php") else { return nil }
        search.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "search"),
            URLQueryItem(name: "srsearch", value: "haswbstatement:P1566=\(geonamesID)"),
            URLQueryItem(name: "srlimit", value: "1"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let searchURL = search.url,
              let searchData = await get(searchURL, timeout: 5),
              let found = try? JSONDecoder().decode(SearchResponse.self, from: searchData),
              let entity = found.query?.search.first?.title else { return nil }

        // 2) Слика (P18) на елементот
        guard var claims = URLComponents(string: "https://www.wikidata.org/w/api.php") else { return nil }
        claims.queryItems = [
            URLQueryItem(name: "action", value: "wbgetclaims"),
            URLQueryItem(name: "entity", value: entity),
            URLQueryItem(name: "property", value: "P18"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let claimsURL = claims.url,
              let claimsData = await get(claimsURL, timeout: 5),
              let decoded = try? JSONDecoder().decode(ClaimsResponse.self, from: claimsData),
              let fileName = decoded.claims?["P18"]?.first?.mainsnak.datavalue?.value else { return nil }

        // 3) Намалена верзија од Commons (1080 px — доволно за Story)
        let underscored = fileName.replacingOccurrences(of: " ", with: "_")
        guard let encoded = underscored.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/\(encoded)?width=1080")
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

    private static func cacheURL(for id: Int) -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("\(id).jpg")
    }
}
