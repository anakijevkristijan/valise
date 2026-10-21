import Foundation

// MARK: - Авиокомпании

enum AirlineRegion: String, CaseIterable, Identifiable {
    case europe, middleEast, asia, americas, africa, oceania

    var id: String { rawValue }

    var title: String {
        switch self {
        case .europe: return L("Европа", "Europe")
        case .middleEast: return L("Блиски Исток", "Middle East")
        case .asia: return L("Азија", "Asia")
        case .americas: return L("Америка", "Americas")
        case .africa: return L("Африка", "Africa")
        case .oceania: return L("Австралија и Океанија", "Australia and Oceania")
        }
    }
}

struct Airline: Identifiable, Hashable {
    let id: String
    let code: String
    let name: String
    let country: String
    let region: AirlineRegion
    let isLowCost: Bool
    let website: String?
    let bags: [BagSpec]
    let tip: String?

    var countryName: String {
        AppLanguage.current.locale.localizedString(forRegionCode: country) ?? country
    }

    /// За пребарување: име, IATA код, земја (на двата јазика).
    var searchText: String {
        let english = Locale(identifier: "en").localizedString(forRegionCode: country) ?? ""
        return [name, code, country, countryName, english].joined(separator: " ").lowercased()
    }
}

/// Правила за багаж (економска класа) — информативно, октомври 2026.
/// Секогаш провери на сајтот на авиокомпанијата пред лет.
enum Airlines {
    static var dataUpdated: String { L("октомври 2026", "October 2026") }

    /// Најчести за патници од Македонија и регионот — прикажани први.
    static let popularIDs = ["wizz", "turkish", "austrian", "lufthansa", "pegasus", "ajet", "airserbia",
                             "swiss", "eurowings", "ryanair", "easyjet", "aegean", "croatia", "flydubai",
                             "emirates", "qatar"]

    // MARK: Правило за багаж

    enum Rule {
        case included   // во секој билет
        case fare       // зависи од тарифата
        case paid       // се доплаќа
    }

    typealias Size = (h: Double, w: Double, d: Double, kg: Double?)

    private struct Row {
        let id: String
        let code: String
        let name: String
        let country: String
        let region: AirlineRegion
        var lowCost = false
        var personal: Size? = (40, 30, 15, nil)
        var cabin: Size? = (55, 40, 23, 8)
        var cabinRule: Rule = .included
        var cabinNote: (String, String)? = nil
        var checkedKg: Double = 23
        var checkedRule: Rule = .fare
        var site: String? = nil
        var tip: (String, String)? = nil
    }

    // MARK: Податоци

