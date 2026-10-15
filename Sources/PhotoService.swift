import UIKit

/// Фотографија од дестинацијата: Wikidata (според GeoNames ID) → слика од Wikimedia Commons.
/// Бесплатно, без клуч. Се чува локално по првото симнување.
enum PhotoService {

    private static let userAgent = "Valise/1.0 (iOS packing app)"

    static func photo(for place: Place) async -> UIImage? {
        let cacheFile = cacheURL(for: place.id)
        if let data = try? Data(contentsOf: cacheFile), let image = UIImage(data: data) {
            return image
        }
        guard let remote = await imageURL(geonamesID: place.id) else { return nil }

        var request = URLRequest(url: remote)
        request.timeoutInterval = 12
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        guard let result = try? await URLSession.shared.data(for: request),
              let image = UIImage(data: result.0) else { return nil }
        try? result.0.write(to: cacheFile, options: .atomic)
        return image
    }

    private struct SparqlResponse: Decodable {
        struct Results: Decodable { let bindings: [Binding] }
        struct Binding: Decodable { let img: Value? }
        struct Value: Decodable { let value: String }
        let results: Results
    }

    private static func imageURL(geonamesID: Int) async -> URL? {
        let query = "SELECT ?img WHERE { ?item wdt:P1566 \"\(geonamesID)\" . ?item wdt:P18 ?img . } LIMIT 1"
        guard var components = URLComponents(string: "https://query.wikidata.org/sparql") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/sparql-results+json", forHTTPHeaderField: "Accept")

        guard let result = try? await URLSession.shared.data(for: request),
              let decoded = try? JSONDecoder().decode(SparqlResponse.self, from: result.0),
              let raw = decoded.results.bindings.first?.img?.value else { return nil }

        var link = raw.replacingOccurrences(of: "http://", with: "https://")
        link += link.contains("?") ? "&width=1400" : "?width=1400"
        return URL(string: link)
    }

    private static func cacheURL(for id: Int) -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("\(id).jpg")
    }
}
