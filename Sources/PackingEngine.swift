import Foundation

// MARK: - Каталог (имиња на двата јазика)

enum Catalog {
    static func name(_ key: String) -> String? {
        if key.hasPrefix("adapter.") {
            let type = String(key.dropFirst("adapter.".count))
            return L("Адаптер за штекер (тип \(type))", "Plug adapter (type \(type))")
        }
        guard let pair = names[key] else { return nil }
        return AppLanguage.current == .mk ? pair.0 : pair.1
    }

    static func note(_ key: String) -> String? {
        guard let pair = notes[key] else { return nil }
        return AppLanguage.current == .mk ? pair.0 : pair.1
    }

    /// Работи што може да ги носи само еден од друштвото.
    static func isShareable(_ key: String) -> Bool {
        key.hasPrefix("adapter.") || shareable.contains(key)
    }

    private static let shareable: Set<String> = [
        "shampoo", "sunscreen", "afterSun", "firstAid", "umbrella", "booking", "tollCash",
        "carCharger", "waterSnacks", "wrinkleSpray", "tripod", "snacks", "powerbank", "usbHub"
    ]

    static func exitTitle(_ key: String) -> String? {
        guard let pair = exit[key] else { return nil }
        return AppLanguage.current == .mk ? pair.0 : pair.1
    }