    private static var rows: [Row] {
        var list: [Row] = []
        func add(_ row: Row) { list.append(row) }

        // ——— Европа: нискобуџетни ———
        add(Row(id: "wizz", code: "W6", name: "Wizz Air", country: "HU", region: .europe, lowCost: true,
                personal: (40, 30, 20, 10), cabin: (55, 40, 23, 10), cabinRule: .paid,
                cabinNote: ("Со WIZZ Priority · горна полица", "With WIZZ Priority · overhead bin"),
                checkedKg: 20, checkedRule: .paid, site: "wizzair.com",
                tip: ("Без Priority смееш само малата торба. Казната на излезот е околу 65 €.",
                      "Without Priority you may only bring the small bag. The gate fee is around €65.")))
        add(Row(id: "ryanair", code: "FR", name: "Ryanair", country: "IE", region: .europe, lowCost: true,
                personal: (40, 30, 20, nil), cabin: (55, 40, 20, 10), cabinRule: .paid,
                cabinNote: ("Со Priority · горна полица", "With Priority · overhead bin"),
                checkedKg: 20, checkedRule: .paid, site: "ryanair.com",
                tip: ("Тркалата, рачките и надворешните џебови влегуваат во мерката.",
                      "Wheels, handles and outer pockets count towards the size.")))
        add(Row(id: "easyjet", code: "U2", name: "easyJet", country: "GB", region: .europe, lowCost: true,
                personal: (45, 36, 20, 15), cabin: (56, 45, 25, 15), cabinRule: .paid,
                cabinNote: ("Голем кабински — се доплаќа или со FLEXI", "Large cabin bag — extra fee or with FLEXI"),
                checkedKg: 23, checkedRule: .paid, site: "easyjet.com",
                tip: ("Up Front и Extra Legroom седиштата веќе не вклучуваат голем кабински куфер.",
                      "Up Front and Extra Legroom seats no longer include a large cabin bag.")))
        add(Row(id: "pegasus", code: "PC", name: "Pegasus", country: "TR", region: .europe, lowCost: true,
                personal: (40, 30, 15, 3), cabin: (55, 40, 20, 8), cabinRule: .fare,
                checkedKg: 20, site: "flypgs.com",
                tip: ("На меѓународни летови бесплатната торба смее до 3 kg.",
                      "On international flights the free bag may weigh up to 3 kg.")))
        add(Row(id: "ajet", code: "VF", name: "AJet", country: "TR", region: .europe, lowCost: true,
                personal: (40, 30, 15, 4), cabin: (55, 40, 23, 8), cabinRule: .fare, checkedKg: 20, site: "ajet.com"))
        add(Row(id: "eurowings", code: "EW", name: "Eurowings", country: "DE", region: .europe, lowCost: true,
                personal: (40, 30, 25, nil), cabin: (55, 40, 23, 8), cabinRule: .fare,
                cabinNote: ("Од тарифата Smart", "From the Smart fare"), site: "eurowings.com"))
        add(Row(id: "vueling", code: "VY", name: "Vueling", country: "ES", region: .europe, lowCost: true,
                personal: (40, 30, 20, nil), cabin: (55, 40, 20, 10), cabinRule: .fare, checkedKg: 25, site: "vueling.com"))
        add(Row(id: "transavia", code: "HV", name: "Transavia", country: "NL", region: .europe, lowCost: true,
                personal: (40, 30, 20, nil), cabin: (55, 40, 25, 10), cabinRule: .paid, checkedKg: 20, checkedRule: .paid,
                site: "transavia.com"))
        add(Row(id: "volotea", code: "V7", name: "Volotea", country: "ES", region: .europe, lowCost: true,
                personal: (40, 35, 20, nil), cabin: (55, 40, 20, 10), cabinRule: .paid, checkedKg: 25, checkedRule: .paid,
                site: "volotea.com"))
        add(Row(id: "norwegian", code: "DY", name: "Norwegian", country: "NO", region: .europe, lowCost: true,
                personal: (38, 30, 20, nil), cabin: (55, 40, 23, 10), cabinRule: .fare, checkedKg: 20, site: "norwegian.com"))
        add(Row(id: "jet2", code: "LS", name: "Jet2", country: "GB", region: .europe, lowCost: true,
                personal: (40, 30, 15, nil), cabin: (56, 45, 25, 10), checkedKg: 22, checkedRule: .paid, site: "jet2.com"))
        add(Row(id: "tui", code: "BY", name: "TUI Airways", country: "GB", region: .europe, lowCost: true,
                personal: nil, cabin: (55, 40, 20, 10), checkedKg: 20, site: "tui.co.uk"))
        add(Row(id: "smartwings", code: "QS", name: "Smartwings", country: "CZ", region: .europe, lowCost: true,
                cabin: (55, 40, 20, 8), cabinRule: .fare, checkedKg: 20, site: "smartwings.com"))
        add(Row(id: "flyone", code: "5F", name: "FlyOne", country: "MD", region: .europe, lowCost: true,
                personal: (40, 30, 20, nil), cabin: (55, 40, 20, 10), cabinRule: .paid, checkedKg: 20, checkedRule: .paid,
                site: "flyone.eu"))
        add(Row(id: "skyexpress", code: "GQ", name: "SKY express", country: "GR", region: .europe, lowCost: true,
                cabin: (55, 40, 20, 8), cabinRule: .fare, site: "skyexpress.gr"))
        add(Row(id: "sunexpress", code: "XQ", name: "SunExpress", country: "TR", region: .europe, lowCost: true,
                cabin: (55, 40, 23, 8), checkedKg: 20, site: "sunexpress.com"))

        // ——— Европа: класични ———
        add(Row(id: "turkish", code: "TK", name: "Turkish Airlines", country: "TR", region: .europe,
                personal: (40, 30, 15, 4), site: "turkishairlines.com"))
        add(Row(id: "lufthansa", code: "LH", name: "Lufthansa", country: "DE", region: .europe,
                personal: (40, 30, 10, nil), site: "lufthansa.com"))
        add(Row(id: "austrian", code: "OS", name: "Austrian", country: "AT", region: .europe,
                personal: (40, 30, 10, nil), site: "austrian.com"))
        add(Row(id: "swiss", code: "LX", name: "SWISS", country: "CH", region: .europe, site: "swiss.com"))
        add(Row(id: "brussels", code: "SN", name: "Brussels Airlines", country: "BE", region: .europe, site: "brusselsairlines.com"))
        add(Row(id: "airserbia", code: "JU", name: "Air Serbia", country: "RS", region: .europe, site: "airserbia.com"))
        add(Row(id: "croatia", code: "OU", name: "Croatia Airlines", country: "HR", region: .europe, site: "croatiaairlines.com"))
        add(Row(id: "aegean", code: "A3", name: "Aegean", country: "GR", region: .europe,
                cabin: (56, 45, 25, 8), site: "aegeanair.com"))
        add(Row(id: "olympic", code: "OA", name: "Olympic Air", country: "GR", region: .europe,
                cabin: (56, 45, 25, 8), site: "olympicair.com"))
        add(Row(id: "airfrance", code: "AF", name: "Air France", country: "FR", region: .europe,
                cabin: (55, 35, 25, 12), cabinNote: ("Вклучено · 12 kg заедно со малата торба", "Included · 12 kg together with the small bag"),
                site: "airfrance.com"))
        add(Row(id: "klm", code: "KL", name: "KLM", country: "NL", region: .europe,
                cabin: (55, 35, 25, 12), cabinNote: ("Вклучено · 12 kg заедно со малата торба", "Included · 12 kg together with the small bag"),
                site: "klm.com"))
        add(Row(id: "britishairways", code: "BA", name: "British Airways", country: "GB", region: .europe,
                personal: (40, 30, 15, 23), cabin: (56, 45, 25, 23), site: "britishairways.com"))
        add(Row(id: "virginatlantic", code: "VS", name: "Virgin Atlantic", country: "GB", region: .europe,
                cabin: (56, 36, 23, 10), site: "virginatlantic.com"))
        add(Row(id: "iberia", code: "IB", name: "Iberia", country: "ES", region: .europe,
                cabin: (56, 40, 25, nil), site: "iberia.com"))
        add(Row(id: "aireuropa", code: "UX", name: "Air Europa", country: "ES", region: .europe,
                cabin: (55, 35, 25, 10), site: "aireuropa.com"))
        add(Row(id: "aerlingus", code: "EI", name: "Aer Lingus", country: "IE", region: .europe,
                personal: (33, 25, 20, nil), cabin: (55, 40, 24, 10), cabinRule: .fare, checkedKg: 20, site: "aerlingus.com"))
        add(Row(id: "tap", code: "TP", name: "TAP Air Portugal", country: "PT", region: .europe,
                cabin: (55, 40, 20, 8), site: "flytap.com"))
        add(Row(id: "ita", code: "AZ", name: "ITA Airways", country: "IT", region: .europe,
                cabin: (55, 35, 25, 8), site: "ita-airways.com"))
        add(Row(id: "sas", code: "SK", name: "SAS", country: "SE", region: .europe, site: "flysas.com"))
        add(Row(id: "finnair", code: "AY", name: "Finnair", country: "FI", region: .europe,
                cabin: (56, 45, 25, 8), site: "finnair.com"))
        add(Row(id: "icelandair", code: "FI", name: "Icelandair", country: "IS", region: .europe,
                cabin: (55, 40, 20, 10), site: "icelandair.com"))
        add(Row(id: "lot", code: "LO", name: "LOT Polish Airlines", country: "PL", region: .europe,
                personal: (40, 35, 12, nil), site: "lot.com"))
        add(Row(id: "tarom", code: "RO", name: "TAROM", country: "RO", region: .europe,
                cabin: (55, 40, 20, 10), site: "tarom.ro"))
        add(Row(id: "bulgariaair", code: "FB", name: "Bulgaria Air", country: "BG", region: .europe,
                cabin: (55, 40, 20, 8), site: "air.bg"))
        add(Row(id: "airalbania", code: "ZB", name: "Air Albania", country: "AL", region: .europe,
                cabin: (55, 40, 20, 8), site: "airalbania.com.al"))
        add(Row(id: "airmontenegro", code: "4O", name: "Air Montenegro", country: "ME", region: .europe,
                cabin: (55, 40, 20, 8), site: "airmontenegro.com"))
        add(Row(id: "airbaltic", code: "BT", name: "airBaltic", country: "LV", region: .europe,
                personal: (40, 30, 10, nil), cabinRule: .fare, checkedKg: 20, site: "airbaltic.com"))
        add(Row(id: "condor", code: "DE", name: "Condor", country: "DE", region: .europe,
                personal: (40, 30, 10, nil), cabin: (55, 40, 20, 8), site: "condor.com"))
        add(Row(id: "edelweiss", code: "WK", name: "Edelweiss", country: "CH", region: .europe, site: "flyedelweiss.com"))
        add(Row(id: "airdolomiti", code: "EN", name: "Air Dolomiti", country: "IT", region: .europe,
                cabin: (55, 40, 20, 8), site: "airdolomiti.eu"))
        add(Row(id: "luxair", code: "LG", name: "Luxair", country: "LU", region: .europe, site: "luxair.lu"))
        add(Row(id: "cyprusairways", code: "CY", name: "Cyprus Airways", country: "CY", region: .europe,
                cabin: (55, 40, 20, 8), site: "cyprusairways.com"))
        add(Row(id: "kmmalta", code: "KM", name: "KM Malta Airlines", country: "MT", region: .europe,
                cabin: (55, 40, 20, 8), site: "kmmaltairlines.com"))
        add(Row(id: "aeroflot", code: "SU", name: "Aeroflot", country: "RU", region: .europe,
                cabin: (55, 40, 25, 10), site: "aeroflot.ru"))
        add(Row(id: "azal", code: "J2", name: "Azerbaijan Airlines", country: "AZ", region: .europe,
                cabin: (55, 40, 23, 10), site: "azal.az"))
        add(Row(id: "georgian", code: "A9", name: "Georgian Airways", country: "GE", region: .europe,
                cabin: (55, 40, 20, 8), site: "georgian-airways.com"))

        // ——— Блиски Исток ———
        add(Row(id: "emirates", code: "EK", name: "Emirates", country: "AE", region: .middleEast,
                personal: nil, cabin: (55, 38, 20, 7), checkedKg: 25, site: "emirates.com"))
        add(Row(id: "qatar", code: "QR", name: "Qatar Airways", country: "QA", region: .middleEast,
                personal: nil, cabin: (50, 37, 25, 7), checkedKg: 25, site: "qatarairways.com"))
        add(Row(id: "etihad", code: "EY", name: "Etihad", country: "AE", region: .middleEast,
                personal: nil, cabin: (56, 36, 23, 7), site: "etihad.com"))
        add(Row(id: "flydubai", code: "FZ", name: "flydubai", country: "AE", region: .middleEast, lowCost: true,
                personal: nil, cabin: (55, 38, 20, 7), checkedKg: 20, site: "flydubai.com"))
        add(Row(id: "airarabia", code: "G9", name: "Air Arabia", country: "AE", region: .middleEast, lowCost: true,
                personal: nil, cabin: (55, 40, 20, 10), cabinNote: ("Вклучено · 10 kg заедно со малата торба", "Included · 10 kg together with the small bag"),
                checkedKg: 20, checkedRule: .paid, site: "airarabia.com"))
        add(Row(id: "saudia", code: "SV", name: "Saudia", country: "SA", region: .middleEast,
                personal: nil, cabin: (56, 36, 23, 7), site: "saudia.com"))
        add(Row(id: "flynas", code: "XY", name: "flynas", country: "SA", region: .middleEast, lowCost: true,
                personal: nil, cabin: (56, 36, 23, 7), checkedKg: 20, site: "flynas.com"))
        add(Row(id: "flyadeal", code: "F3", name: "flyadeal", country: "SA", region: .middleEast, lowCost: true,
                personal: nil, cabin: (56, 36, 23, 7), checkedKg: 20, checkedRule: .paid, site: "flyadeal.com"))
        add(Row(id: "gulfair", code: "GF", name: "Gulf Air", country: "BH", region: .middleEast,
                personal: nil, cabin: (55, 40, 20, 7), site: "gulfair.com"))
        add(Row(id: "omanair", code: "WY", name: "Oman Air", country: "OM", region: .middleEast,
                personal: nil, cabin: (55, 40, 20, 7), site: "omanair.com"))
        add(Row(id: "kuwait", code: "KU", name: "Kuwait Airways", country: "KW", region: .middleEast,
                personal: nil, cabin: (55, 40, 20, 7), site: "kuwaitairways.com"))
        add(Row(id: "royaljordanian", code: "RJ", name: "Royal Jordanian", country: "JO", region: .middleEast,
                personal: nil, cabin: (56, 46, 25, 7), site: "rj.com"))
        add(Row(id: "mea", code: "ME", name: "Middle East Airlines", country: "LB", region: .middleEast,
                personal: nil, cabin: (55, 40, 20, 7), site: "mea.com.lb"))
        add(Row(id: "elal", code: "LY", name: "El Al", country: "IL", region: .middleEast,
                cabin: (56, 45, 25, 8), site: "elal.com"))

        // ——— Азија ———
        add(Row(id: "singapore", code: "SQ", name: "Singapore Airlines", country: "SG", region: .asia,
                personal: nil, cabin: (56, 36, 23, 7), checkedKg: 25, site: "singaporeair.com"))
        add(Row(id: "scoot", code: "TR", name: "Scoot", country: "SG", region: .asia, lowCost: true,
                personal: nil, cabin: (54, 38, 23, 10), cabinNote: ("Вклучено · 10 kg заедно со малата торба", "Included · 10 kg together with the small bag"),
                checkedKg: 20, checkedRule: .paid, site: "flyscoot.com"))
        add(Row(id: "cathay", code: "CX", name: "Cathay Pacific", country: "HK", region: .asia,
                personal: nil, cabin: (56, 36, 23, 7), site: "cathaypacific.com"))
        add(Row(id: "hkexpress", code: "UO", name: "HK Express", country: "HK", region: .asia, lowCost: true,
                personal: nil, cabin: (56, 36, 23, 7), checkedKg: 20, checkedRule: .paid, site: "hkexpress.com"))
        add(Row(id: "ana", code: "NH", name: "ANA", country: "JP", region: .asia,
                personal: nil, cabin: (55, 40, 25, 10), checkedRule: .included, site: "ana.co.jp"))
        add(Row(id: "jal", code: "JL", name: "Japan Airlines", country: "JP", region: .asia,
                personal: nil, cabin: (55, 40, 25, 10), checkedRule: .included, site: "jal.com"))
        add(Row(id: "peach", code: "MM", name: "Peach", country: "JP", region: .asia, lowCost: true,
                personal: nil, cabin: (50, 40, 25, 7), checkedKg: 20, checkedRule: .paid, site: "flypeach.com"))
        add(Row(id: "korean", code: "KE", name: "Korean Air", country: "KR", region: .asia,
                personal: nil, cabin: (55, 40, 20, 10), checkedRule: .included, site: "koreanair.com"))
        add(Row(id: "asiana", code: "OZ", name: "Asiana", country: "KR", region: .asia,
                personal: nil, cabin: (55, 40, 20, 10), checkedRule: .included, site: "flyasiana.com"))
        add(Row(id: "jejuair", code: "7C", name: "Jeju Air", country: "KR", region: .asia, lowCost: true,
                personal: nil, cabin: (55, 40, 20, 10), checkedKg: 15, site: "jejuair.net"))
        add(Row(id: "airchina", code: "CA", name: "Air China", country: "CN", region: .asia,
                personal: nil, cabin: (55, 40, 20, 5), checkedRule: .included, site: "airchina.com"))
        add(Row(id: "chinaeastern", code: "MU", name: "China Eastern", country: "CN", region: .asia,
                personal: nil, cabin: (55, 40, 20, 10), checkedRule: .included, site: "ceair.com"))
        add(Row(id: "chinasouthern", code: "CZ", name: "China Southern", country: "CN", region: .asia,
                personal: nil, cabin: (55, 40, 20, 8), checkedRule: .included, site: "csair.com"))
        add(Row(id: "hainan", code: "HU", name: "Hainan Airlines", country: "CN", region: .asia,
                personal: nil, cabin: (55, 40, 20, 10), checkedRule: .included, site: "hainanairlines.com"))
        add(Row(id: "eva", code: "BR", name: "EVA Air", country: "TW", region: .asia,
                personal: nil, cabin: (56, 36, 23, 7), site: "evaair.com"))
        add(Row(id: "chinaairlines", code: "CI", name: "China Airlines", country: "TW", region: .asia,
                personal: nil, cabin: (56, 36, 23, 7), site: "china-airlines.com"))
        add(Row(id: "starlux", code: "JX", name: "STARLUX", country: "TW", region: .asia,
                personal: nil, cabin: (56, 36, 23, 7), site: "starlux-airlines.com"))
        add(Row(id: "thai", code: "TG", name: "Thai Airways", country: "TH", region: .asia,
                personal: nil, cabin: (56, 45, 25, 7), site: "thaiairways.com"))
        add(Row(id: "airasia", code: "AK", name: "AirAsia", country: "MY", region: .asia, lowCost: true,
                personal: nil, cabin: (56, 36, 23, 7), cabinNote: ("Вклучено · 7 kg заедно со малата торба", "Included · 7 kg together with the small bag"),
                checkedKg: 20, checkedRule: .paid, site: "airasia.com"))
        add(Row(id: "malaysia", code: "MH", name: "Malaysia Airlines", country: "MY", region: .asia,
                personal: nil, cabin: (56, 36, 23, 7), site: "malaysiaairlines.com"))
        add(Row(id: "batik", code: "OD", name: "Batik Air", country: "MY", region: .asia,
                personal: nil, cabin: (56, 36, 23, 7), checkedKg: 20, site: "batikair.com"))
        add(Row(id: "garuda", code: "GA", name: "Garuda Indonesia", country: "ID", region: .asia,
                personal: nil, cabin: (56, 36, 23, 7), site: "garuda-indonesia.com"))
        add(Row(id: "lionair", code: "JT", name: "Lion Air", country: "ID", region: .asia, lowCost: true,
                personal: nil, cabin: (40, 30, 20, 7), checkedKg: 20, checkedRule: .included, site: "lionair.co.id"))
        add(Row(id: "philippine", code: "PR", name: "Philippine Airlines", country: "PH", region: .asia,
                personal: nil, cabin: (56, 36, 23, 7), site: "philippineairlines.com"))
        add(Row(id: "cebupacific", code: "5J", name: "Cebu Pacific", country: "PH", region: .asia, lowCost: true,
                personal: nil, cabin: (56, 35, 23, 7), checkedKg: 20, checkedRule: .paid, site: "cebupacificair.com"))
        add(Row(id: "vietnam", code: "VN", name: "Vietnam Airlines", country: "VN", region: .asia,
                personal: nil, cabin: (56, 36, 23, 10), site: "vietnamairlines.com"))
        add(Row(id: "vietjet", code: "VJ", name: "VietJet Air", country: "VN", region: .asia, lowCost: true,
                personal: nil, cabin: (56, 36, 23, 7), checkedKg: 20, checkedRule: .paid, site: "vietjetair.com"))
        add(Row(id: "airindia", code: "AI", name: "Air India", country: "IN", region: .asia,
                personal: nil, cabin: (55, 40, 20, 7), site: "airindia.com"))
        add(Row(id: "indigo", code: "6E", name: "IndiGo", country: "IN", region: .asia, lowCost: true,
                personal: nil, cabin: (55, 35, 25, 7), checkedKg: 15, site: "goindigo.in"))
        add(Row(id: "airindiaexpress", code: "IX", name: "Air India Express", country: "IN", region: .asia, lowCost: true,
                personal: nil, cabin: (55, 35, 25, 7), checkedKg: 15, site: "airindiaexpress.com"))
        add(Row(id: "spicejet", code: "SG", name: "SpiceJet", country: "IN", region: .asia, lowCost: true,
                personal: nil, cabin: (55, 35, 25, 7), checkedKg: 15, site: "spicejet.com"))
        add(Row(id: "srilankan", code: "UL", name: "SriLankan Airlines", country: "LK", region: .asia,
                personal: nil, cabin: (56, 36, 23, 7), checkedKg: 30, site: "srilankan.com"))
        add(Row(id: "airastana", code: "KC", name: "Air Astana", country: "KZ", region: .asia,
                cabin: (56, 45, 25, 8), site: "airastana.com"))
        add(Row(id: "uzbekistan", code: "HY", name: "Uzbekistan Airways", country: "UZ", region: .asia,
                cabin: (55, 40, 20, 8), site: "uzairways.com"))

        // ——— Австралија и Океанија ———
        add(Row(id: "qantas", code: "QF", name: "Qantas", country: "AU", region: .oceania,
                personal: nil, cabin: (56, 36, 23, 7), site: "qantas.com"))
        add(Row(id: "virginaustralia", code: "VA", name: "Virgin Australia", country: "AU", region: .oceania,
                personal: nil, cabin: (56, 36, 23, 7), site: "virginaustralia.com"))
        add(Row(id: "jetstar", code: "JQ", name: "Jetstar", country: "AU", region: .oceania, lowCost: true,
                personal: nil, cabin: (56, 36, 23, 7), cabinNote: ("Вклучено · 7 kg заедно со малата торба", "Included · 7 kg together with the small bag"),
                checkedKg: 20, checkedRule: .paid, site: "jetstar.com"))
        add(Row(id: "airnewzealand", code: "NZ", name: "Air New Zealand", country: "NZ", region: .oceania,
                personal: nil, cabin: (56, 36, 23, 7), site: "airnewzealand.com"))
        add(Row(id: "fiji", code: "FJ", name: "Fiji Airways", country: "FJ", region: .oceania,
                personal: nil, cabin: (56, 36, 23, 7), checkedRule: .included, site: "fijiairways.com"))

        // ——— Америка ———
        add(Row(id: "american", code: "AA", name: "American Airlines", country: "US", region: .americas,
                personal: (45, 35, 20, nil), cabin: (56, 36, 23, nil), checkedRule: .paid, site: "aa.com"))
        add(Row(id: "delta", code: "DL", name: "Delta", country: "US", region: .americas,
                personal: (45, 35, 20, nil), cabin: (56, 35, 23, nil), checkedRule: .paid, site: "delta.com"))
        add(Row(id: "united", code: "UA", name: "United", country: "US", region: .americas,
                personal: (43, 25, 22, nil), cabin: (56, 35, 22, nil), cabinRule: .fare,
                cabinNote: ("Не е во Basic Economy (во САД)", "Not in Basic Economy (US flights)"),
                checkedRule: .paid, site: "united.com"))
        add(Row(id: "southwest", code: "WN", name: "Southwest", country: "US", region: .americas,
                personal: (41, 33, 20, nil), cabin: (61, 41, 25, nil), checkedRule: .paid, site: "southwest.com"))
        add(Row(id: "alaska", code: "AS", name: "Alaska Airlines", country: "US", region: .americas,
                personal: (43, 33, 20, nil), cabin: (56, 35, 23, nil), checkedRule: .paid, site: "alaskaair.com"))
        add(Row(id: "jetblue", code: "B6", name: "JetBlue", country: "US", region: .americas,
                personal: (43, 33, 20, nil), cabin: (56, 35, 23, nil), cabinRule: .fare, checkedRule: .paid, site: "jetblue.com"))
        add(Row(id: "hawaiian", code: "HA", name: "Hawaiian Airlines", country: "US", region: .americas,
                personal: (43, 33, 20, nil), cabin: (56, 36, 23, nil), checkedRule: .paid, site: "hawaiianairlines.com"))
        add(Row(id: "spirit", code: "NK", name: "Spirit", country: "US", region: .americas, lowCost: true,
                personal: (45, 35, 20, nil), cabin: (56, 46, 25, nil), cabinRule: .paid, checkedKg: 18, checkedRule: .paid,
                site: "spirit.com"))
        add(Row(id: "frontier", code: "F9", name: "Frontier", country: "US", region: .americas, lowCost: true,
                personal: (46, 36, 20, nil), cabin: (61, 41, 25, nil), cabinRule: .paid, checkedKg: 18, checkedRule: .paid,
                site: "flyfrontier.com"))
        add(Row(id: "aircanada", code: "AC", name: "Air Canada", country: "CA", region: .americas,
                personal: (43, 33, 16, nil), cabin: (55, 40, 23, nil), cabinRule: .fare, site: "aircanada.com"))
        add(Row(id: "westjet", code: "WS", name: "WestJet", country: "CA", region: .americas,
                personal: (41, 33, 15, nil), cabin: (53, 38, 23, nil), cabinRule: .fare, checkedRule: .paid, site: "westjet.com"))
        add(Row(id: "porter", code: "PD", name: "Porter Airlines", country: "CA", region: .americas,
                personal: (43, 33, 16, nil), cabin: (55, 40, 23, nil), checkedRule: .paid, site: "flyporter.com"))
        add(Row(id: "aeromexico", code: "AM", name: "Aeroméxico", country: "MX", region: .americas,
                cabin: (55, 40, 25, 10), site: "aeromexico.com"))
        add(Row(id: "volaris", code: "Y4", name: "Volaris", country: "MX", region: .americas, lowCost: true,
                personal: (45, 35, 20, nil), cabin: (57, 45, 25, 10), cabinRule: .fare, checkedKg: 25, checkedRule: .paid,
                site: "volaris.com"))
        add(Row(id: "vivaaerobus", code: "VB", name: "Viva Aerobus", country: "MX", region: .americas, lowCost: true,
                personal: (40, 35, 15, nil), cabin: (55, 40, 25, 10), cabinRule: .paid, checkedKg: 15, checkedRule: .paid,
                site: "vivaaerobus.com"))
        add(Row(id: "copa", code: "CM", name: "Copa Airlines", country: "PA", region: .americas,
                cabin: (56, 36, 25, 10), site: "copaair.com"))
        add(Row(id: "avianca", code: "AV", name: "Avianca", country: "CO", region: .americas,
                personal: (45, 35, 20, nil), cabin: (55, 35, 25, 10), cabinRule: .fare, site: "avianca.com"))
        add(Row(id: "latam", code: "LA", name: "LATAM", country: "CL", region: .americas,
                personal: (45, 35, 20, nil), cabin: (55, 35, 25, 10), cabinRule: .fare, site: "latamairlines.com"))
        add(Row(id: "azul", code: "AD", name: "Azul", country: "BR", region: .americas,
                cabin: (55, 35, 25, 10), site: "voeazul.com.br"))
        add(Row(id: "gol", code: "G3", name: "GOL", country: "BR", region: .americas,
                cabin: (55, 35, 25, 10), site: "voegol.com.br"))
        add(Row(id: "aerolineas", code: "AR", name: "Aerolíneas Argentinas", country: "AR", region: .americas,
                cabin: (55, 35, 25, 8), site: "aerolineas.com.ar"))
        add(Row(id: "jetsmart", code: "JA", name: "JetSMART", country: "CL", region: .americas, lowCost: true,
                personal: (45, 35, 25, nil), cabin: (55, 35, 25, 10), cabinRule: .paid, checkedRule: .paid, site: "jetsmart.com"))
        add(Row(id: "sky", code: "H2", name: "SKY Airline", country: "CL", region: .americas, lowCost: true,
                personal: (45, 35, 20, nil), cabin: (55, 35, 25, 10), cabinRule: .paid, checkedRule: .paid, site: "skyairline.com"))
        add(Row(id: "caribbean", code: "BW", name: "Caribbean Airlines", country: "TT", region: .americas,
                personal: nil, cabin: (56, 36, 23, nil), site: "caribbean-airlines.com"))

        // ——— Африка ———
        add(Row(id: "ethiopian", code: "ET", name: "Ethiopian Airlines", country: "ET", region: .africa,
                cabin: (55, 40, 23, 7), checkedRule: .included, site: "ethiopianairlines.com"))
        add(Row(id: "egyptair", code: "MS", name: "EgyptAir", country: "EG", region: .africa, site: "egyptair.com"))
        add(Row(id: "royalairmaroc", code: "AT", name: "Royal Air Maroc", country: "MA", region: .africa,
                cabin: (55, 40, 25, 10), site: "royalairmaroc.com"))
        add(Row(id: "kenya", code: "KQ", name: "Kenya Airways", country: "KE", region: .africa,
                personal: nil, cabin: (56, 36, 23, 7), site: "kenya-airways.com"))
        add(Row(id: "saa", code: "SA", name: "South African Airways", country: "ZA", region: .africa,
                personal: nil, cabin: (56, 36, 23, 8), checkedRule: .included, site: "flysaa.com"))
        add(Row(id: "flysafair", code: "FA", name: "FlySafair", country: "ZA", region: .africa, lowCost: true,
                personal: nil, cabin: (56, 36, 23, 7), checkedKg: 20, checkedRule: .paid, site: "flysafair.co.za"))
        add(Row(id: "airalgerie", code: "AH", name: "Air Algérie", country: "DZ", region: .africa,
                cabin: (55, 35, 25, 10), site: "airalgerie.dz"))
        add(Row(id: "tunisair", code: "TU", name: "Tunisair", country: "TN", region: .africa,
                cabin: (55, 40, 20, 8), site: "tunisair.com"))
        add(Row(id: "rwandair", code: "WB", name: "RwandAir", country: "RW", region: .africa,
                personal: nil, cabin: (55, 40, 23, 7), site: "rwandair.com"))

        return list
    }

