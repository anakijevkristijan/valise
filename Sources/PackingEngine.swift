import Foundation

/// Паметна листа без AI — чиста логика според денови, време, превоз, багаж и активности.
enum PackingEngine {

    // MARK: Градител

    private struct Builder {
        var items: [PackingItem] = []

        mutating func add(_ name: String,
                          _ category: ItemCategory,
                          qty: Int = 1,
                          vol: Double,
                          kg: Double,
                          note: String? = nil,
                          worn: Int = 0) {
            guard qty > 0 else { return }
            if let index = items.firstIndex(where: { $0.name == name }) {
                items[index].quantity = max(items[index].quantity, qty)
                return
            }
            items.append(PackingItem(name: name,
                                     category: category,
                                     quantity: qty,
                                     note: note,
                                     unitVolume: vol,
                                     unitWeight: kg,
                                     wornCount: min(worn, qty)))
        }
    }

    // MARK: Генерирање

    static func generate(for trip: Trip) -> [PackingItem] {
        var b = Builder()

        let days = trip.dayCount
        let clothDays = trip.hasLaundry ? min(days, 4) : days
        let w = trip.weatherSummary
        let acts = Set(trip.activities)
        let isPlane = trip.transport == .plane
        let carryOnOnly = isPlane && trip.bag.kind != .checked
        let woman = trip.style == .woman
        let man = trip.style == .man
        let international = trip.isInternational
        let liquidsNote: String? = carryOnOnly ? "до 100 ml во рачен багаж" : nil

        // Временски услови (без податоци → умерено, со слоеви за секој случај)
        let minT = w.minTemp ?? 12
        let maxT = w.maxTemp ?? 22
        let chilly = minT < 15
        let cold = minT < 8
        let freezing = minT < 2 || w.hasSnow
        let warm = maxT >= 24
        let hot = maxT >= 28
        let rainy = (w.maxRainChance ?? 0) > 40 || w.rainyDays > 0 || !w.hasData

        // ── Документи
        if international {
            b.add("Пасош / лична карта", .documents, vol: 0.05, kg: 0.05, note: "провери ја важноста")
            b.add("Патничко здравствено осигурување", .documents, vol: 0.01, kg: 0.01)
        } else {
            b.add("Лична карта", .documents, vol: 0.02, kg: 0.02)
        }
        switch trip.transport {
        case .plane:
            b.add("Boarding pass", .documents, vol: 0.01, kg: 0.01, note: "зачувај го и офлајн")
        case .train, .bus:
            b.add("Билети", .documents, vol: 0.01, kg: 0.01)
        case .car:
            b.add("Возачка и сообраќајна дозвола", .documents, vol: 0.02, kg: 0.02)
            if international {
                b.add("Зелен картон", .documents, vol: 0.01, kg: 0.01)
            }
        }
        b.add("Потврда за сместување", .documents, vol: 0.01, kg: 0.01)
        b.add("Платежни картички", .documents, vol: 0.05, kg: 0.05, note: international ? "и малку готовина во локална валута" : nil)

        // ── Облека
        b.add("Маици", .clothing, qty: min(clothDays + 1 + (hot ? 1 : 0), 12), vol: 0.6, kg: 0.18, worn: 1)
        b.add("Долна облека", .clothing, qty: min(clothDays + 1, 12), vol: 0.1, kg: 0.05, worn: 1)
        b.add("Чорапи", .clothing, qty: min(clothDays + 1, 12), vol: 0.12, kg: 0.05, worn: 1)

        let bottoms = max(1, Int((Double(clothDays) / 2.5).rounded(.up)))
        if warm {
            b.add("Шорцеви / лесни панталони", .clothing, qty: bottoms, vol: 0.7, kg: 0.25)
            if minT < 18 {
                b.add("Долги панталони", .clothing, qty: 1, vol: 1.2, kg: 0.5, worn: 1)
            }
        } else {
            b.add("Панталони / фармерки", .clothing, qty: bottoms, vol: 1.3, kg: 0.55, worn: 1)
        }
        if woman && (warm || acts.contains(.dining)) {
            b.add("Фустан / сукња", .clothing, qty: max(1, days / 3), vol: 0.8, kg: 0.25)
        }
        b.add("Пижама", .clothing, vol: 0.8, kg: 0.25)

        if chilly {
            b.add("Џемпер / дуксер", .clothing, qty: days > 5 ? 2 : 1, vol: 1.6, kg: 0.45)
        }
        if cold {
            b.add("Топла јакна", .clothing, vol: 5, kg: 1.2, worn: 1)
        } else if minT < 17 {
            b.add("Лесна јакна", .clothing, vol: 2, kg: 0.5, worn: 1)
        }
        if freezing {
            b.add("Капа, шал и ракавици", .clothing, vol: 1, kg: 0.3)
            b.add("Термо долна облека", .clothing, qty: 2, vol: 0.4, kg: 0.15)
        }

        // ── Обувки
        b.add("Удобни патики", .shoes, vol: 4, kg: 0.8, worn: 1)
        if warm || acts.contains(.beach) {
            b.add("Сандали / папучи", .shoes, vol: 1.5, kg: 0.4)
        }

        // ── Хигиена
        b.add("Четка и паста за заби", .toiletries, vol: 0.2, kg: 0.12)
        b.add("Дезодоранс", .toiletries, vol: 0.2, kg: 0.12, note: liquidsNote)
        b.add("Шампон и гел за туширање", .toiletries, vol: carryOnOnly ? 0.25 : 0.5, kg: carryOnOnly ? 0.2 : 0.5, note: carryOnOnly ? "патни пакувања до 100 ml" : nil)
        b.add("Крема за лице и тело", .toiletries, vol: 0.15, kg: 0.12, note: liquidsNote)
        b.add("Чешел / четка за коса", .toiletries, vol: 0.2, kg: 0.08)
        if man {
            b.add("Прибор за бричење", .toiletries, vol: 0.3, kg: 0.2)
        }
        if woman {
            b.add("Шминка и отстранувач", .toiletries, vol: 0.6, kg: 0.35, note: liquidsNote)
            b.add("Додатоци за коса", .toiletries, vol: 0.1, kg: 0.05)
            b.add("Женски хигиенски производи", .toiletries, vol: 0.3, kg: 0.1)
        }
        if carryOnOnly {
            b.add("Проѕирна кеса за течности (1 L)", .toiletries, vol: 0.05, kg: 0.02, note: "за безбедносната контрола")
        }
        if warm || acts.contains(.beach) || acts.contains(.hiking) {
            b.add("Крема за сончање SPF 50", .toiletries, vol: 0.2, kg: 0.2, note: liquidsNote)
        }

        // ── Здравје
        b.add("Лични лекови", .health, vol: 0.2, kg: 0.1, note: isPlane ? "секогаш во рачен багаж" : nil)
        b.add("Мини прва помош", .health, vol: 0.3, kg: 0.15, note: "фластери, аналгетик, нешто за стомак")

        // ── Електроника
        b.add("Полнач и кабел за телефон", .electronics, vol: 0.15, kg: 0.1)
        b.add("Powerbank", .electronics, vol: 0.25, kg: 0.25, note: isPlane ? "само во рачен багаж" : nil)
        b.add("Слушалки", .electronics, vol: 0.2, kg: 0.06)
        if let plug = adapterType(from: trip.origin?.countryCode ?? "MK", to: trip.destination.countryCode) {
            b.add("Адаптер за штекер (тип \(plug))", .electronics, vol: 0.1, kg: 0.08, note: "различни штекери на дестинацијата")
        }

        // ── Додатоци
        if warm || acts.contains(.beach) {
            b.add("Сончеви очила", .accessories, vol: 0.2, kg: 0.05)
        }
        if hot {
            b.add("Капа за сонце", .accessories, vol: 0.5, kg: 0.1)
        }
        if rainy {
            if acts.contains(.hiking) {
                b.add("Кабаница", .accessories, vol: 0.6, kg: 0.3)
            } else {
                b.add("Мал склопувачки чадор", .accessories, vol: 0.5, kg: 0.3, note: w.hasData ? "најавени врнежи" : "за секој случај")
            }
        }
        b.add("Кеса за валкана облека", .accessories, vol: 0.05, kg: 0.03)

        // ── Активности
        if acts.contains(.photo) {
            b.add("Комбинации за слики", .clothing, qty: max(1, days / 3), vol: 0.8, kg: 0.3, note: "неутрални тонови се спојуваат лесно")
            b.add("Мини статив / држач за телефон", .activity, vol: 0.3, kg: 0.15)
            b.add("Крпче за чистење леќа", .activity, vol: 0.01, kg: 0.01)
            b.add("Powerbank", .electronics, qty: 1, vol: 0.25, kg: 0.25, note: isPlane ? "само во рачен багаж" : nil)
        }
        if acts.contains(.walking) {
            b.add("Мало ранче / торбичка за град", .accessories, vol: 0.8, kg: 0.25)
            b.add("Шише за вода", .accessories, vol: 0.5, kg: 0.12, note: isPlane ? "празно на контрола" : nil)
        }
        if acts.contains(.dining) {
            if woman {
                b.add("Фустан за вечер", .clothing, qty: max(1, days / 4), vol: 1, kg: 0.35)
                b.add("Елегантни обувки", .shoes, vol: 2.5, kg: 0.5)
                b.add("Накит", .accessories, vol: 0.1, kg: 0.05)
            } else if man {
                b.add("Кошула", .clothing, qty: max(1, days / 3), vol: 0.9, kg: 0.25)
                b.add("Елегантни панталони", .clothing, vol: 1.2, kg: 0.45)
                b.add("Елегантни чевли", .shoes, vol: 4, kg: 0.9)
            } else {
                b.add("Елегантен комплет", .clothing, qty: max(1, days / 4), vol: 1.2, kg: 0.4)
                b.add("Елегантни обувки", .shoes, vol: 3, kg: 0.7)
            }
            b.add("Спреј против гужвање", .toiletries, vol: 0.15, kg: 0.12, note: liquidsNote)
            b.add("Парфем", .toiletries, vol: 0.1, kg: 0.1, note: carryOnOnly ? "патно пакување до 100 ml" : nil)
        }
        if acts.contains(.work) {
            b.add("Лаптоп", .electronics, vol: 1.6, kg: 1.5, note: isPlane ? "го вадиш на контрола" : nil)
            b.add("Полнач за лаптоп", .electronics, vol: 0.4, kg: 0.35)
            b.add("USB‑C хаб / HDMI адаптер", .electronics, vol: 0.1, kg: 0.08)
            b.add("Безжично глувче", .electronics, vol: 0.1, kg: 0.08)
        }
        if acts.contains(.fitness) {
            b.add("Спортска облека (комплет)", .activity, qty: max(1, (days + 1) / 2), vol: 0.7, kg: 0.25)
            b.add("Патики за тренинг", .shoes, vol: 3.5, kg: 0.7)
        }
        if acts.contains(.beach) {
            b.add("Костим за капење", .activity, qty: days > 3 ? 2 : 1, vol: 0.2, kg: 0.1)
            b.add("Пешкир за плажа", .activity, vol: 2, kg: 0.45, note: "лесен микрофибер штеди простор")
            b.add("After-sun лосион", .toiletries, vol: 0.2, kg: 0.2, note: liquidsNote)
            b.add("Водоотпорна футрола за телефон", .activity, vol: 0.05, kg: 0.03)
        }
        if acts.contains(.hiking) {
            b.add("Планинарски чевли", .shoes, vol: 5, kg: 1.1)
            b.add("Технички / термо слој", .activity, vol: 1, kg: 0.3)
            b.add("Челна ламба", .activity, vol: 0.1, kg: 0.08)
            b.add("Мал ранец за пешачење", .activity, vol: 1, kg: 0.4)
            b.add("Шише за вода", .accessories, vol: 0.5, kg: 0.12, note: isPlane ? "празно на контрола" : nil)
        }
        if acts.contains(.nightlife) {
            b.add("Облека за излегување", .clothing, qty: max(1, days / 3), vol: 0.8, kg: 0.3)
            b.add("Чепчиња за уши", .accessories, vol: 0.02, kg: 0.01, note: "за мирен сон после тоа")
        }

        // ── За патот
        switch trip.transport {
        case .plane:
            b.add("Грицки за на пат", .journey, vol: 0.3, kg: 0.2)
        case .car:
            b.add("Полнач за кола", .journey, vol: 0.05, kg: 0.05)
            b.add("Вода и грицки за пат", .journey, vol: 1, kg: 0.8)
            b.add("Готовина за патарина", .journey, vol: 0.01, kg: 0.01)
        case .train, .bus:
            b.add("Вода и грицки за пат", .journey, vol: 1, kg: 0.8)
            if trip.dayCount > 1 {
                b.add("Перница за врат", .journey, vol: 1.5, kg: 0.2)
            }
        }

        return b.items
    }

