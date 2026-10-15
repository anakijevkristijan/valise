import Foundation

/// Open-Meteo: бесплатно, без API клуч.
/// • Пребарување места (на македонски кога има превод)
/// • Прогноза до 16 дена однапред
/// • За подалечни датуми — реално време од истите датуми лани како проценка
enum WeatherService {

    static let forecastHorizonDays = 15

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
            URLQueryItem(name: "language", value: "mk"),
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

    // MARK: Време

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

    static func fetchWeather(for place: Place, from start: Date, to end: Date) async -> (days: [WeatherDay], source: WeatherSource) {
        let today = Date().startOfDay
        let horizon = today.adding(days: forecastHorizonDays)
        let tripStart = start.startOfDay
        let tripEnd = end.startOfDay

        if tripEnd < today {
            return ([], .none)
        }

        if tripStart <= horizon {
            // Реална прогноза за деновите што се во дометот
            let from = max(tripStart, today)
            let to = min(tripEnd, horizon)
            if let days = try? await fetchDaily(base: "https://api.open-meteo.com/v1/forecast",
                                                place: place, from: from, to: to,
                                                includeProbability: true, shiftYears: 0),
               !days.isEmpty {
                return (days, .forecast)
            }
        } else {
            // Предалеку за прогноза → истите датуми лани како проценка
            let cappedEnd = min(tripEnd, tripStart.adding(days: forecastHorizonDays))
            let cal = Calendar.current
            if let lyStart = cal.date(byAdding: .year, value: -1, to: tripStart),
               let lyEnd = cal.date(byAdding: .year, value: -1, to: cappedEnd),
               let days = try? await fetchDaily(base: "https://archive-api.open-meteo.com/v1/archive",
                                                place: place, from: lyStart, to: lyEnd,
                                                includeProbability: false, shiftYears: 1),
               !days.isEmpty {
                return (days, .lastYear)
            }
        }
        return ([], .none)
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

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(DailyResponse.self, from: data)
        guard let d = response.daily else { return [] }

        let cal = Calendar.current
        var result: [WeatherDay] = []
        for (i, dateString) in d.time.enumerated() {
            guard let parsed = dayFormatter.date(from: dateString),
                  let maxT = value(d.tMax, i),
                  let minT = value(d.tMin, i) else { continue }
            let date = shiftYears == 0 ? parsed : (cal.date(byAdding: .year, value: shiftYears, to: parsed) ?? parsed)
            let precipitation = value(d.precipitation, i)
            var chance = value(d.rainProbability, i).map { Int($0.rounded()) }
            if chance == nil, let precipitation {
                // Архивата нема веројатност — грубо ја изведуваме од врнежите
                chance = precipitation >= 1 ? 70 : (precipitation > 0.2 ? 30 : 5)
            }
            result.append(WeatherDay(date: date.startOfDay,
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