    // MARK: Градење

    private static func build(_ row: Row) -> Airline {
        var bags: [BagSpec] = []
        if let p = row.personal {
            bags.append(BagSpec(title: L("Мала торба / ранец", "Small bag / backpack"),
                                detail: L("Бесплатно · под седиштето", "Free · under the seat"),
                                height: p.h, width: p.w, depth: p.d, weightLimit: p.kg, kind: .personal, isFree: true,
                                key: "\(row.id).personal"))
        }
        if let c = row.cabin {
            let detail: String
            if let note = row.cabinNote {
                detail = L(note.0, note.1)
            } else {
                switch row.cabinRule {
                case .included: detail = L("Вклучено во билетот · горна полица", "Included · overhead bin")
                case .fare: detail = L("Според тарифата", "Depends on fare")
                case .paid: detail = L("Се доплаќа", "Extra fee")
                }
            }
            bags.append(BagSpec(title: L("Кабински куфер", "Cabin trolley"), detail: detail,
                                height: c.h, width: c.w, depth: c.d, weightLimit: c.kg, kind: .cabin,
                                isFree: row.cabinRule == .included, key: "\(row.id).cabin"))
        }
        let kg = Fmt.number(row.checkedKg)
        let checkedDetail: String
        switch row.checkedRule {
        case .included: checkedDetail = L("Вклучено · \(kg) kg", "Included · \(kg) kg")
        case .fare: checkedDetail = L("Според тарифата · \(kg) kg", "Depends on fare · \(kg) kg")
        case .paid: checkedDetail = L("Се доплаќа · \(kg) kg", "Extra fee · \(kg) kg")
        }
        bags.append(BagSpec(title: L("Чекиран куфер", "Checked suitcase"), detail: checkedDetail,
                            height: 78, width: 50, depth: 30, weightLimit: row.checkedKg, kind: .checked,
                            isFree: row.checkedRule == .included, key: "\(row.id).checked"))

        return Airline(id: row.id, code: row.code, name: row.name, country: row.country, region: row.region,
                       isLowCost: row.lowCost, website: row.site, bags: bags,
                       tip: row.tip.map { L($0.0, $0.1) })
    }

