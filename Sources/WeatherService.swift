import Foundation

/// Open-Meteo (open-meteo.com) — бесплатно, без API клуч.
/// • Пребарување места: GeoNames преку Open-Meteo Geocoding
/// • Прогноза: модели на националните служби (ECMWF, DWD, NOAA…), до 16 дена
/// • Денови подалеку од прогнозата: истите датуми лани од архивата ERA5 (Copernicus/ECMWF)
enum WeatherService {

    static let forecastHorizonDays = 15
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
            forecast = (try? await fetchDaily(base: "https://api.open-meteo.com/v1/forecast",
                                              place: place, from: from, to: to,
                                              includeProbability: true, shiftYears: 0)) ?? []
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
                let archive = (try? await fetchDaily(base: "https://archive-api.open-meteo.com/v1/archive",
                                                     place: place, from: lyStart, to: lyEnd,
                                                     includeProbability: false, shiftYears: 1)) ?? []
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