    private static let names: [String: (String, String)] = [
        // Документи
        "passport": ("Пасош / лична карта", "Passport / ID card"),
        "insurance": ("Патничко здравствено осигурување", "Travel health insurance"),
        "idCard": ("Лична карта", "ID card"),
        "boardingPass": ("Boarding pass", "Boarding pass"),
        "tickets": ("Билети", "Tickets"),
        "carDocs": ("Возачка и сообраќајна дозвола", "Driving licence and car papers"),
        "greenCard": ("Зелен картон", "Green card (car insurance)"),
        "booking": ("Потврда за сместување", "Accommodation confirmation"),
        "cards": ("Платежни картички", "Payment cards"),
        // Облека
        "tshirts": ("Маици", "T-shirts"),
        "underwear": ("Долна облека", "Underwear"),
        "socks": ("Чорапи", "Socks"),
        "shorts": ("Шорцеви / лесни панталони", "Shorts / light trousers"),
        "longTrousers": ("Долги панталони", "Long trousers"),
        "trousers": ("Панталони / фармерки", "Trousers / jeans"),
        "dress": ("Фустан / сукња", "Dress / skirt"),
        "pyjamas": ("Пижама", "Pyjamas"),
        "sweater": ("Џемпер / дуксер", "Sweater / hoodie"),
        "warmJacket": ("Топла јакна", "Warm jacket"),
        "lightJacket": ("Лесна јакна", "Light jacket"),
        "winterSet": ("Капа, шал и ракавици", "Hat, scarf and gloves"),
        "thermals": ("Термо долна облека", "Thermal base layer"),
        "photoOutfits": ("Комбинации за слики", "Outfits for photos"),
        "eveningDress": ("Фустан за вечер", "Evening dress"),
        "shirt": ("Кошула", "Shirt"),
        "smartTrousers": ("Елегантни панталони", "Smart trousers"),
        "smartOutfit": ("Елегантен комплет", "Smart outfit"),
        "nightOutfit": ("Облека за излегување", "Going-out outfit"),
        // Обувки
        "sneakers": ("Удобни патики", "Comfortable sneakers"),
        "sandals": ("Сандали / папучи", "Sandals / flip-flops"),
        "smartShoes": ("Елегантни обувки", "Elegant shoes"),
        "dressShoes": ("Елегантни чевли", "Dress shoes"),
        "trainingShoes": ("Патики за тренинг", "Training shoes"),
        "hikingBoots": ("Планинарски чевли", "Hiking boots"),
        // Хигиена
        "toothbrush": ("Четка и паста за заби", "Toothbrush and toothpaste"),
        "deodorant": ("Дезодоранс", "Deodorant"),
        "shampoo": ("Шампон и гел за туширање", "Shampoo and shower gel"),
        "cream": ("Крема за лице и тело", "Face and body cream"),
        "comb": ("Чешел / четка за коса", "Comb / hairbrush"),
        "shaving": ("Прибор за бричење", "Shaving kit"),
        "makeup": ("Шминка и отстранувач", "Make-up and remover"),
        "hairAccessories": ("Додатоци за коса", "Hair accessories"),
        "feminine": ("Женски хигиенски производи", "Feminine hygiene products"),
        "liquidsBag": ("Проѕирна кеса за течности (1 L)", "Clear liquids bag (1 L)"),
        "sunscreen": ("Крема за сончање SPF 50", "Sunscreen SPF 50"),
        "wrinkleSpray": ("Спреј против гужвање", "Wrinkle-release spray"),
        "perfume": ("Парфем", "Perfume"),
        "afterSun": ("After-sun лосион", "After-sun lotion"),
        // Здравје
        "meds": ("Лични лекови", "Personal medication"),
        "firstAid": ("Мини прва помош", "Mini first-aid kit"),
        // Електроника
        "phoneCharger": ("Полнач и кабел за телефон", "Phone charger and cable"),
        "powerbank": ("Powerbank", "Power bank"),
        "headphones": ("Слушалки", "Headphones"),
        "laptop": ("Лаптоп", "Laptop"),
        "laptopCharger": ("Полнач за лаптоп", "Laptop charger"),
        "usbHub": ("USB‑C хаб / HDMI адаптер", "USB‑C hub / HDMI adapter"),
        "mouse": ("Безжично глувче", "Wireless mouse"),
        // Додатоци
        "sunglasses": ("Сончеви очила", "Sunglasses"),
        "sunHat": ("Капа за сонце", "Sun hat"),
        "raincoat": ("Кабаница", "Rain jacket"),
        "umbrella": ("Мал склопувачки чадор", "Compact umbrella"),
        "laundryBag": ("Кеса за валкана облека", "Laundry bag"),
        "daypack": ("Мало ранче / торбичка за град", "Small daypack / city bag"),
        "bottle": ("Шише за вода", "Water bottle"),
        "jewellery": ("Накит", "Jewellery"),
        "earplugs": ("Чепчиња за уши", "Earplugs"),
        // Активности
        "tripod": ("Мини статив / држач за телефон", "Mini tripod / phone mount"),
        "lensCloth": ("Крпче за чистење леќа", "Lens cloth"),
        "sportswear": ("Спортска облека (комплет)", "Sportswear (set)"),
        "swimwear": ("Костим за капење", "Swimwear"),
        "beachTowel": ("Пешкир за плажа", "Beach towel"),
        "waterproofCase": ("Водоотпорна футрола за телефон", "Waterproof phone case"),
        "techLayer": ("Технички / термо слој", "Technical / thermal layer"),
        "headlamp": ("Челна ламба", "Head torch"),
        "hikingPack": ("Мал ранец за пешачење", "Hiking daypack"),
        // За патот
        "snacks": ("Грицки за на пат", "Snacks for the journey"),
        "carCharger": ("Полнач за кола", "Car charger"),
        "waterSnacks": ("Вода и грицки за пат", "Water and snacks for the road"),
        "tollCash": ("Готовина за патарина", "Cash for tolls"),
        "neckPillow": ("Перница за врат", "Neck pillow")
    ]

    private static let notes: [String: (String, String)] = [
        "checkValidity": ("провери ја важноста", "check it's still valid"),
        "offline": ("зачувај го и офлајн", "save it offline too"),
        "localCash": ("и малку готовина во локална валута", "plus a little local cash"),
        "neutralTones": ("неутрални тонови се спојуваат лесно", "neutral tones mix and match"),
        "liquids100": ("до 100 ml во рачен багаж", "up to 100 ml in hand luggage"),
        "travelSizes": ("патни пакувања до 100 ml", "travel sizes up to 100 ml"),
        "security": ("за безбедносната контрола", "for the security check"),
        "medsCarryOn": ("секогаш во рачен багаж", "always in hand luggage"),
        "firstAidNote": ("фластери, аналгетик, нешто за стомак", "plasters, painkillers, something for the stomach"),
        "handOnly": ("само во рачен багаж", "hand luggage only"),
        "plugNote": ("различни штекери на дестинацијата", "different sockets at your destination"),
        "laptopSecurity": ("го вадиш на контрола", "take it out at security"),
        "rainForecast": ("најавени врнежи", "rain in the forecast"),
        "justInCase": ("за секој случај", "just in case"),
        "emptyAtSecurity": ("празно на контрола", "empty at security"),
        "earplugsNote": ("за мирен сон после тоа", "for a quiet night afterwards"),
        "microfiber": ("лесен микрофибер штеди простор", "light microfibre saves space")
    ]

