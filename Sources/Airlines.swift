import Foundation

struct Airline: Identifiable, Hashable {
    let id: String
    let name: String
    let isLowCost: Bool
    let bags: [BagSpec]
    let tip: String?
}

/// Правила за багаж (економска класа, Европа). Се менуваат често —
/// апликацијата секогаш потсетува да се проверат на сајтот на авиокомпанијата.
/// Последно ажурирање на податоците: октомври 2026.
enum Airlines {
    static let dataUpdated = "октомври 2026"

    static let all: [Airline] = [
        Airline(
            id: "wizz",
            name: "Wizz Air",
            isLowCost: true,
            bags: [
                BagSpec(title: "Мала торба / ранец", detail: "Бесплатно · под седиштето", height: 40, width: 30, depth: 20, weightLimit: 10, kind: .personal, isFree: true),
                BagSpec(title: "Кабински куфер", detail: "Со WIZZ Priority · горна полица", height: 55, width: 40, depth: 23, weightLimit: 10, kind: .cabin),
                BagSpec(title: "Чекиран куфер", detail: "Се доплаќа · 20 kg", height: 78, width: 50, depth: 30, weightLimit: 20, kind: .checked)
            ],
            tip: "Без Priority смееш само малата торба. Казната на излезот е околу 65 €."
        ),
        Airline(
            id: "ryanair",
            name: "Ryanair",
            isLowCost: true,
            bags: [
                BagSpec(title: "Мала торба / ранец", detail: "Бесплатно · под седиштето", height: 40, width: 30, depth: 20, weightLimit: nil, kind: .personal, isFree: true),
                BagSpec(title: "Кабински куфер", detail: "Со Priority · горна полица", height: 55, width: 40, depth: 20, weightLimit: 10, kind: .cabin),
                BagSpec(title: "Чекиран куфер", detail: "Се доплаќа · 20 kg", height: 78, width: 50, depth: 30, weightLimit: 20, kind: .checked)
            ],
            tip: "Тркалата, рачките и надворешните џебови влегуваат во мерката."
        ),
        Airline(
            id: "easyjet",
            name: "easyJet",
            isLowCost: true,
            bags: [
                BagSpec(title: "Торба под седиште", detail: "Бесплатно · под седиштето", height: 45, width: 36, depth: 20, weightLimit: 15, kind: .personal, isFree: true),
                BagSpec(title: "Голем кабински куфер", detail: "Се доплаќа или со FLEXI", height: 56, width: 45, depth: 25, weightLimit: 15, kind: .cabin),
                BagSpec(title: "Чекиран куфер", detail: "Се доплаќа · 23 kg", height: 78, width: 50, depth: 30, weightLimit: 23, kind: .checked)
            ],
            tip: "Up Front и Extra Legroom седиштата веќе не вклучуваат голем кабински куфер."
        ),
        Airline(
            id: "pegasus",
            name: "Pegasus",
            isLowCost: true,
            bags: [
                BagSpec(title: "Лична торба", detail: "Бесплатно · под седиштето", height: 40, width: 30, depth: 15, weightLimit: 3, kind: .personal, isFree: true),
                BagSpec(title: "Кабински куфер", detail: "Во пакет или се доплаќа", height: 55, width: 40, depth: 20, weightLimit: 8, kind: .cabin),
                BagSpec(title: "Чекиран куфер", detail: "Според тарифата · 20 kg", height: 78, width: 50, depth: 30, weightLimit: 20, kind: .checked)
            ],
            tip: "На меѓународни летови бесплатната торба смее до 3 kg."
        ),
        Airline(
            id: "eurowings",
            name: "Eurowings",
            isLowCost: true,
            bags: [
                BagSpec(title: "Мала торба / ранец", detail: "Бесплатно · под седиштето", height: 40, width: 30, depth: 25, weightLimit: nil, kind: .personal, isFree: true),
                BagSpec(title: "Кабински куфер", detail: "Од тарифата Smart", height: 55, width: 40, depth: 23, weightLimit: 8, kind: .cabin),
                BagSpec(title: "Чекиран куфер", detail: "Според тарифата · 23 kg", height: 78, width: 50, depth: 30, weightLimit: 23, kind: .checked)
            ],
            tip: nil
        ),
        Airline(
            id: "turkish",
            name: "Turkish Airlines",
            isLowCost: false,
            bags: [
                BagSpec(title: "Кабински куфер", detail: "Вклучено во билетот", height: 55, width: 40, depth: 23, weightLimit: 8, kind: .cabin, isFree: true),
                BagSpec(title: "Лична торба", detail: "Вклучено · под седиштето", height: 40, width: 30, depth: 15, weightLimit: 4, kind: .personal, isFree: true),
                BagSpec(title: "Чекиран куфер", detail: "Според тарифата · 23 kg", height: 78, width: 50, depth: 30, weightLimit: 23, kind: .checked)
            ],
            tip: nil
        ),
        Airline(
            id: "lufthansa",
            name: "Lufthansa",
            isLowCost: false,
            bags: [
                BagSpec(title: "Кабински куфер", detail: "Вклучено во билетот", height: 55, width: 40, depth: 23, weightLimit: 8, kind: .cabin, isFree: true),
                BagSpec(title: "Лична торба", detail: "Вклучено · под седиштето", height: 40, width: 30, depth: 10, weightLimit: nil, kind: .personal, isFree: true),
                BagSpec(title: "Чекиран куфер", detail: "Не е во Light тарифа · 23 kg", height: 78, width: 50, depth: 30, weightLimit: 23, kind: .checked)
            ],
            tip: nil
        ),
        Airline(
            id: "austrian",
            name: "Austrian",
            isLowCost: false,
            bags: [
                BagSpec(title: "Кабински куфер", detail: "Вклучено во билетот", height: 55, width: 40, depth: 23, weightLimit: 8, kind: .cabin, isFree: true),
                BagSpec(title: "Лична торба", detail: "Вклучено · под седиштето", height: 40, width: 30, depth: 10, weightLimit: nil, kind: .personal, isFree: true),
                BagSpec(title: "Чекиран куфер", detail: "Не е во Light тарифа · 23 kg", height: 78, width: 50, depth: 30, weightLimit: 23, kind: .checked)
            ],
            tip: nil
        ),
        Airline(
            id: "swiss",
            name: "SWISS",
            isLowCost: false,
            bags: [
                BagSpec(title: "Кабински куфер", detail: "Вклучено во билетот", height: 55, width: 40, depth: 23, weightLimit: 8, kind: .cabin, isFree: true),
                BagSpec(title: "Лична торба", detail: "Вклучено · под седиштето", height: 40, width: 30, depth: 15, weightLimit: nil, kind: .personal, isFree: true),
                BagSpec(title: "Чекиран куфер", detail: "Не е во Light тарифа · 23 kg", height: 78, width: 50, depth: 30, weightLimit: 23, kind: .checked)
            ],
            tip: nil
        ),
        Airline(
            id: "airserbia",
            name: "Air Serbia",
            isLowCost: false,
            bags: [
                BagSpec(title: "Кабински куфер", detail: "Вклучено во билетот", height: 55, width: 40, depth: 23, weightLimit: 8, kind: .cabin, isFree: true),
                BagSpec(title: "Лична торба", detail: "Вклучено · под седиштето", height: 40, width: 30, depth: 15, weightLimit: nil, kind: .personal, isFree: true),
                BagSpec(title: "Чекиран куфер", detail: "Според тарифата · 23 kg", height: 78, width: 50, depth: 30, weightLimit: 23, kind: .checked)
            ],
            tip: nil
        ),
        Airline(
            id: "other",
            name: "Друга",
            isLowCost: false,
            bags: [
                BagSpec(title: "Мала торба / ранец", detail: "Стандард во ЕУ · под седиштето", height: 40, width: 30, depth: 15, weightLimit: nil, kind: .personal, isFree: true),
                BagSpec(title: "Кабински куфер", detail: "Најчеста мерка", height: 55, width: 40, depth: 23, weightLimit: 8, kind: .cabin),
                BagSpec(title: "Чекиран куфер", detail: "23 kg", height: 78, width: 50, depth: 30, weightLimit: 23, kind: .checked)
            ],
            tip: nil
        )
    ]

    static func find(_ id: String?) -> Airline? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// Багажи за патување со кола, воз или автобус.
    static let groundBags: [BagSpec] = [
        BagSpec(title: "Ранец", detail: "За кратки патувања", height: 45, width: 30, depth: 20, weightLimit: nil, kind: .backpack),
        BagSpec(title: "Кабински куфер", detail: "Мал куфер на тркала", height: 55, width: 40, depth: 23, weightLimit: nil, kind: .cabin),
        BagSpec(title: "Среден куфер", detail: "За една недела", height: 66, width: 44, depth: 27, weightLimit: nil, kind: .suitcase),
        BagSpec(title: "Голем куфер", detail: "За подолг престој", height: 77, width: 50, depth: 30, weightLimit: nil, kind: .suitcase)
    ]

    static func customBag() -> BagSpec {
        BagSpec(title: "Мој багаж", detail: "Сопствени димензии", height: 55, width: 40, depth: 20, weightLimit: 10, kind: .custom)
    }
}
