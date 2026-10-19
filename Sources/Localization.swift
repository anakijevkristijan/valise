import Foundation

/// Јазик на апликацијата. Се чува во UserDefaults; стандардно македонски.
enum AppLanguage: String, CaseIterable, Identifiable {
    case mk, en

    static let storageKey = "appLanguage"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .mk: return "Македонски"
        case .en: return "English"
        }
    }

    var shortName: String { rawValue.uppercased() }

    var locale: Locale {
        Locale(identifier: self == .mk ? "mk_MK" : "en_GB")
    }

    static var current: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let language = AppLanguage(rawValue: raw) {
            return language
        }
        return .mk
    }
}

/// Краток превод: L("Македонски", "English")
func L(_ mk: String, _ en: String) -> String {
    AppLanguage.current == .mk ? mk : en
}
