import Foundation

/// Трибуквен код на град за авионската карта (SKP, ROM, PAR…).
/// Познатите градови го добиваат вистинскиот IATA код; останатите — изведен од името.
enum CityCode {

    static func code(for name: String) -> String {
        let latin = latinLetters(name)
        if latin.isEmpty { return "———" }
        if let known = knownCodes[latin] { return known }
        return derived(from: latin)
    }

    /// Прва буква + следните согласки, како аеродромските кодови (Маврово → MVR).
    private static func derived(from latin: String) -> String {
        let letters = Array(latin)
        guard let first = letters.first else { return "———" }
        var result = [first]
        let vowels: Set<Character> = ["A", "E", "I", "O", "U", "Y"]
        for ch in letters.dropFirst() where result.count < 3 {
            if !vowels.contains(ch) && ch != result.last { result.append(ch) }
        }
        if result.count < 3 {
            for ch in letters.dropFirst() where result.count < 3 {
                result.append(ch)
            }
        }
        while result.count < 3 { result.append("X") }
        return String(result.prefix(3))
    }

    /// Кирилица → латиница, без дијакритици, само големи букви A–Z.
    static func latinLetters(_ text: String) -> String {
        var out = ""
        for ch in text.lowercased() {
            if let mapped = cyrillic[ch] {
                out += mapped
            } else {
                out.append(ch)
            }
        }
        let folded = out.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
        return folded.uppercased().filter { $0 >= "A" && $0 <= "Z" }
    }

    private static let cyrillic: [Character: String] = [
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "ѓ": "gj", "е": "e", "ж": "zh",
        "з": "z", "ѕ": "dz", "и": "i", "ј": "j", "к": "k", "л": "l", "љ": "lj", "м": "m",
        "н": "n", "њ": "nj", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "ќ": "kj",
        "у": "u", "ф": "f", "х": "h", "ц": "c", "ч": "ch", "џ": "dzh", "ш": "sh",
        "ђ": "dj", "ћ": "c", "й": "y", "ы": "y", "э": "e", "ю": "yu", "я": "ya", "ё": "e",
        "щ": "sht", "ъ": "a", "ь": "", "і": "i", "ї": "i", "є": "e", "ґ": "g"
    ]

    private static let knownCodes: [String: String] = [
        // Македонија и регион
        "SKOPJE": "SKP", "OHRID": "OHD",
        "BELGRAD": "BEG", "BELGRADE": "BEG", "BEOGRAD": "BEG",
        "SOFIJA": "SOF", "SOFIA": "SOF",
        "SOLUN": "SKG", "THESSALONIKI": "SKG",
        "TIRANA": "TIA", "PODGORICA": "TGD", "SARAEVO": "SJJ", "SARAJEVO": "SJJ",
        "ZAGREB": "ZAG", "LJUBLJANA": "LJU", "DUBROVNIK": "DBV", "SPLIT": "SPU",
        "NISH": "INI", "NIS": "INI", "PRISHTINA": "PRN", "PRISTINA": "PRN",
        "ATINA": "ATH", "ATHENS": "ATH",
        "KRF": "CFU", "CORFU": "CFU", "SANTORINI": "JTR", "MIKONOS": "JMK", "MYKONOS": "JMK",
        "IRAKLION": "HER", "HERAKLION": "HER",
        "ISTANBUL": "IST", "ANTALIJA": "AYT", "ANTALYA": "AYT",
        "BUKURESHT": "BUH", "BUCHAREST": "BUH", "BUDIMPESHTA": "BUD", "BUDAPEST": "BUD",
        // Европа
        "RIM": "ROM", "ROME": "ROM", "ROMA": "ROM",
        "MILANO": "MIL", "MILAN": "MIL", "VENECIJA": "VCE", "VENICE": "VCE",
        "FIRENCA": "FLR", "FLORENCE": "FLR", "NEAPOL": "NAP", "NAPLES": "NAP",
        "PARIZ": "PAR", "PARIS": "PAR", "NICA": "NCE", "NICE": "NCE",
        "LONDON": "LON", "AMSTERDAM": "AMS", "BRISEL": "BRU", "BRUSSELS": "BRU",
        "BERLIN": "BER", "MINHEN": "MUC", "MUNICH": "MUC", "MUNCHEN": "MUC",
        "FRANKFURT": "FRA", "HAMBURG": "HAM", "KELN": "CGN", "COLOGNE": "CGN",
        "DISELDORF": "DUS", "DUSSELDORF": "DUS",
        "VIENA": "VIE", "VIENNA": "VIE", "WIEN": "VIE",
        "PRAGA": "PRG", "PRAGUE": "PRG", "BRATISLAVA": "BTS",
        "CIRIH": "ZRH", "ZURICH": "ZRH", "ZHENEVA": "GVA", "GENEVA": "GVA",
        "BARSELONA": "BCN", "BARCELONA": "BCN", "MADRID": "MAD",
        "LISABON": "LIS", "LISBON": "LIS",
        "KOPENHAGEN": "CPH", "COPENHAGEN": "CPH", "STOKHOLM": "STO", "STOCKHOLM": "STO",
        "OSLO": "OSL", "VARSHAVA": "WAW", "WARSAW": "WAW", "KRAKOV": "KRK", "KRAKOW": "KRK",
        "MALTA": "MLA", "VALETA": "MLA", "VALLETTA": "MLA",
        // Свет
        "DUBAI": "DXB", "DUBAJ": "DXB", "DOHA": "DOH", "ABUDABI": "AUH", "ABUDHABI": "AUH",
        "NJUJORK": "NYC", "NEWYORK": "NYC", "LOSANGELES": "LAX", "MAJAMI": "MIA", "MIAMI": "MIA",
        "TOKIO": "TYO", "TOKYO": "TYO", "BANGKOK": "BKK", "SINGAPUR": "SIN", "SINGAPORE": "SIN",
        "MARAKESH": "RAK", "MARRAKESH": "RAK", "MARRAKECH": "RAK", "KAIRO": "CAI", "CAIRO": "CAI"
    ]
}
