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
        "SK": "421", "US": "1", "CA": "1", "AU": "61", "AE": "971"
    ]

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
