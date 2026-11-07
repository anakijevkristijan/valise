import Foundation

/// Јазик на апликацијата. Се чува во UserDefaults; стандардно англиски.
/// Текстовите се пишуваат како L("македонски", "English"); за другите јазици преводот се бара
/// по англискиот текст во табелите `Translations` (Sources/Translations/*.swift).
enum AppLanguage: String, CaseIterable, Identifiable {
    case en, mk, sq, sr, bg, el, tr, de, fr, es, it, pl, pt

    static let storageKey = "appLanguage"

    var id: String { rawValue }

    /// Името на самиот јазик.
    var nativeName: String {
        switch self {
        case .en: return "English"
        case .mk: return "Македонски"
        case .sq: return "Shqip"
        case .sr: return "Srpski"
        case .bg: return "Български"
        case .el: return "Ελληνικά"
        case .tr: return "Türkçe"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .es: return "Español"
        case .it: return "Italiano"
        case .pl: return "Polski"
        case .pt: return "Português"
        }
    }

    /// Името на англиски (мал натпис под името).
    var englishName: String {
        switch self {
        case .en: return "International"
        case .mk: return "Macedonian"
        case .sq: return "Albanian"
        case .sr: return "Serbian"
        case .bg: return "Bulgarian"
        case .el: return "Greek"
        case .tr: return "Turkish"
        case .de: return "German"
        case .fr: return "French"
        case .es: return "Spanish"
        case .it: return "Italian"
        case .pl: return "Polish"
        case .pt: return "Portuguese"
        }
    }

    var shortName: String { rawValue.uppercased() }

    var locale: Locale {
        switch self {
        case .en: return Locale(identifier: "en_GB")
        case .mk: return Locale(identifier: "mk_MK")
        case .sq: return Locale(identifier: "sq_AL")
        case .sr: return Locale(identifier: "sr_Latn_RS")
        case .bg: return Locale(identifier: "bg_BG")
        case .el: return Locale(identifier: "el_GR")
        case .tr: return Locale(identifier: "tr_TR")
        case .de: return Locale(identifier: "de_DE")
        case .fr: return Locale(identifier: "fr_FR")
        case .es: return Locale(identifier: "es_ES")
        case .it: return Locale(identifier: "it_IT")
        case .pl: return Locale(identifier: "pl_PL")
        case .pt: return Locale(identifier: "pt_BR")
        }
    }

    static var current: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let language = AppLanguage(rawValue: raw) {
            return language
        }
        return .en
    }
}

/// Краток превод: L("Македонски", "English"). Другите јазици — од табелите, по англискиот текст.
func L(_ mk: String, _ en: String) -> String {
    switch AppLanguage.current {
    case .mk: return mk
    case .en: return en
    case let other: return Translations.translate(en, to: other)
    }
}

/// „3 маици“ / „3 T-shirts“ — број и именка. За другите јазици именката се бара посебно
/// (клуч „#T-shirts“), за да не се меша со насловите („T-shirts“ → „Tişörtler“, а „3 tişört“).
func countNoun(_ n: Int, _ oneMK: String, _ manyMK: String, _ oneEN: String, _ manyEN: String) -> String {
    let one = n == 1
    switch AppLanguage.current {
    case .mk: return "\(n) \(one ? oneMK : manyMK)"
    case .en: return "\(n) \(one ? oneEN : manyEN)"
    case let other:
        let english = one ? oneEN : manyEN
        let key = "#" + english
        let found = Translations.translate(key, to: other)
        return "\(n) \(found == key ? english : found)"
    }
}

/// Преводи на другите јазици: англиски текст → превод. Текстовите со вметнати вредности
/// („Search 417 airlines“) се наоѓаат по шаблон („Search {0} airlines“) и вредностите се враќаат на место.
enum Translations {
    private struct Table {
        let exact: [String: String]
        let patterns: [(regex: NSRegularExpression, translation: String)]
    }

    private static var tables: [AppLanguage: Table] = [:]
    private static var cache: [AppLanguage: [String: String]] = [:]
    private static let lock = NSLock()

    static func translate(_ english: String, to language: AppLanguage) -> String {
        lock.lock()
        defer { lock.unlock() }
        if let hit = cache[language]?[english] { return hit }
        let table = tables[language] ?? load(language)
        let result = lookup(english, in: table)
        cache[language, default: [:]][english] = result
        return result
    }

    private static func lookup(_ english: String, in table: Table) -> String {
        if let exact = table.exact[english] { return exact }
        let range = NSRange(english.startIndex..., in: english)
        for (regex, translation) in table.patterns {
            guard let match = regex.firstMatch(in: english, options: [], range: range) else { continue }
            var output = translation
            for index in 1..<match.numberOfRanges {
                guard let r = Range(match.range(at: index), in: english) else { continue }
                output = output.replacingOccurrences(of: "{\(index - 1)}", with: String(english[r]))
            }
            return output
        }
        return english
    }

    private static func load(_ language: AppLanguage) -> Table {
        let raw = source(for: language)
        var exact: [String: String] = [:]
        var patterns: [(NSRegularExpression, String)] = []
        if let data = raw.data(using: .utf8),
           let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: String] {
            for (english, translated) in dict {
                if english.contains("{0}") {
                    if let regex = pattern(for: english) { patterns.append((regex, translated)) }
                } else {
                    exact[english] = translated
                }
            }
        }
        // Подолгите шаблони прво (поконкретни)
        patterns.sort { $0.0.pattern.count > $1.0.pattern.count }
        let table = Table(exact: exact, patterns: patterns)
        tables[language] = table
        return table
    }

    /// „Search {0} airlines“ → ^Search (.+?) airlines$
    private static func pattern(for template: String) -> NSRegularExpression? {
        var regex = "^"
        var rest = Substring(template)
        while let open = rest.range(of: "{") {
            let after = rest[open.upperBound...]
            guard let close = after.range(of: "}"),
                  Int(after[after.startIndex..<close.lowerBound]) != nil else {
                regex += NSRegularExpression.escapedPattern(for: String(rest[..<open.upperBound]))
                rest = rest[open.upperBound...]
                continue
            }
            regex += NSRegularExpression.escapedPattern(for: String(rest[..<open.lowerBound]))
            regex += "(.+?)"
            rest = after[close.upperBound...]
        }
        regex += NSRegularExpression.escapedPattern(for: String(rest)) + "$"
        return try? NSRegularExpression(pattern: regex, options: [.dotMatchesLineSeparators])
    }

    private static func source(for language: AppLanguage) -> String {
        switch language {
        case .sq: return TranslationsSQ.json
        case .sr: return TranslationsSR.json
        case .bg: return TranslationsBG.json
        case .el: return TranslationsEL.json
        case .tr: return TranslationsTR.json
        case .de: return TranslationsDE.json
        case .fr: return TranslationsFR.json
        case .es: return TranslationsES.json
        case .it: return TranslationsIT.json
        case .pl: return TranslationsPL.json
        case .pt: return TranslationsPT.json
        case .en, .mk: return "{}"
        }
    }
}
