import Foundation
import CryptoKit

/// Тековната сесија (најавен акаунт).
enum Session {
    static var uid: String?
}

/// Телефонски броеви и е-пошти → приватни клучеви за пребарување.
/// Во базата никогаш не се чуваат самите броеви, само SHA-256 отпечаток.
enum PhoneID {

    static let phoneStorageKey = "userPhone"

    private static let callingCodes: [String: String] = [
        "MK": "389", "RS": "381", "BG": "359", "GR": "30", "AL": "355", "XK": "383",
        "ME": "382", "BA": "387", "HR": "385", "SI": "386", "RO": "40", "HU": "36",
        "TR": "90", "DE": "49", "AT": "43", "CH": "41", "IT": "39", "FR": "33",
        "ES": "34", "PT": "351", "NL": "31", "BE": "32", "GB": "44", "IE": "353",
        "SE": "46", "NO": "47", "DK": "45", "FI": "358", "PL": "48", "CZ": "420",
        "SK": "421", "US": "1", "CA": "1", "AU": "61", "AE": "971",
        "MC": "377", "LU": "352", "LI": "423", "IS": "354", "EE": "372", "LV": "371", "LT": "370",
        "UA": "380", "MD": "373", "CY": "357", "MT": "356", "IL": "972", "SA": "966", "QA": "974",
        "KW": "965", "BH": "973", "OM": "968", "EG": "20", "MA": "212", "TN": "216", "ZA": "27",
        "NG": "234", "KE": "254", "IN": "91", "PK": "92", "CN": "86", "HK": "852", "TW": "886",
        "JP": "81", "KR": "82", "SG": "65", "MY": "60", "TH": "66", "VN": "84", "PH": "63",
        "ID": "62", "NZ": "64", "MX": "52", "BR": "55", "AR": "54", "CL": "56", "CO": "57",
        "PE": "51", "GE": "995", "AM": "374", "AZ": "994"
    ]

    /// Земјите за избор на повикувачки код, по азбучен ред на тековниот јазик.
    static var regions: [String] {
        callingCodes.keys.sorted { regionName($0) < regionName($1) }
    }

    static func callingCode(for region: String) -> String {
        callingCodes[region] ?? "389"
    }

    static func regionName(_ region: String) -> String {
        AppLanguage.current.locale.localizedString(forRegionCode: region) ?? region
    }

    static func flag(_ region: String) -> String {
        var result = ""
        for scalar in region.uppercased().unicodeScalars {
            if let flagScalar = UnicodeScalar(127397 + scalar.value) {
                result.unicodeScalars.append(flagScalar)
            }
        }
        return result
    }

    /// Код на земјата + локален број → „+38970123456“ (без почетната нула). Празно ако нема цифри.
    static func compose(region: String, local: String) -> String {
        var digits = local.filter { $0.isASCII && $0.isNumber }
        while digits.hasPrefix("0") { digits.removeFirst() }
        return digits.isEmpty ? "" : "+" + callingCode(for: region) + digits
    }

    /// „+38970123456“ → („MK“, „70123456“). Број без код → земјата на телефонот и бројот каков што е.
    static func split(_ full: String) -> (region: String, local: String) {
        let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
        var digits = trimmed.filter { $0.isASCII && $0.isNumber }
        let international = trimmed.hasPrefix("+") || trimmed.hasPrefix("00")
        if trimmed.hasPrefix("00"), digits.count >= 2 { digits.removeFirst(2) }
        guard international, !digits.isEmpty else { return (defaultRegion, trimmed) }

        let preferred = defaultRegion
        let preferredCode = callingCode(for: preferred)
        if digits.hasPrefix(preferredCode) {
            return (preferred, String(digits.dropFirst(preferredCode.count)))
        }
        // Најдолгиот код што одговара (за +1 — САД)
        let ordered = callingCodes.sorted { a, b in
            if a.value.count != b.value.count { return a.value.count > b.value.count }
            if a.key == "US" { return true }
            if b.key == "US" { return false }
            return a.key < b.key
        }
        if let match = ordered.first(where: { digits.hasPrefix($0.value) }) {
            return (match.key, String(digits.dropFirst(match.value.count)))
        }
        return (preferred, digits)
    }

    /// Земјата на телефонот — од неа се зема почетниот код (+389 во Македонија).
    static var defaultRegion: String {
        let region = Locale.current.region?.identifier ?? "MK"
        return callingCodes[region] != nil ? region : "MK"
    }

    /// Повикувачки код: од мојот број ако го имам, инаку од регионот на телефонот.
    static var defaultCallingCode: String {
        if let mine = UserDefaults.standard.string(forKey: phoneStorageKey), mine.hasPrefix("+") {
            let digits = String(mine.dropFirst())
            if let match = Set(callingCodes.values).sorted(by: { $0.count > $1.count }).first(where: { digits.hasPrefix($0) }) {
                return match
            }
        }
        let region = Locale.current.region?.identifier ?? "MK"
        return callingCodes[region] ?? "389"
    }

    /// 070 123 456 → +38970123456
    static func normalize(_ raw: String, defaultCode: String = PhoneID.defaultCallingCode) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasPlus = trimmed.hasPrefix("+")
        var digits = trimmed.filter { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty else { return nil }

        if hasPlus {
            // веќе меѓународен
        } else if digits.hasPrefix("00") {
            digits.removeFirst(2)
        } else if digits.hasPrefix("0") {
            digits = defaultCode + digits.dropFirst()
        } else if !digits.hasPrefix(defaultCode) || digits.count <= 9 {
            digits = defaultCode + digits
        }

        guard (8...15).contains(digits.count) else { return nil }
        return "+" + digits
    }

    static func phoneKey(_ normalized: String) -> String {
        "p_" + sha256("valise:phone:" + normalized)
    }

    static func emailKey(_ email: String) -> String {
        "e_" + sha256("valise:email:" + email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    /// Клучот без префикс (за users/{uid}).
    static func bareHash(_ key: String) -> String {
        String(key.dropFirst(2))
    }

    private static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