    private static let exit: [String: (String, String)] = [
        "stove": ("Шпорет и рерна исклучени", "Stove and oven off"),
        "iron": ("Пегла и фен извадени од струја", "Iron and hairdryer unplugged"),
        "boiler": ("Бојлер исклучен", "Water heater off"),
        "water": ("Главен вентил за вода затворен", "Main water valve closed"),
        "windows": ("Прозорци и балкон затворени", "Windows and balcony closed"),
        "trash": ("Ѓубрето фрлено", "Rubbish taken out"),
        "fridge": ("Фрижидерот без расипливо", "Nothing perishable in the fridge"),
        "plants": ("Цвеќињата наводнети", "Plants watered"),
        "chargers": ("Полначите извадени од штекер", "Chargers unplugged"),
        "essentials": ("Пасош, паричник и телефон кај тебе", "Passport, wallet and phone with you"),
        "door": ("Вратата заклучена, клучевите кај тебе", "Door locked, keys with you")
    ]
}

/// Паметна листа без AI — чиста логика според денови, време, превоз, багаж и активности.
enum PackingEngine {

    // MARK: Градител

    private struct Builder {
        var items: [PackingItem] = []

        mutating func add(_ key: String,
                          _ category: ItemCategory,
                          qty: Int = 1,
                          vol: Double,
                          kg: Double,
                          note: String? = nil,
                          worn: Int = 0) {
            guard qty > 0 else { return }
            if let index = items.firstIndex(where: { $0.key == key }) {
                items[index].quantity = max(items[index].quantity, qty)
                return
            }
            items.append(PackingItem(name: Catalog.name(key) ?? key,
                                     category: category,
                                     quantity: qty,
                                     note: note.flatMap { Catalog.note($0) },
                                     unitVolume: vol,
                                     unitWeight: kg,
                                     wornCount: min(worn, qty),
                                     key: key,
                                     noteKey: note))
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
        let liquids: String? = carryOnOnly ? "liquids100" : nil

        let minT = w.minTemp ?? 12
        let maxT = w.maxTemp ?? 22
        let chilly = minT < 15
        let cold = minT < 8
        let freezing = minT < 2 || w.hasSnow
        let warm = maxT >= 24
        let hot = maxT >= 28
        let rainy = (w.maxRainChance ?? 0) > 40 || w.rainyDays > 0 || !w.hasData

        // Документи
        if international {
            b.add("passport", .documents, vol: 0.05, kg: 0.05, note: "checkValidity")
            b.add("insurance", .documents, vol: 0.01, kg: 0.01)
        } else {
            b.add("idCard", .documents, vol: 0.02, kg: 0.02)
        }
        switch trip.transport {
        case .plane:
            b.add("boardingPass", .documents, vol: 0.01, kg: 0.01, note: "offline")
        case .train, .bus:
            b.add("tickets", .documents, vol: 0.01, kg: 0.01)
        case .car:
            b.add("carDocs", .documents, vol: 0.02, kg: 0.02)
            if international { b.add("greenCard", .documents, vol: 0.01, kg: 0.01) }
        }
        b.add("booking", .documents, vol: 0.01, kg: 0.01)
        b.add("cards", .documents, vol: 0.05, kg: 0.05, note: international ? "localCash" : nil)

        // Облека
        b.add("tshirts", .clothing, qty: min(clothDays + 1 + (hot ? 1 : 0), 12), vol: 0.6, kg: 0.18, worn: 1)
        b.add("underwear", .clothing, qty: min(clothDays + 1, 12), vol: 0.1, kg: 0.05, worn: 1)
        b.add("socks", .clothing, qty: min(clothDays + 1, 12), vol: 0.12, kg: 0.05, worn: 1)

        let bottoms = max(1, Int((Double(clothDays) / 2.5).rounded(.up)))
        if warm {
            b.add("shorts", .clothing, qty: bottoms, vol: 0.7, kg: 0.25)
            if minT < 18 { b.add("longTrousers", .clothing, vol: 1.2, kg: 0.5, worn: 1) }
        } else {
            b.add("trousers", .clothing, qty: bottoms, vol: 1.3, kg: 0.55, worn: 1)
        }
        if woman && (warm || acts.contains(.dining)) {
            b.add("dress", .clothing, qty: max(1, days / 3), vol: 0.8, kg: 0.25)
        }
        b.add("pyjamas", .clothing, vol: 0.8, kg: 0.25)
        if chilly { b.add("sweater", .clothing, qty: days > 5 ? 2 : 1, vol: 1.6, kg: 0.45) }
        if cold {
            b.add("warmJacket", .clothing, vol: 5, kg: 1.2, worn: 1)
        } else if minT < 17 {
            b.add("lightJacket", .clothing, vol: 2, kg: 0.5, worn: 1)
        }
        if freezing {
            b.add("winterSet", .clothing, vol: 1, kg: 0.3)
            b.add("thermals", .clothing, qty: 2, vol: 0.4, kg: 0.15)
        }

        // Обувки
        b.add("sneakers", .shoes, vol: 4, kg: 0.8, worn: 1)
        if warm || acts.contains(.beach) { b.add("sandals", .shoes, vol: 1.5, kg: 0.4) }

        // Хигиена
        b.add("toothbrush", .toiletries, vol: 0.2, kg: 0.12)
        b.add("deodorant", .toiletries, vol: 0.2, kg: 0.12, note: liquids)
        b.add("shampoo", .toiletries, vol: carryOnOnly ? 0.25 : 0.5, kg: carryOnOnly ? 0.2 : 0.5, note: carryOnOnly ? "travelSizes" : nil)
        b.add("cream", .toiletries, vol: 0.15, kg: 0.12, note: liquids)
        b.add("comb", .toiletries, vol: 0.2, kg: 0.08)
        if man { b.add("shaving", .toiletries, vol: 0.3, kg: 0.2) }
        if woman {
            b.add("makeup", .toiletries, vol: 0.6, kg: 0.35, note: liquids)
            b.add("hairAccessories", .toiletries, vol: 0.1, kg: 0.05)
            b.add("feminine", .toiletries, vol: 0.3, kg: 0.1)
        }
        if carryOnOnly { b.add("liquidsBag", .toiletries, vol: 0.05, kg: 0.02, note: "security") }
        if warm || acts.contains(.beach) || acts.contains(.hiking) {
            b.add("sunscreen", .toiletries, vol: 0.2, kg: 0.2, note: liquids)
        }

        // Здравје
        b.add("meds", .health, vol: 0.2, kg: 0.1, note: isPlane ? "medsCarryOn" : nil)
        b.add("firstAid", .health, vol: 0.3, kg: 0.15, note: "firstAidNote")

        // Електроника
        b.add("phoneCharger", .electronics, vol: 0.15, kg: 0.1)
        b.add("powerbank", .electronics, vol: 0.25, kg: 0.25, note: isPlane ? "handOnly" : nil)
        b.add("headphones", .electronics, vol: 0.2, kg: 0.06)
        if let plug = adapterType(from: trip.origin?.countryCode ?? "MK", to: trip.destination.countryCode) {
            b.add("adapter.\(plug)", .electronics, vol: 0.1, kg: 0.08, note: "plugNote")
        }

        // Додатоци
        if warm || acts.contains(.beach) { b.add("sunglasses", .accessories, vol: 0.2, kg: 0.05) }
        if hot { b.add("sunHat", .accessories, vol: 0.5, kg: 0.1) }
        if rainy {
            if acts.contains(.hiking) {
                b.add("raincoat", .accessories, vol: 0.6, kg: 0.3)
            } else {
                b.add("umbrella", .accessories, vol: 0.5, kg: 0.3, note: w.hasData ? "rainForecast" : "justInCase")
            }
        }
        b.add("laundryBag", .accessories, vol: 0.05, kg: 0.03)

        // Активности
        if acts.contains(.photo) {
            b.add("photoOutfits", .clothing, qty: max(1, days / 3), vol: 0.8, kg: 0.3, note: "neutralTones")
            b.add("tripod", .activity, vol: 0.3, kg: 0.15)
            b.add("lensCloth", .activity, vol: 0.01, kg: 0.01)
        }
        if acts.contains(.walking) {
            b.add("daypack", .accessories, vol: 0.8, kg: 0.25)
            b.add("bottle", .accessories, vol: 0.5, kg: 0.12, note: isPlane ? "emptyAtSecurity" : nil)
        }
        if acts.contains(.dining) {
            if woman {
                b.add("eveningDress", .clothing, qty: max(1, days / 4), vol: 1, kg: 0.35)
                b.add("smartShoes", .shoes, vol: 2.5, kg: 0.5)
                b.add("jewellery", .accessories, vol: 0.1, kg: 0.05)
            } else if man {
                b.add("shirt", .clothing, qty: max(1, days / 3), vol: 0.9, kg: 0.25)
                b.add("smartTrousers", .clothing, vol: 1.2, kg: 0.45)
                b.add("dressShoes", .shoes, vol: 4, kg: 0.9)
            } else {
                b.add("smartOutfit", .clothing, qty: max(1, days / 4), vol: 1.2, kg: 0.4)
                b.add("smartShoes", .shoes, vol: 3, kg: 0.7)
            }
            b.add("wrinkleSpray", .toiletries, vol: 0.15, kg: 0.12, note: liquids)
            b.add("perfume", .toiletries, vol: 0.1, kg: 0.1, note: carryOnOnly ? "travelSizes" : nil)
        }
        if acts.contains(.work) {
            b.add("laptop", .electronics, vol: 1.6, kg: 1.5, note: isPlane ? "laptopSecurity" : nil)
            b.add("laptopCharger", .electronics, vol: 0.4, kg: 0.35)
            b.add("usbHub", .electronics, vol: 0.1, kg: 0.08)
            b.add("mouse", .electronics, vol: 0.1, kg: 0.08)
        }
        if acts.contains(.fitness) {
            b.add("sportswear", .activity, qty: max(1, (days + 1) / 2), vol: 0.7, kg: 0.25)
            b.add("trainingShoes", .shoes, vol: 3.5, kg: 0.7)
        }
        if acts.contains(.beach) {
            b.add("swimwear", .activity, qty: days > 3 ? 2 : 1, vol: 0.2, kg: 0.1)
            b.add("beachTowel", .activity, vol: 2, kg: 0.45, note: "microfiber")
            b.add("afterSun", .toiletries, vol: 0.2, kg: 0.2, note: liquids)
            b.add("waterproofCase", .activity, vol: 0.05, kg: 0.03)
        }
        if acts.contains(.hiking) {
            b.add("hikingBoots", .shoes, vol: 5, kg: 1.1)
            b.add("techLayer", .activity, vol: 1, kg: 0.3)
            b.add("headlamp", .activity, vol: 0.1, kg: 0.08)
            b.add("hikingPack", .activity, vol: 1, kg: 0.4)
            b.add("bottle", .accessories, vol: 0.5, kg: 0.12, note: isPlane ? "emptyAtSecurity" : nil)
        }
        if acts.contains(.nightlife) {
            b.add("nightOutfit", .clothing, qty: max(1, days / 3), vol: 0.8, kg: 0.3)
            b.add("earplugs", .accessories, vol: 0.02, kg: 0.01, note: "earplugsNote")
        }

        // За патот
        switch trip.transport {
        case .plane:
            b.add("snacks", .journey, vol: 0.3, kg: 0.2)
        case .car:
            b.add("carCharger", .journey, vol: 0.05, kg: 0.05)
            b.add("waterSnacks", .journey, vol: 1, kg: 0.8)
            b.add("tollCash", .journey, vol: 0.01, kg: 0.01)
        case .train, .bus:
            b.add("waterSnacks", .journey, vol: 1, kg: 0.8)
            if trip.dayCount > 1 { b.add("neckPillow", .journey, vol: 1.5, kg: 0.2) }
        }

        return b.items
    }