    // MARK: Предлози по промена на прогнозата

    /// Предмети што логиката сега би ги додала, а ги нема во листата.
    static func suggestions(for trip: Trip) -> [PackingItem] {
        let existing = Set(trip.items.map { $0.name.lowercased() })
        let dismissed = Set(trip.dismissedSuggestions.map { $0.lowercased() })
        return generate(for: trip).filter {
            !existing.contains($0.name.lowercased()) && !dismissed.contains($0.name.lowercased())
        }
    }

    /// Нова листа, а се задржува што е веќе спакувано и што е додадено рачно.
    static func regenerate(_ trip: Trip) -> [PackingItem] {
        let packedNames = Set(trip.items.filter(\.isPacked).map { $0.name.lowercased() })
        var fresh = generate(for: trip).map { item -> PackingItem in
            var copy = item
            copy.isPacked = packedNames.contains(item.name.lowercased())
            return copy
        }
        let freshNames = Set(fresh.map { $0.name.lowercased() })
        fresh.append(contentsOf: trip.items.filter { $0.isCustom && !freshNames.contains($0.name.lowercased()) })
        return fresh
    }

    // MARK: Штекери

    private static let plugTypes: [String: String] = [
        "GB": "G", "IE": "G", "MT": "G", "CY": "G", "AE": "G", "QA": "G", "SG": "G", "HK": "G", "MY": "G",
        "US": "A/B", "CA": "A/B", "MX": "A/B", "JP": "A/B", "TW": "A/B", "PH": "A/B",
        "CH": "J", "LI": "J",
        "AU": "I", "NZ": "I", "CN": "A/I", "AR": "I",
        "IL": "H", "ZA": "M/N", "BR": "N", "IN": "D/M", "TH": "A/B/C"
    ]

