import Foundation

// MARK: - Сезона

enum Season: String, Codable, CaseIterable, Identifiable {
    case spring, summer, autumn, winter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spring: return L("Пролет", "Spring")
        case .summer: return L("Лето", "Summer")
        case .autumn: return L("Есен", "Autumn")
        case .winter: return L("Зима", "Winter")
        }
    }

    var icon: String {
        switch self {
        case .spring: return "camera.macro"
        case .summer: return "sun.max"
        case .autumn: return "leaf"
        case .winter: return "snowflake"
        }
    }

    static func of(_ date: Date) -> Season {
        switch Calendar.current.component(.month, from: date) {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }

    static var current: Season { of(Date()) }
}

// MARK: - Категорија

enum WardrobeCategory: String, Codable, CaseIterable, Identifiable {
    case outerwear, top, dress, bottom, shoes, bag, accessory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .outerwear: return L("Јакни и палта", "Coats and jackets")
        case .top: return L("Горни делови", "Tops")
        case .dress: return L("Фустани", "Dresses")
        case .bottom: return L("Панталони и сукњи", "Trousers and skirts")
        case .shoes: return L("Обувки", "Shoes")
        case .bag: return L("Торби", "Bags")
        case .accessory: return L("Додатоци", "Accessories")
        }
    }

    var shortTitle: String {
        switch self {
        case .outerwear: return L("Јакна", "Jacket")
        case .top: return L("Горно", "Top")
        case .dress: return L("Фустан", "Dress")
        case .bottom: return L("Долно", "Bottom")
        case .shoes: return L("Обувки", "Shoes")
        case .bag: return L("Торба", "Bag")
        case .accessory: return L("Додаток", "Accessory")
        }
    }
}

// MARK: - Парче облека

struct WardrobeItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var category: WardrobeCategory
    var seasons: [Season]
    var createdAt: Date = Date()

    var imageName: String { id.uuidString + ".png" }

    func fits(_ season: Season?) -> Bool {
        guard let season else { return true }
        return seasons.isEmpty || seasons.contains(season)
    }
}

// MARK: - Аутфит

struct Outfit: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var itemIDs: [UUID]
    var createdAt: Date = Date()
}

// MARK: - План по денови (во патувањето)

extension Trip {
    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    /// Секој ден од патувањето.
    var days: [Date] {
        (0..<dayCount).map { startDate.startOfDay.adding(days: $0) }
    }

    var season: Season { Season.of(startDate) }

    func outfitID(on date: Date) -> UUID? {
        outfitPlan?[Trip.dayKey(date)]
    }
}