    // MARK: Предлози и регенерирање

    /// Предмети што логиката сега би ги додала, а ги нема во листата.
    static func suggestions(for trip: Trip) -> [PackingItem] {
        let existing = Set(trip.items.map(\.identity) + trip.items.map { $0.displayName.lowercased() })
        let dismissed = Set(trip.dismissedSuggestions.map { $0.lowercased() })
        return generate(for: trip).filter {
            !existing.contains($0.identity) && !dismissed.contains($0.identity)
                && !existing.contains($0.displayName.lowercased())
        }
    }

    /// Нова листа; спакуваното, кој што носи и рачно додаденото остануваат.
    static func regenerate(_ trip: Trip) -> [PackingItem] {
        var previous: [String: PackingItem] = [:]
        for item in trip.items {
            previous[item.identity] = item
            previous[item.displayName.lowercased()] = item
        }
        var fresh = generate(for: trip).map { item -> PackingItem in
            var copy = item
            if let old = previous[item.identity] ?? previous[item.displayName.lowercased()] {
                copy.id = old.id
                copy.isPacked = old.isPacked
                copy.assignee = old.assignee
                copy.packedBy = old.packedBy
            }
            return copy
        }
        let freshIDs = Set(fresh.map(\.identity))
        fresh.append(contentsOf: trip.items.filter { $0.isCustom && !freshIDs.contains($0.identity) })
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

    static func adapterType(from origin: String, to destination: String) -> String? {
        let from = plugTypes[origin.uppercased()]
        let to = plugTypes[destination.uppercased()]
        if from == to { return nil }
        return to ?? "C/F"
    }

    // MARK: Излез од дома

    static func defaultExitChecklist() -> [ChecklistItem] {
        let entries: [(String, String)] = [
            ("stove", "flame"),
            ("iron", "powerplug"),
            ("boiler", "thermometer.medium"),
            ("water", "drop"),
            ("windows", "window.vertical.closed"),
            ("trash", "trash"),
            ("fridge", "refrigerator"),
            ("plants", "leaf"),
            ("chargers", "bolt.slash"),
            ("essentials", "wallet.pass"),
            ("door", "key")
        ]
        return entries.map { entry in
            ChecklistItem(title: Catalog.exitTitle(entry.0) ?? entry.0, icon: entry.1, key: entry.0)
        }
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
            return L("Има простор. Сè собира без туркање.", "Plenty of room. Everything fits with ease.")
        case .snug:
            return L("Тесно, но собира. Свиткај ја облеката во ролни и облечи го најобемното на пат.",
                     "Snug, but it fits. Roll your clothes and wear the bulkiest pieces on the way.")
        case .over:
            if heavy && !over, let limit = trip.bag.weightLimit {
                return L("Над дозволените \(Fmt.number(limit)) kg. Облечи ги најтешките работи на пат или намали ги количините.",
                         "Over the \(Fmt.number(limit)) kg limit. Wear the heaviest pieces or pack fewer.")
            }
            if trip.bag.kind == .personal {
                return L("Премногу за малата торба. Намали количини, облечи го обемното на пат или земи кабински куфер — однапред е многу поевтино отколку на излезот.",
                         "Too much for the small bag. Pack fewer, wear the bulky pieces, or add a cabin bag — it's far cheaper online than at the gate.")
            }
            return L("Не собира сè. Намали количини или размисли за поголем багаж.",
                     "It won't all fit. Pack fewer or consider a bigger bag.")
        }
    }
}
