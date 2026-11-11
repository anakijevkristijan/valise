import Foundation

// MARK: - Каталог за децата и миленичињата

enum FamilyCatalog {
    static let names: [String: (String, String)] = [
        // Документи
        "kid.passport": ("Пасош / лична карта за детето", "Child's passport / ID"),
        "kid.healthCard": ("Здравствена книшка и картичка", "Health card and vaccination record"),
        "pet.passport": ("Пасош за миленичето и книшка за вакцини", "Pet passport and vaccination record"),
        // Облека
        "kid.bodysuits": ("Бодиња", "Bodysuits"),
        "kid.sleepsuits": ("Пижамки / ромперчиња", "Sleepsuits"),
        "kid.tshirts": ("Маички", "T-shirts"),
        "kid.longSleeves": ("Блузи со долги ракави", "Long-sleeve tops"),
        "kid.shorts": ("Шортсеви", "Shorts"),
        "kid.trousers": ("Панталонки / хеланки", "Trousers / leggings"),
        "kid.underwear": ("Гаќички", "Underwear"),
        "kid.socks": ("Чорапчиња", "Socks"),
        "kid.pyjamas": ("Пижама", "Pyjamas"),
        "kid.sweater": ("Џемперче / дуксерче", "Jumper / hoodie"),
        "kid.lightJacket": ("Лесна јакна", "Light jacket"),
        "kid.warmJacket": ("Топла јакна", "Warm jacket"),
        "kid.warmSuit": ("Топол комбинезон", "Snowsuit"),
        "kid.winterSet": ("Капа, шал и ракавици", "Hat, scarf and gloves"),
        "kid.raincoat": ("Детска кабаница", "Kids' rain jacket"),
        "kid.sunHat": ("Капа за сонце", "Sun hat"),
        "kid.swimwear": ("Костим за капење", "Swimwear"),
        "kid.spareOutfit": ("Резервна облека во рачниот багаж", "Spare outfit in hand luggage"),
        // Обувки
        "kid.shoes": ("Удобни патики", "Comfortable sneakers"),
        "kid.sandals": ("Сандалки", "Sandals"),
        "kid.boots": ("Чизми / боти", "Boots"),
        // Хигиена
        "kid.nappies": ("Пелени", "Nappies"),
        "kid.wipes": ("Влажни марамчиња", "Wet wipes"),
        "kid.nappyCream": ("Крема за пелени", "Nappy cream"),
        "kid.changingMat": ("Подлога за пресоблекување", "Changing mat"),
        "kid.babyWash": ("Бебешки шампон и крема", "Baby shampoo and lotion"),
        "kid.toothbrush": ("Детска четка и паста за заби", "Kids' toothbrush and toothpaste"),
        "kid.sunscreen": ("Детска крема за сончање SPF 50+", "Kids' sunscreen SPF 50+"),
        "kid.teenToiletries": ("Четка, паста и дезодоранс", "Toothbrush, toothpaste and deodorant"),
        // Здравје
        "kid.meds": ("Детски лекови (сируп за температура)", "Children's medicine (fever syrup)"),
        "kid.thermometer": ("Термометар", "Thermometer"),
        // Електроника
        "kid.tablet": ("Таблет со цртани и слушалки", "Tablet with cartoons and headphones"),
        "kid.phoneCharger": ("Полнач за телефон и слушалки", "Phone charger and headphones"),
        // Додатоци
        "kid.bottles": ("Шишиња за млеко", "Baby bottles"),
        "kid.formula": ("Адаптирано млеко и бебешка храна", "Formula and baby food"),
        "kid.bibs": ("Лигавчиња", "Bibs"),
        "kid.dummy": ("Цуцли", "Dummies"),
        "kid.blanket": ("Ќебенце", "Baby blanket"),
        "kid.sippyCup": ("Чаша со сламка", "Sippy cup"),
        "kid.waterBottle": ("Детско шише за вода", "Kids' water bottle"),
        "kid.toy": ("Омилена играчка", "Favourite toy"),
        "kid.books": ("Сликовници и боици", "Picture books and crayons"),
        "kid.travelGame": ("Книга или игра за пат", "Book or travel game"),
        // За активностите
        "kid.swimNappies": ("Пелени за пливање", "Swim nappies"),
        "kid.floaties": ("Мишки или елек за пливање", "Armbands or swim vest"),
        "kid.beachToys": ("Играчки за плажа", "Beach toys"),
        // За патот
        "kid.snacks": ("Грицки и овошје за на пат", "Snacks and fruit for the journey"),
        "kid.stroller": ("Количка или носиљка", "Pushchair or baby carrier"),
        "kid.carSeat": ("Детско седиште за кола", "Child car seat"),
        "kid.booster": ("Бустер седиште", "Booster seat"),
        // Миленичиња
        "pet.food": ("Храна", "Food"),
        "pet.treats": ("Лакомства", "Treats"),
        "pet.bowls": ("Чинии за храна и вода", "Food and water bowls"),
        "pet.water": ("Вода за на пат", "Water for the journey"),
        "pet.leash": ("Поводник и огрлица со плочка", "Lead and collar with ID tag"),
        "pet.harness": ("Ам и поводник", "Harness and lead"),
        "pet.poopBags": ("Кесички за измет", "Poop bags"),
        "pet.litter": ("Песок и мала тоалета", "Litter and a small litter tray"),
        "pet.carrier": ("Транспортер", "Pet carrier"),
        "pet.bed": ("Креветче или ќебенце", "Bed or blanket"),
        "pet.bedding": ("Постелка", "Bedding"),
        "pet.toy": ("Омилена играчка", "Favourite toy"),
        "pet.meds": ("Лекови и заштита од крлежи", "Medication and flea & tick treatment"),
        "pet.brush": ("Четка", "Brush"),
        "pet.towel": ("Пешкир", "Towel"),
        "pet.wipes": ("Марамчиња за шепи", "Paw wipes"),
        "pet.coat": ("Јакна за куче", "Dog coat"),
        "pet.carBelt": ("Појас или преграда за кола", "Car harness or barrier")
    ]

