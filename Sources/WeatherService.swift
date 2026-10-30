import Foundation
import CoreLocation
import MapKit
import WeatherKit

/// Прогноза и пребарување места.
/// • App Store (AppConfig.weatherKitEnabled): Apple Weather (WeatherKit) и Apple Maps (MapKit) —
///   бесплатно до 500.000 барања месечно со платената Apple Developer сметка, дозволено за комерцијална апликација.
/// • Тест-верзии: Open-Meteo (open-meteo.com) — бесплатно само за некомерцијална употреба (CC BY 4.0).
/// • Денови подалеку од прогнозата: истите датуми лани (историски податоци).
enum WeatherService {

    static var forecastHorizonDays: Int { AppConfig.weatherKitEnabled ? 9 : 15 }
    static let maxTripDays = 30

    // MARK: Пребарување места

    private struct GeoResponse: Decodable {
        let results: [GeoResult]?
    }

    private struct GeoResult: Decodable {
        let id: Int
        let name: String
        let latitude: Double
        let longitude: Double
        let country: String?
        let countryCode: String?
        let admin1: String?
        let timezone: String?

        enum CodingKeys: String, CodingKey {
            case id, name, latitude, longitude, country, admin1, timezone
            case countryCode = "country_code"
        }
    }

    static func searchPlaces(_ query: String) async throws -> [Place] {
        let apple = await searchApple(query)
        // Во App Store верзијата само Apple Maps; Open-Meteo само во тест-верзиите како резерва.
        if !apple.isEmpty || AppConfig.weatherKitEnabled { return apple }
        return try await searchOpenMeteo(query)
    }

