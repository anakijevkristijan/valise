import Foundation

struct Airline: Identifiable, Hashable {
    let id: String
    let name: String
    let isLowCost: Bool
    let bags: [BagSpec]
    let tip: String?
}

/// Правила за багаж (економска класа, Европа), октомври 2026.
/// Се пресметуваат при секој пристап — за да се на тековниот јазик.
enum Airlines {
    static var dataUpdated: String { L("октомври 2026", "October 2026") }

    private static func personal(_ airline: String, _ h: Double, _ w: Double, _ d: Double, _ kg: Double?, free: Bool = true, detail: String? = nil) -> BagSpec {
        BagSpec(title: L("Мала торба / ранец", "Small bag / backpack"),
                detail: detail ?? L("Бесплатно · под седиштето", "Free · under the seat"),
                height: h, width: w, depth: d, weightLimit: kg, kind: .personal, isFree: free,
                key: "\(airline).personal")
    }

    private static func cabin(_ airline: String, _ h: Double, _ w: Double, _ d: Double, _ kg: Double?, detail: String, free: Bool = false, title: String? = nil) -> BagSpec {
        BagSpec(title: title ?? L("Кабински куфер", "Cabin trolley"),
                detail: detail,
                height: h, width: w, depth: d, weightLimit: kg, kind: .cabin, isFree: free,
                key: "\(airline).cabin")
    }

    private static func checked(_ airline: String, _ kg: Double, detail: String) -> BagSpec {
        BagSpec(title: L("Чекиран куфер", "Checked suitcase"),
                detail: detail,
                height: 78, width: 50, depth: 30, weightLimit: kg, kind: .checked,
                key: "\(airline).checked")
    }

    static var all: [Airline] {
        let paid20 = L("Се доплаќа · 20 kg", "Extra fee · 20 kg")
        let paid23 = L("Се доплаќа · 23 kg", "Extra fee · 23 kg")
        let fare20 = L("Според тарифата · 20 kg", "Depends on fare · 20 kg")
        let fare23 = L("Според тарифата · 23 kg", "Depends on fare · 23 kg")
        let notLight = L("Не е во Light тарифа · 23 kg", "Not in Light fares · 23 kg")
        let included = L("Вклучено во билетот", "Included in the ticket")
        let includedSeat = L("Вклучено · под седиштето", "Included · under the seat")

        return [
            Airline(id: "wizz", name: "Wizz Air", isLowCost: true, bags: [
                personal("wizz", 40, 30, 20, 10),
                cabin("wizz", 55, 40, 23, 10, detail: L("Со WIZZ Priority · горна полица", "With WIZZ Priority · overhead bin")),
                checked("wizz", 20, detail: paid20)
            ], tip: L("Без Priority смееш само малата торба. Казната на излезот е околу 65 €.",
                      "Without Priority you may only bring the small bag. The gate fee is around €65.")),
            Airline(id: "ryanair", name: "Ryanair", isLowCost: true, bags: [
                personal("ryanair", 40, 30, 20, nil),
                cabin("ryanair", 55, 40, 20, 10, detail: L("Со Priority · горна полица", "With Priority · overhead bin")),
                checked("ryanair", 20, detail: paid20)
            ], tip: L("Тркалата, рачките и надворешните џебови влегуваат во мерката.",
                      "Wheels, handles and outer pockets count towards the size.")),
            Airline(id: "easyjet", name: "easyJet", isLowCost: true, bags: [
                personal("easyjet", 45, 36, 20, 15),
                cabin("easyjet", 56, 45, 25, 15, detail: L("Се доплаќа или со FLEXI", "Extra fee or with FLEXI"), title: L("Голем кабински куфер", "Large cabin bag")),
                checked("easyjet", 23, detail: paid23)
            ], tip: L("Up Front и Extra Legroom седиштата веќе не вклучуваат голем кабински куфер.",
                      "Up Front and Extra Legroom seats no longer include a large cabin bag.")),
            Airline(id: "pegasus", name: "Pegasus", isLowCost: true, bags: [
                personal("pegasus", 40, 30, 15, 3),
                cabin("pegasus", 55, 40, 20, 8, detail: L("Во пакет или се доплаќа", "In a bundle or extra fee")),
                checked("pegasus", 20, detail: fare20)
            ], tip: L("На меѓународни летови бесплатната торба смее до 3 kg.",
                      "On international flights the free bag may weigh up to 3 kg.")),
            Airline(id: "eurowings", name: "Eurowings", isLowCost: true, bags: [
                personal("eurowings", 40, 30, 25, nil),
                cabin("eurowings", 55, 40, 23, 8, detail: L("Од тарифата Smart", "From the Smart fare")),
                checked("eurowings", 23, detail: fare23)
            ], tip: nil),
            Airline(id: "turkish", name: "Turkish Airlines", isLowCost: false, bags: [
                cabin("turkish", 55, 40, 23, 8, detail: included, free: true),
                personal("turkish", 40, 30, 15, 4, detail: includedSeat),
                checked("turkish", 23, detail: fare23)
            ], tip: nil),
            Airline(id: "lufthansa", name: "Lufthansa", isLowCost: false, bags: [
                cabin("lufthansa", 55, 40, 23, 8, detail: included, free: true),
                personal("lufthansa", 40, 30, 10, nil, detail: includedSeat),
                checked("lufthansa", 23, detail: notLight)
            ], tip: nil),
            Airline(id: "austrian", name: "Austrian", isLowCost: false, bags: [
                cabin("austrian", 55, 40, 23, 8, detail: included, free: true),
                personal("austrian", 40, 30, 10, nil, detail: includedSeat),
                checked("austrian", 23, detail: notLight)
            ], tip: nil),
            Airline(id: "swiss", name: "SWISS", isLowCost: false, bags: [
                cabin("swiss", 55, 40, 23, 8, detail: included, free: true),
                personal("swiss", 40, 30, 15, nil, detail: includedSeat),
                checked("swiss", 23, detail: notLight)
            ], tip: nil),
            Airline(id: "airserbia", name: "Air Serbia", isLowCost: false, bags: [
                cabin("airserbia", 55, 40, 23, 8, detail: included, free: true),
                personal("airserbia", 40, 30, 15, nil, detail: includedSeat),
                checked("airserbia", 23, detail: fare23)
            ], tip: nil),
            Airline(id: "other", name: L("Друга", "Other"), isLowCost: false, bags: [
                personal("other", 40, 30, 15, nil, detail: L("Стандард во ЕУ · под седиштето", "EU standard · under the seat")),
                cabin("other", 55, 40, 23, 8, detail: L("Најчеста мерка", "Most common size")),
                checked("other", 23, detail: L("23 kg", "23 kg"))
            ], tip: nil)
        ]
    }

    static func find(_ id: String?) -> Airline? {
        guard let id else { return nil }
        return all.first { $0.id == id }
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