    private static func other() -> Airline {
        Airline(id: "other", code: "—", name: L("Друга авиокомпанија", "Other airline"), country: "", region: .europe,
                isLowCost: false, website: nil, bags: [
                    BagSpec(title: L("Мала торба / ранец", "Small bag / backpack"),
                            detail: L("Стандард во ЕУ · под седиштето", "EU standard · under the seat"),
                            height: 40, width: 30, depth: 15, weightLimit: nil, kind: .personal, isFree: true, key: "other.personal"),
                    BagSpec(title: L("Кабински куфер", "Cabin trolley"), detail: L("Најчеста мерка", "Most common size"),
                            height: 55, width: 40, depth: 23, weightLimit: 8, kind: .cabin, key: "other.cabin"),
                    BagSpec(title: L("Чекиран куфер", "Checked suitcase"), detail: "23 kg",
                            height: 78, width: 50, depth: 30, weightLimit: 23, kind: .checked, key: "other.checked")
                ], tip: nil)
    }

    // MARK: Кеш (по јазик) — листата се гради еднаш, не при секое цртање

    private static var cache: (language: String, list: [Airline], index: [String: Airline])?

    static var all: [Airline] {
        let language = AppLanguage.current.rawValue
        if let cache, cache.language == language { return cache.list }
        let list = rows.map(build).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } + [other()]
        let index = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        cache = (language, list, index)
        return list
    }

    static func find(_ id: String?) -> Airline? {
        guard let id else { return nil }
        _ = all
        return cache?.index[id]
    }

    static var popular: [Airline] {
        popularIDs.compactMap { find($0) }
    }

    static func search(_ text: String) -> [Airline] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return all }
        return all.filter { $0.searchText.contains(query) }
    }

    /// Багажи за кола, воз или автобус.
    static var groundBags: [BagSpec] {
        [
            BagSpec(title: L("Ранец", "Backpack"), detail: L("За кратки патувања", "For short trips"),
                    height: 45, width: 30, depth: 20, weightLimit: nil, kind: .backpack, key: "ground.backpack"),
            BagSpec(title: L("Кабински куфер", "Cabin trolley"), detail: L("Мал куфер на тркала", "Small wheeled case"),
                    height: 55, width: 40, depth: 23, weightLimit: nil, kind: .cabin, key: "ground.cabin"),
            BagSpec(title: L("Среден куфер", "Medium suitcase"), detail: L("За една недела", "For about a week"),
                    height: 66, width: 44, depth: 27, weightLimit: nil, kind: .suitcase, key: "ground.medium"),
            BagSpec(title: L("Голем куфер", "Large suitcase"), detail: L("За подолг престој", "For longer stays"),
                    height: 77, width: 50, depth: 30, weightLimit: nil, kind: .suitcase, key: "ground.large")
        ]
    }

    static func customBag() -> BagSpec {
        BagSpec(title: L("Мој багаж", "My bag"), detail: L("Сопствени димензии", "Custom size"),
                height: 55, width: 40, depth: 20, weightLimit: 10, kind: .custom, key: "custom")
    }

    /// Багаж според клуч, на тековниот јазик (за превод на зачувани патувања).
    static func spec(forKey key: String) -> BagSpec? {
        if key == "custom" { return customBag() }
        if key.hasPrefix("ground.") { return groundBags.first { $0.key == key } }
        let airlineID = key.split(separator: ".").first.map(String.init)
        return find(airlineID)?.bags.first { $0.key == key }
    }
}