    /// Apple Maps (MapKit) — без клуч и без трошок.
    private static func searchApple(_ query: String) async -> [Place] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }

        var seen = Set<String>()
        var places: [Place] = []
        for item in response.mapItems {
            let place = Self.place(from: item, name: nil)
            let key = place.name.lowercased() + "|" + place.countryCode
            if seen.contains(key) { continue }
            seen.insert(key)
            places.append(place)
            if places.count >= 8 { break }
        }
        return places
    }

    /// Предлог од автоматското дополнување (MKLocalSearchCompleter) → место со координати.
    static func resolve(_ completion: MKLocalSearchCompletion) async -> Place? {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = .address
        guard let response = try? await MKLocalSearch(request: request).start(),
              let item = response.mapItems.first else { return nil }
        return place(from: item, name: completion.title)
    }

    /// MKMapItem → Place. id е негативен за да не се меша со GeoNames бројките од Open-Meteo.
    static func place(from item: MKMapItem, name: String?) -> Place {
        let mark = item.placemark
        let coordinate = mark.coordinate
        let raw = Int(coordinate.latitude * 1000) &* 100_003 &+ Int(coordinate.longitude * 1000)
        let id = -((raw % 999_999_937 + 999_999_937) % 999_999_937) - 1
        return Place(id: id,
                     name: name ?? item.name ?? mark.locality ?? "",
                     region: mark.administrativeArea,
                     country: mark.country ?? "",
                     countryCode: mark.isoCountryCode ?? "",
                     latitude: coordinate.latitude,
                     longitude: coordinate.longitude,
                     timezone: item.timeZone?.identifier)
    }

    /// Open-Meteo пребарување (само тест-верзии).
    static func searchOpenMeteoIfAllowed(_ query: String) async -> [Place] {
        guard !AppConfig.weatherKitEnabled else { return [] }
        return (try? await searchOpenMeteo(query)) ?? []
    }

    private static func searchOpenMeteo(_ query: String) async throws -> [Place] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: AppLanguage.current.rawValue),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components.url else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(GeoResponse.self, from: data)
        return (response.results ?? []).map { r in
            Place(id: r.id,
                  name: r.name,
                  region: r.admin1,
                  country: r.country ?? "",
                  countryCode: r.countryCode ?? "",
                  latitude: r.latitude,
                  longitude: r.longitude,
                  timezone: r.timezone)
        }
    }

    // MARK: Време за целото патување

    private struct DailyResponse: Decodable {
        struct Daily: Decodable {
            let time: [String]
            let weatherCode: [Double?]?
            let tMax: [Double?]?
            let tMin: [Double?]?
            let rainProbability: [Double?]?
            let precipitation: [Double?]?

            enum CodingKeys: String, CodingKey {
                case time
                case weatherCode = "weather_code"
                case tMax = "temperature_2m_max"
                case tMin = "temperature_2m_min"
                case rainProbability = "precipitation_probability_max"
                case precipitation = "precipitation_sum"
            }
        }
        let daily: Daily?
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Секој ден од патувањето: прогноза каде што ја има, инаку истиот ден лани (означен).
    static func fetchWeather(for place: Place, from start: Date, to end: Date) async -> (days: [WeatherDay], source: WeatherSource) {
        let today = Date().startOfDay
        let horizon = today.adding(days: forecastHorizonDays)
        let tripStart = start.startOfDay
        let tripEnd = min(end.startOfDay, tripStart.adding(days: maxTripDays - 1))

        if tripEnd < today { return ([], .none) }
        let from = max(tripStart, today)

        // 1) Прогноза за деновите во дометот
        var forecast: [WeatherDay] = []
        if from <= horizon {
            let to = min(tripEnd, horizon)
            forecast = (try? await daily(place: place, from: from, to: to, isForecast: true, shiftYears: 0)) ?? []
        }

        // 2) Денови без прогноза
        let covered = Set(forecast.map(\.date))
        var missing: [Date] = []
        var cursor = from
        while cursor <= tripEnd {
            if !covered.contains(cursor) { missing.append(cursor) }
            cursor = cursor.adding(days: 1)
        }

        // 3) Истите датуми лани
        var estimates: [WeatherDay] = []
        if let first = missing.first, let last = missing.last {
            let cal = Calendar.current
            if let lyStart = cal.date(byAdding: .year, value: -1, to: first),
               let lyEnd = cal.date(byAdding: .year, value: -1, to: last) {
                let archive = (try? await daily(place: place, from: lyStart, to: lyEnd, isForecast: false, shiftYears: 1)) ?? []
                let wanted = Set(missing)
                estimates = archive
                    .filter { wanted.contains($0.date) }
                    .map { day in
                        var copy = day
                        copy.fromLastYear = true
                        return copy
                    }
            }
        }

        let all = (forecast + estimates).sorted { $0.date < $1.date }
        let source: WeatherSource
        if all.isEmpty {
            source = .none
        } else if estimates.isEmpty {
            source = .forecast
        } else if forecast.isEmpty {
            source = .lastYear
        } else {
            source = .mixed
        }
        return (all, source)
    }

    /// Дневни податоци од избраниот извор.
    private static func daily(place: Place, from: Date, to: Date, isForecast: Bool, shiftYears: Int) async throws -> [WeatherDay] {
        if AppConfig.weatherKitEnabled {
            return try await fetchWeatherKit(place: place, from: from, to: to, shiftYears: shiftYears)
        }
        return try await fetchDaily(base: isForecast ? "https://api.open-meteo.com/v1/forecast"
                                                     : "https://archive-api.open-meteo.com/v1/archive",
                                    place: place, from: from, to: to,
                                    includeProbability: isForecast, shiftYears: shiftYears)
    }

    /// Apple Weather (WeatherKit): прогноза до 10 дена и историја за изминатите години.
    private static func fetchWeatherKit(place: Place, from: Date, to: Date, shiftYears: Int) async throws -> [WeatherDay] {
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        let end = to.adding(days: 1)
        let forecast = try await WeatherKit.WeatherService.shared.weather(for: location,
                                                                         including: .daily(startDate: from, endDate: end))
        let cal = Calendar.current
        var result: [WeatherDay] = []
        for day in forecast {
            // Пладне на дестинацијата → истиот календарски ден и кај нас
            let local = day.date.addingTimeInterval(12 * 3600).startOfDay
            guard local >= from.startOfDay, local <= to.startOfDay else { continue }
            let shifted = shiftYears == 0 ? local : (cal.date(byAdding: .year, value: shiftYears, to: local) ?? local).startOfDay
            let code = wmoCode(forSymbol: day.symbolName)
            var chance = Int((day.precipitationChance * 100).rounded())
            if shiftYears != 0 && chance == 0 {
                chance = [51, 61, 71, 95].contains(code) ? 70 : 5
            }
            result.append(WeatherDay(date: shifted,
                                     maxTemp: day.highTemperature.converted(to: .celsius).value,
                                     minTemp: day.lowTemperature.converted(to: .celsius).value,
                                     rainChance: chance,
                                     precipitation: nil,
                                     code: code))
        }
        return result
    }

    /// Симболот на Apple → WMO код што го користи остатокот од апликацијата.
    private static func wmoCode(forSymbol symbol: String) -> Int {
        let s = symbol.lowercased()
        if s.contains("bolt") || s.contains("tropicalstorm") || s.contains("hurricane") { return 95 }
        if s.contains("snow") || s.contains("sleet") || s.contains("hail") { return 71 }
        if s.contains("drizzle") { return 51 }
        if s.contains("rain") { return 61 }
        if s.contains("fog") || s.contains("haze") || s.contains("smoke") || s.contains("dust") { return 45 }
        if s.contains("cloud.sun") || s.contains("cloud.moon") { return 2 }
        if s.contains("cloud") { return 3 }
        if s.contains("wind") { return 2 }
        return 0
    }

    private static func fetchDaily(base: String,
                                   place: Place,
                                   from: Date,
                                   to: Date,
                                   includeProbability: Bool,
                                   shiftYears: Int) async throws -> [WeatherDay] {
        var daily = ["weather_code", "temperature_2m_max", "temperature_2m_min", "precipitation_sum"]
        if includeProbability { daily.append("precipitation_probability_max") }

        var components = URLComponents(string: base)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", place.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", place.longitude)),
            URLQueryItem(name: "daily", value: daily.joined(separator: ",")),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "start_date", value: dayFormatter.string(from: from)),
            URLQueryItem(name: "end_date", value: dayFormatter.string(from: to))
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DailyResponse.self, from: data)
        guard let d = response.daily else { return [] }

        let cal = Calendar.current
        var result: [WeatherDay] = []
        for (i, dateString) in d.time.enumerated() {
            guard let parsed = dayFormatter.date(from: dateString),
                  let maxT = value(d.tMax, i),
                  let minT = value(d.tMin, i) else { continue }
            let shifted = shiftYears == 0 ? parsed : (cal.date(byAdding: .year, value: shiftYears, to: parsed) ?? parsed)
            let precipitation = value(d.precipitation, i)
            var chance = value(d.rainProbability, i).map { Int($0.rounded()) }
            if chance == nil, let precipitation {
                chance = precipitation >= 1 ? 70 : (precipitation > 0.2 ? 30 : 5)
            }
            result.append(WeatherDay(date: shifted.startOfDay,
                                     maxTemp: maxT,
                                     minTemp: minT,
                                     rainChance: chance,
                                     precipitation: precipitation,
                                     code: Int(value(d.weatherCode, i) ?? 2)))
        }
        return result
    }

    private static func value(_ array: [Double?]?, _ index: Int) -> Double? {
        guard let array, index < array.count else { return nil }
        return array[index]
    }
}