    static let notes: [String: (String, String)] = [
        "kid.babyFood": ("бебешката храна смее во рачен багаж", "baby food is allowed in hand luggage"),
        "kid.buyThere": ("за првите денови - останатото купи таму", "for the first few days - buy the rest there"),
        "kid.atGate": ("се предава на вратата од авионот", "handed over at the plane door"),
        "kid.checkSize": ("според возраста и висината", "suited to their age and height"),
        "pet.checkCarrier": ("провери ги правилата на превозникот", "check the carrier's pet rules"),
        "pet.foodNote": ("за сите денови + 2 дена резерва", "for every day + 2 spare days"),
        "pet.rabies": ("чип и вакцина против беснило", "microchip and rabies vaccine")
    ]
}

// MARK: - Листи за децата и миленичињата

/// Без AI - иста логика како за тебе: денови, перење, време, превоз и активности, а за детето и возраста.
enum FamilyPacking {

    private struct Builder {
        var items: [PackingItem] = []

        mutating func add(_ key: String, _ category: ItemCategory, qty: Int = 1,
                          vol: Double, kg: Double, note: String? = nil) {
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
                                     key: key,
                                     noteKey: note))
        }
    }

    /// Времето на патувањето (исто како за тебе).
    private struct Weather {
        let warm: Bool
        let hot: Bool
        let mild: Bool
        let cool: Bool
        let freezing: Bool
        let rainy: Bool
        let chillyNights: Bool

        init(trip: Trip) {
            let c = PackingEngine.climate(for: trip)
            let w = WeatherSummary(days: trip.weather.filter { !$0.isClimate })
            warm = c.high >= 23 || c.warmestHigh >= 27
            hot = c.warmestHigh >= 29 && c.high >= 25
            mild = !warm && c.high >= 16
            cool = !warm && !mild && c.high >= 9
            freezing = c.coldestLow < 0 || w.hasSnow
            rainy = (w.maxRainChance ?? 0) > 40 || w.rainyDays > 0 || !w.hasData
            chillyNights = c.low < 15
        }

        var cold: Bool { !warm && !mild && !cool }
    }

    /// Предмети што зависат од времето - се усогласуваат со новата прогноза.
    static let weatherKeys: Set<String> = [
        "kid.tshirts", "kid.longSleeves", "kid.shorts", "kid.trousers", "kid.sweater", "kid.lightJacket",
        "kid.warmJacket", "kid.warmSuit", "kid.winterSet", "kid.raincoat", "kid.sunHat", "kid.sandals",
        "kid.boots", "kid.sunscreen", "pet.coat"
    ]

    static func items(for member: TripFamilyMember, trip: Trip) -> [PackingItem] {
        member.kind == .child ? childItems(age: member.age ?? 5, trip: trip)
                              : petItems(member.petType ?? .other, trip: trip)
    }

    // MARK: Дете

    static func childItems(age: Int, trip: Trip) -> [PackingItem] {
        var b = Builder()
        let group = AgeGroup(age: age)
        let f = group.sizeFactor
        let days = trip.dayCount
        let n = PackingEngine.clothingDays(for: trip)
        let w = Weather(trip: trip)
        let acts = Set(trip.activities)
        let isPlane = trip.transport == .plane
        let isCar = trip.transport == .car
        let little = group == .baby || group == .toddler

        // Документи
        if trip.isInternational { b.add("kid.passport", .documents, vol: 0.05, kg: 0.05, note: "checkValidity") }
        b.add("kid.healthCard", .documents, vol: 0.02, kg: 0.02)

        // Облека: малите се валкаат почесто - повеќе парчиња
        let extra = group == .baby ? 0 : (group == .toddler ? 2 : (group == .small ? 1 : 0))
        if group == .baby {
            b.add("kid.bodysuits", .clothing, qty: min(n * 2, 14), vol: 0.5 * f, kg: 0.12 * f)
            b.add("kid.sleepsuits", .clothing, qty: min(n, 7), vol: 0.8 * f, kg: 0.2 * f)
            if !w.warm { b.add("kid.trousers", .clothing, qty: min(max(2, n / 2), 5), vol: 1.2 * f, kg: 0.3 * f) }
        } else {
            let tops = min(n + extra, 12)
            if w.warm {
                b.add("kid.tshirts", .clothing, qty: tops, vol: 0.6 * f, kg: 0.18 * f)
                if w.chillyNights { b.add("kid.longSleeves", .clothing, vol: 0.8 * f, kg: 0.22 * f) }
                b.add("kid.shorts", .clothing, qty: min(max(2, (n + 1) / 2 + (little ? 1 : 0)), 7), vol: 0.7 * f, kg: 0.2 * f)
                if w.chillyNights { b.add("kid.trousers", .clothing, vol: 1.2 * f, kg: 0.35 * f) }
            } else {
                let tees = max(1, Int((Double(tops) * (w.mild ? 0.5 : 0.4)).rounded()))
                b.add("kid.tshirts", .clothing, qty: tees, vol: 0.6 * f, kg: 0.18 * f)
                b.add("kid.longSleeves", .clothing, qty: max(1, tops - tees), vol: 0.8 * f, kg: 0.22 * f)
                b.add("kid.trousers", .clothing, qty: min(max(2, (n + 2) / 3 + (little ? 1 : 0)), 6), vol: 1.2 * f, kg: 0.35 * f)
            }
            if group != .toddler {
                b.add("kid.underwear", .clothing, qty: min(n + (group == .small ? 2 : 1), 12), vol: 0.1 * f, kg: 0.04 * f)
            }
            b.add("kid.pyjamas", .clothing, qty: max(1, (n + (little ? 2 : 3)) / (little ? 3 : 4)), vol: 0.8 * f, kg: 0.25 * f)
        }
        b.add("kid.socks", .clothing, qty: min(n + 1, 10), vol: 0.1 * f, kg: 0.04 * f)

        // Слоеви според времето
        if w.warm {
            if w.chillyNights { b.add("kid.sweater", .clothing, vol: 1.5 * f, kg: 0.35 * f) }
            if !w.hot || group == .baby { b.add("kid.sunHat", .accessories, vol: 0.3 * f, kg: 0.05) }
            if w.chillyNights && group != .baby { b.add("kid.lightJacket", .clothing, vol: 2 * f, kg: 0.4 * f) }
        } else if w.mild {
            b.add("kid.sweater", .clothing, qty: 2, vol: 1.5 * f, kg: 0.35 * f)
            b.add("kid.lightJacket", .clothing, vol: 2 * f, kg: 0.4 * f)
        } else {
            b.add("kid.sweater", .clothing, qty: min(max(2, n / 3 + 1), 4), vol: 1.5 * f, kg: 0.35 * f)
            if group == .baby && (w.cold || w.freezing) {
                b.add("kid.warmSuit", .clothing, vol: 4 * f, kg: 0.7 * f)
            } else {
                b.add("kid.warmJacket", .clothing, vol: 4 * f, kg: 0.8 * f)
            }
            if w.cold || w.freezing { b.add("kid.winterSet", .accessories, vol: 1 * f, kg: 0.25 * f) }
        }
        if w.rainy && group != .baby { b.add("kid.raincoat", .clothing, vol: 0.8 * f, kg: 0.25 * f) }

        // Обувки (бебето нема)
        if group != .baby {
            b.add("kid.shoes", .shoes, vol: 3 * f, kg: 0.7 * f)
            if w.warm { b.add("kid.sandals", .shoes, vol: 2 * f, kg: 0.4 * f) }
            if w.freezing { b.add("kid.boots", .shoes, vol: 4 * f, kg: 0.9 * f) }
        }

        // Хигиена
        if little {
            let perDay = group == .baby ? 7 : 5
            b.add("kid.nappies", .toiletries, qty: min(days, 4) * perDay, vol: 0.2, kg: 0.04,
                  note: days > 4 ? "kid.buyThere" : nil)
            b.add("kid.wipes", .toiletries, qty: max(1, (days + 2) / 3), vol: 0.4, kg: 0.35)
            b.add("kid.nappyCream", .toiletries, vol: 0.1, kg: 0.1)
        }
        if group == .baby {
            b.add("kid.changingMat", .toiletries, vol: 0.6, kg: 0.15)
            b.add("kid.babyWash", .toiletries, vol: 0.3, kg: 0.3, note: isPlane && !trip.hasCheckedBag ? "liquids100" : nil)
        } else if group == .teen {
            b.add("kid.teenToiletries", .toiletries, vol: 0.3, kg: 0.25)
        } else {
            b.add("kid.toothbrush", .toiletries, vol: 0.1, kg: 0.08)
        }
        if (w.warm || acts.contains(.beach)) && group != .baby && group != .teen {
            b.add("kid.sunscreen", .toiletries, vol: 0.2, kg: 0.2, note: isPlane && !trip.hasCheckedBag ? "liquids100" : nil)
        }

        // Здравје
        if group != .teen {
            b.add("kid.meds", .health, vol: 0.2, kg: 0.15, note: "medsCarryOn")
        }
        if little { b.add("kid.thermometer", .health, vol: 0.05, kg: 0.03) }

        // Храна и удобност
        if group == .baby {
            b.add("kid.bottles", .accessories, qty: 2, vol: 0.4, kg: 0.1)
            b.add("kid.formula", .accessories, vol: 1, kg: 0.8, note: isPlane ? "kid.babyFood" : nil)
            b.add("kid.bibs", .accessories, qty: min(n, 5), vol: 0.1, kg: 0.03)
            b.add("kid.dummy", .accessories, qty: 2, vol: 0.05, kg: 0.02)
            b.add("kid.blanket", .accessories, vol: 1.2, kg: 0.3)
        } else if group == .toddler {
            b.add("kid.sippyCup", .accessories, vol: 0.4, kg: 0.12)
            b.add("kid.bibs", .accessories, qty: 3, vol: 0.1, kg: 0.03)
        } else {
            b.add("kid.waterBottle", .accessories, vol: 0.5, kg: 0.12, note: isPlane ? "emptyAtSecurity" : nil)
        }
        if group != .teen { b.add("kid.toy", .accessories, vol: 0.8, kg: 0.15) }

        // Забава на пат
        switch group {
        case .baby: break
        case .toddler, .small: b.add("kid.books", .accessories, vol: 0.6, kg: 0.3)
        case .school, .teen: b.add("kid.travelGame", .accessories, vol: 0.5, kg: 0.3)
        }
        let longRide = !isCar || days >= 3
        if (group == .small || group == .school) && longRide {
            b.add("kid.tablet", .electronics, vol: 0.6, kg: 0.5)
        }
        if group == .teen { b.add("kid.phoneCharger", .electronics, vol: 0.2, kg: 0.1) }

        // Плажа
        if acts.contains(.beach) {
            if little { b.add("kid.swimNappies", .activity, qty: min(days, 6), vol: 0.1, kg: 0.03) }
            b.add("kid.swimwear", .activity, qty: group == .baby ? 1 : 2, vol: 0.3 * f, kg: 0.1 * f)
            if group == .toddler || group == .small { b.add("kid.floaties", .activity, vol: 0.3, kg: 0.15) }
            if group != .teen { b.add("kid.beachToys", .activity, vol: 1.5, kg: 0.4) }
        }

        // За патот (количката и седиштето не се во куферот)
        if group != .teen {
            b.add("kid.snacks", .journey, vol: 0.4, kg: 0.3)
        }
        if isPlane && group != .teen && group != .school {
            b.add("kid.spareOutfit", .journey, qty: group == .baby ? 2 : 1, vol: 0.6 * f, kg: 0.2 * f)
        }
        if little {
            b.add("kid.stroller", .journey, vol: 0, kg: 0, note: isPlane ? "kid.atGate" : nil)
        }
        if isCar {
            if age < 4 {
                b.add("kid.carSeat", .journey, vol: 0, kg: 0, note: "kid.checkSize")
            } else if age < 12 {
                b.add("kid.booster", .journey, vol: 0, kg: 0, note: "kid.checkSize")
            }
        }
        return b.items
    }

    // MARK: Милениче

    static func petItems(_ type: PetType, trip: Trip) -> [PackingItem] {
        var b = Builder()
        let days = trip.dayCount
        let w = Weather(trip: trip)
        let isCar = trip.transport == .car
        let portions = Double(days + 2)

        if trip.isInternational || type != .other {
            b.add("pet.passport", .documents, vol: 0.05, kg: 0.05, note: trip.isInternational ? "pet.rabies" : nil)
        }

        switch type {
        case .dog:
            b.add("pet.food", .journey, vol: 0.6 * portions, kg: 0.3 * portions, note: "pet.foodNote")
            b.add("pet.treats", .journey, vol: 0.4, kg: 0.2)
            b.add("pet.bowls", .accessories, vol: 1, kg: 0.2)
            b.add("pet.leash", .accessories, vol: 0.4, kg: 0.2)
            b.add("pet.poopBags", .toiletries, qty: max(1, (days + 4) / 5), vol: 0.1, kg: 0.05)
            b.add("pet.bed", .accessories, vol: 4, kg: 0.6)
            b.add("pet.toy", .accessories, vol: 0.4, kg: 0.1)
            b.add("pet.brush", .toiletries, vol: 0.2, kg: 0.1)
            b.add("pet.towel", .toiletries, vol: 1, kg: 0.3)
            b.add("pet.wipes", .toiletries, vol: 0.3, kg: 0.25)
            if w.cool || w.cold || w.freezing { b.add("pet.coat", .accessories, vol: 1, kg: 0.2) }
        case .cat:
            b.add("pet.food", .journey, vol: 0.3 * portions, kg: 0.12 * portions, note: "pet.foodNote")
            b.add("pet.treats", .journey, vol: 0.2, kg: 0.1)
            b.add("pet.bowls", .accessories, vol: 0.8, kg: 0.2)
            b.add("pet.litter", .toiletries, vol: 4, kg: 2)
            b.add("pet.harness", .accessories, vol: 0.3, kg: 0.15)
            b.add("pet.bed", .accessories, vol: 2, kg: 0.3)
            b.add("pet.toy", .accessories, vol: 0.3, kg: 0.05)
            b.add("pet.brush", .toiletries, vol: 0.2, kg: 0.1)
        case .other:
            b.add("pet.food", .journey, vol: 0.2 * portions, kg: 0.1 * portions, note: "pet.foodNote")
            b.add("pet.treats", .journey, vol: 0.2, kg: 0.1)
            b.add("pet.bowls", .accessories, vol: 0.5, kg: 0.1)
            b.add("pet.bedding", .accessories, vol: 2, kg: 0.5)
        }
        b.add("pet.meds", .health, vol: 0.2, kg: 0.1)

        // Превоз (транспортерот не е во куферот)
        if type == .dog {
            if isCar {
                b.add("pet.carBelt", .journey, vol: 0, kg: 0)
                b.add("pet.water", .journey, vol: 1.5, kg: 1.5)
            } else {
                b.add("pet.carrier", .journey, vol: 0, kg: 0, note: "pet.checkCarrier")
            }
        } else {
            b.add("pet.carrier", .journey, vol: 0, kg: 0, note: isCar ? nil : "pet.checkCarrier")
            if isCar { b.add("pet.water", .journey, vol: 1, kg: 1) }
        }
        return b.items
    }

    // MARK: Избор по патување

    /// Децата и миленичињата избрани за патувањето, со нивните листи.
    /// Тие што веќе биле во патувањето ги задржуваат спакуваното, рачно додаденото и сменетите бројки.
    static func family(for ids: [UUID], trip: Trip, previous: [TripFamilyMember]?) -> [TripFamilyMember]? {
        let store = FamilyStore.shared
        var result: [TripFamilyMember] = []
        for id in ids {
            if var existing = previous?.first(where: { $0.id == id }) {
                // Листа што ми е споделена: ја уредува само нејзиниот сопственик
                guard existing.isMine else { result.append(existing); continue }
                if let profile = store.member(id) { existing.update(from: profile, on: trip.startDate) }
                refresh(&existing, trip: trip, weatherOnly: false)
                result.append(existing)
            } else if let profile = store.member(id) {
                var fresh = TripFamilyMember(member: profile, on: trip.startDate)
                fresh.items = items(for: fresh, trip: trip)
                result.append(fresh)
            }
        }
        return result.isEmpty ? nil : result
    }

    /// Нова прогноза: облеката на децата се усогласува (како твојата).
    @discardableResult
    static func syncWithWeather(_ trip: inout Trip) -> Bool {
        guard var family = trip.family, !family.isEmpty else { return false }
        var changed = false
        for index in family.indices where family[index].isMine {
            if refresh(&family[index], trip: trip, weatherOnly: true) { changed = true }
        }
        if changed { trip.family = family }
        return changed
    }

    /// Ја усогласува листата со новото (датуми, време, возраст).
    /// Не се допира: спакуваното, рачно сменетата бројка, рачно додаденото и тргнатото.
    @discardableResult
    static func refresh(_ member: inout TripFamilyMember, trip: Trip, weatherOnly: Bool) -> Bool {
        let fresh = items(for: member, trip: trip)
        var freshByKey: [String: PackingItem] = [:]
        for item in fresh {
            if let key = item.key, freshByKey[key] == nil { freshByKey[key] = item }
        }
        let dismissed = Set((member.dismissed ?? []).map { $0.lowercased() })

        func follows(_ item: PackingItem) -> Bool {
            guard let key = item.key, !item.isCustom, !item.isPacked, item.quantityEdited != true else { return false }
            return !weatherOnly || weatherKeys.contains(key)
        }

        var list = member.items
        list.removeAll { follows($0) && freshByKey[$0.key ?? ""] == nil }
        for index in list.indices where follows(list[index]) {
            guard let key = list[index].key, let new = freshByKey[key] else { continue }
            list[index].quantity = new.quantity
            list[index].note = new.note
            list[index].noteKey = new.noteKey
            list[index].unitVolume = new.unitVolume
            list[index].unitWeight = new.unitWeight
        }
        let present = Set(list.compactMap(\.key))
        for item in fresh {
            guard let key = item.key, !present.contains(key), !dismissed.contains(item.identity) else { continue }
            if weatherOnly && !weatherKeys.contains(key) { continue }
            if let last = list.lastIndex(where: { $0.category == item.category }) {
                list.insert(item, at: last + 1)
            } else {
                list.append(item)
            }
        }
        guard list != member.items else { return false }
        member.items = list
        return true
    }
}