    /// nil = истиот европски штекер (C/F), не треба адаптер.
    static func adapterType(from origin: String, to destination: String) -> String? {
        let from = plugTypes[origin.uppercased()]
        let to = plugTypes[destination.uppercased()]
        if from == to { return nil }
        return to ?? "C/F"
    }

    // MARK: Излез од дома

    static func defaultExitChecklist() -> [ChecklistItem] {
        [
            ChecklistItem(title: "Шпорет и рерна исклучени", icon: "flame"),
            ChecklistItem(title: "Пегла и фен извадени од струја", icon: "powerplug"),
            ChecklistItem(title: "Бојлер исклучен", icon: "thermometer.medium"),
            ChecklistItem(title: "Главен вентил за вода затворен", icon: "drop"),
            ChecklistItem(title: "Прозорци и балкон затворени", icon: "window.vertical.closed"),
            ChecklistItem(title: "Ѓубрето фрлено", icon: "trash"),
            ChecklistItem(title: "Фрижидерот без расипливо", icon: "refrigerator"),
            ChecklistItem(title: "Цвеќињата наводнети", icon: "leaf"),
            ChecklistItem(title: "Полначите извадени од штекер", icon: "bolt.slash"),
            ChecklistItem(title: "Пасош, паричник и телефон кај тебе", icon: "wallet.pass"),
            ChecklistItem(title: "Вратата заклучена, клучевите кај тебе", icon: "key")
        ]
    }

    // MARK: Совет за багажот

    enum FitLevel { case roomy, snug, over }

    static func fitLevel(for trip: Trip) -> FitLevel {
        let r = trip.fillRatio
        let wr = trip.weightRatio ?? 0
        if r > 1.0 || wr > 1.0 { return .over }
        if r > 0.85 || wr > 0.9 { return .snug }
        return .roomy
    }

    static func advice(for trip: Trip) -> String {
        let over = trip.fillRatio > 1.0
        let heavy = (trip.weightRatio ?? 0) > 1.0
        switch fitLevel(for: trip) {
        case .roomy:
            return "Има простор. Сè собира без туркање."
        case .snug:
            return "Тесно, но собира. Свиткај ја облеката во ролни и облечи го најобемното на пат."
        case .over:
            if heavy && !over, let limit = trip.bag.weightLimit {
                return "Над дозволените \(Fmt.number(limit)) kg. Облечи ги најтешките работи на пат или намали ги количините."
            }
            if trip.bag.kind == .personal {
                return "Премногу за малата торба. Намали количини, облечи го обемното на пат или земи кабински куфер — однапред е многу поевтино отколку на излезот."
            }
            return "Не собира сè. Намали количини или размисли за поголем багаж."
        }
    }
}
