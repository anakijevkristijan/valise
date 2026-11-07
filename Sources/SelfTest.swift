#if DEBUG
import Foundation
import CoreGraphics

/// Автоматска проверка на логиката — само Debug изградба, само со аргументот -TripdrobeSelfTest
/// (workflow-от „Провери ја апликацијата“, во симулатор). Резултатот: Documents/selftest.json.
/// Во TestFlight и App Store (Release) овој код воопшто не постои.
enum SelfTest {
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-TripdrobeSelfTest") }

    struct Result: Codable {
        let name: String
        let passed: Bool
        let detail: String
    }

    private struct Missing: Error, CustomStringConvertible {
        let description: String
    }

    private static var results: [Result] = []
    private static var failures: [String] = []

    // MARK: Помошни

    private static func check(_ condition: Bool, _ message: @autoclosure () -> String) {
        if !condition { failures.append(message()) }
    }

    private static func unwrap<T>(_ value: T?, _ what: String) throws -> T {
        guard let value else { throw Missing(description: "нема: \(what)") }
        return value
    }

    private static func test(_ name: String, _ body: () throws -> Void) {
        failures = []
        do {
            try body()
        } catch {
            failures.append("прекинато — \(error)")
        }
        let detail = failures.prefix(10).joined(separator: " | ")
            + (failures.count > 10 ? " | …и уште \(failures.count - 10)" : "")
        results.append(Result(name: name, passed: failures.isEmpty, detail: detail))
    }

    private static func use(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
    }

    private static var otherLanguages: [AppLanguage] {
        AppLanguage.allCases.filter { $0 != .en && $0 != .mk }
    }

    private static func day(_ offset: Int) -> Date { Date().startOfDay.adding(days: offset) }

    private static func sameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    private static func place(_ id: Int, _ name: String, _ country: String, _ code: String,
                              _ latitude: Double, _ longitude: Double) -> Place {
        Place(id: id, name: name, region: nil, country: country, countryCode: code,
              latitude: latitude, longitude: longitude, timezone: nil)
    }

    private static let skopje = place(785842, "Skopje", "North Macedonia", "MK", 41.99, 21.43)
    private static let thessaloniki = place(734077, "Thessaloniki", "Greece", "GR", 40.64, 22.94)
    private static let athens = place(264371, "Athens", "Greece", "GR", 37.98, 23.73)

    private static func sampleTrip(startIn: Int = 10, days: Int = 7) -> Trip {
        let bag = BagSpec(title: "Cabin bag", height: 55, width: 40, depth: 20, weightLimit: 10, kind: .cabin)
        let start = day(startIn)
        var trip = Trip(origin: skopje,
                        destination: athens,
                        startDate: start,
                        endDate: start.adding(days: days - 1),
                        transport: .plane,
                        airlineID: "wizz",
                        bag: bag,
                        activities: [],
                        style: .woman,
                        hasLaundry: false)
        trip.items = PackingEngine.generate(for: trip)
        return trip
    }

    private static func table(_ language: AppLanguage) -> [String: String] {
        let raw: String
        switch language {
        case .sq: raw = TranslationsSQ.json
        case .sr: raw = TranslationsSR.json
        case .bg: raw = TranslationsBG.json
        case .el: raw = TranslationsEL.json
        case .tr: raw = TranslationsTR.json
        case .de: raw = TranslationsDE.json
        case .fr: raw = TranslationsFR.json
        case .es: raw = TranslationsES.json
        case .it: raw = TranslationsIT.json
        case .pl: raw = TranslationsPL.json
        case .pt: raw = TranslationsPT.json
        case .en, .mk: raw = "{}"
        }
        return ((try? JSONSerialization.jsonObject(with: Data(raw.utf8))) as? [String: String]) ?? [:]
    }

    private static func placeholders(_ text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "\\{\\d\\}") else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }.sorted()
    }

    // MARK: Пуштање

    static func run() {
        let savedLanguage = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        results = []

        test("Преводи: секој јазик ги има сите текстови", translationsComplete)
        test("Преводи: вметнатите вредности ({0}) се зачувани", translationsKeepPlaceholders)
        test("Преводи: менувањето јазик го менува текстот", languageSwitch)
        test("Преводи: шаблоните ги вметнуваат бројките", templates)
        test("Преводи: „3 маици“ на секој јазик", countNouns)
        test("Правни текстови за секој јазик", legalTexts)
        test("Листа за пакување на секој јазик", packingList)
        test("Авиокомпании: секоја се наоѓа со пребарување", airlines)
        test("Прогноза: климатска проценка", climate)
        test("Аутфити: парчињата не се преклопуваат", outfitLayout)
        test("Пријатели: кога сте заедно (градови и датуми)", memberOverlap)
        test("Пријатели: нов член ги следи сопственикот", memberFollowsOwner)
        test("Пријатели: сменетите датуми на членот се само негови", memberOwnPlan)

        UserDefaults.standard.set(savedLanguage, forKey: AppLanguage.storageKey)
        write()
    }

    private static func write() {
        guard let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? JSONEncoder().encode(results) else { return }
        try? data.write(to: folder.appendingPathComponent("selftest.json"), options: .atomic)
    }

    // MARK: Преводи

    private static func translationsComplete() throws {
        let reference = Set(table(.de).keys)
        check(reference.count > 900, "германски: само \(reference.count) текстови")
        for language in otherLanguages {
            let keys = Set(table(language).keys)
            let missing = reference.subtracting(keys).sorted()
            let extra = keys.subtracting(reference).sorted()
            check(missing.isEmpty, "\(language.englishName): фалат \(missing.count), пр. \(missing.prefix(3))")
            check(extra.isEmpty, "\(language.englishName): вишок \(extra.count), пр. \(extra.prefix(3))")
        }
    }

    private static func translationsKeepPlaceholders() throws {
        for language in otherLanguages {
            for (english, translated) in table(language) {
                check(placeholders(english) == placeholders(translated), "\(language.rawValue): «\(english)» → «\(translated)»")
                check(translated.contains(where: { !$0.isWhitespace }) || !english.contains(where: { !$0.isWhitespace }),
                      "\(language.rawValue): празен превод за «\(english)»")
            }
        }
    }

    private static func languageSwitch() throws {
        for language in AppLanguage.allCases {
            use(language)
            let text = L("Избери јазик", "Choose your language")
            switch language {
            case .en: check(text == "Choose your language", "en: \(text)")
            case .mk: check(text == "Избери јазик", "mk: \(text)")
            default: check(text != "Choose your language" && !text.isEmpty, "\(language.rawValue): не е преведено")
            }
        }
    }

    private static func templates() throws {
        for language in otherLanguages {
            let text = Translations.translate("Search 417 airlines", to: language)
            check(text.contains("417") && text != "Search 417 airlines", "\(language.rawValue): «\(text)»")
            let ready = Translations.translate("3 of 12 packed", to: language)
            check(ready.contains("3") && ready.contains("12"), "\(language.rawValue): «\(ready)»")
        }
    }

    private static func countNouns() throws {
        use(.tr)
        check(countNoun(3, "маица", "маици", "T-shirt", "T-shirts") == "3 tişört", "tr: \(countNoun(3, "маица", "маици", "T-shirt", "T-shirts"))")
        use(.de)
        check(countNoun(2, "маица", "маици", "T-shirt", "T-shirts") == "2 T-Shirts", "de: \(countNoun(2, "маица", "маици", "T-shirt", "T-shirts"))")
        use(.mk)
        check(countNoun(2, "маица", "маици", "T-shirt", "T-shirts") == "2 маици", "mk")
        use(.en)
        check(countNoun(1, "маица", "маици", "T-shirt", "T-shirts") == "1 T-shirt", "en")
        // Секој вид облека и секој ред од листата има свој превод за бројот („#…“ клучевите)
        let before = MissingTranslations.all
        for language in otherLanguages {
            use(language)
            for kind in WardrobeKind.allCases {
                _ = kind.count(1)
                _ = kind.count(3)
            }
            for key in ["tshirts", "longSleeves", "shirt", "sweater", "trousers", "smartTrousers", "shorts", "dress",
                        "eveningDress", "lightJacket", "warmJacket", "raincoat", "sneakers", "sandals", "smartShoes",
                        "boots", "hikingBoots", "trainingShoes", "swimwear", "sportswear", "daypack", "jewellery",
                        "sunglasses", "sunHat", "winterSet"] {
                _ = PackingRowText.count(key, 1)
                _ = PackingRowText.count(key, 4)
            }
        }
        let missing = MissingTranslations.all.subtracting(before).filter { $0.contains("|#") }.sorted()
        check(missing.isEmpty, "без превод: \(missing.count), пр. \(missing.prefix(4))")
    }

    private static func legalTexts() throws {
        for language in AppLanguage.allCases {
            use(language)
            check(LegalTexts.markdown(.privacy).count > 1000, "\(language.rawValue): приватност")
            check(LegalTexts.markdown(.terms).count > 1000, "\(language.rawValue): услови")
        }
    }

    // MARK: Листа, авиокомпании, прогноза

    private static func packingList() throws {
        for language in AppLanguage.allCases {
            use(language)
            let trip = sampleTrip()
            check(!trip.items.isEmpty, "\(language.rawValue): празна листа")
            check(trip.items.contains { $0.category == .documents }, "\(language.rawValue): нема документи")
            check(trip.items.contains { $0.category == .clothing }, "\(language.rawValue): нема облека")
            check(trip.items.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty },
                  "\(language.rawValue): предмет без име")
            check(trip.items.allSatisfy { $0.quantity >= 0 }, "\(language.rawValue): негативна бројка")
        }
        use(.en)
    }

    private static func airlines() throws {
        let all = Airlines.all
        check(all.count > 400, "само \(all.count) авиокомпании")
        for airline in all.dropLast() {
            check(Airlines.find(airline.id)?.id == airline.id, "find: \(airline.id)")
            let found = Airlines.search(airline.name)
            check(found.contains { $0.id == airline.id }, "пребарување по име: \(airline.name)")
            if !airline.code.isEmpty {
                check(Airlines.search(airline.code).contains { $0.id == airline.id }, "пребарување по код: \(airline.code) (\(airline.name))")
            }
        }
        check(Airlines.search("W6").first?.code == "W6", "W6 не е прва за „W6“")
    }

    private static func climate() throws {
        var july = DateComponents()
        july.year = 2026; july.month = 7; july.day = 15
        var january = DateComponents()
        january.year = 2027; january.month = 1; january.day = 15
        let summer = try unwrap(Calendar.current.date(from: july), "датум")
        let winter = try unwrap(Calendar.current.date(from: january), "датум")
        let athensSummer = ClimateEstimate.high(latitude: 37.98, on: summer)
        let osloWinter = ClimateEstimate.high(latitude: 59.91, on: winter)
        let sydneyJanuary = ClimateEstimate.high(latitude: -33.87, on: winter)
        check((24...38).contains(athensSummer), "Атина јули: \(athensSummer)")
        check((-12...8).contains(osloWinter), "Осло јануари: \(osloWinter)")
        check(sydneyJanuary > osloWinter + 10, "Сиднеј јануари (лето): \(sydneyJanuary)")
        let estimate = ClimateEstimate.day(latitude: 37.98, on: summer)
        check(estimate.isClimate && estimate.isEstimate, "проценката не е означена ~")
    }

    // MARK: Аутфити

    private static func outfitLayout() throws {
        let categories = WardrobeCategory.allCases
        let sizes = [CGSize(width: 320, height: 400), CGSize(width: 160, height: 200), CGSize(width: 400, height: 300)]
        for size in sizes {
            for count in 1...9 {
                let items = (0..<count).map { index in
                    WardrobeItem(name: "Piece \(index)", category: categories[index % categories.count], seasons: [])
                }
                let rects = OutfitCollage.layout(items, in: size)
                check(rects.count == count, "\(count) парчиња → \(rects.count) места")
                let canvas = CGRect(origin: .zero, size: size).insetBy(dx: -0.5, dy: -0.5)
                let list = Array(rects.values)
                for (i, rect) in list.enumerated() {
                    check(canvas.contains(rect), "\(count) парчиња: излегува од рамката \(rect)")
                    check(rect.width > 8 && rect.height > 8, "\(count) парчиња: премало \(rect)")
                    for other in list[(i + 1)...] {
                        let a = rect.insetBy(dx: 0.5, dy: 0.5)
                        let b = other.insetBy(dx: 0.5, dy: 0.5)
                        check(!a.intersects(b), "\(count) парчиња, \(Int(size.width))×\(Int(size.height)): преклопување")
                    }
                }
            }
        }
    }

    // MARK: Заедничко патување

    private static func memberOverlap() throws {
        let me = MemberPlan(origin: skopje,
                            stops: [TripStop(place: thessaloniki, startDate: day(10), endDate: day(13)),
                                    TripStop(place: athens, startDate: day(13), endDate: day(16))],
                            startDate: day(10), endDate: day(16))
        let friend = MemberPlan(origin: thessaloniki,
                                stops: [TripStop(place: athens, startDate: day(14), endDate: day(20))],
                                startDate: day(14), endDate: day(20))
        let overlap = try unwrap(me.overlap(with: friend), "преклопување")
        check(sameDay(overlap.start, day(14)) && sameDay(overlap.end, day(16)), "датуми на преклопување")
        check(overlap.cities == ["Athens"], "градови: \(overlap.cities)")
        check(me.routeText == "Skopje → Thessaloniki → Athens", "маршрута: \(me.routeText)")
        check(!me.sameRoute(as: friend) && me.sameRoute(as: me), "sameRoute")
        let later = MemberPlan(origin: skopje,
                               stops: [TripStop(place: athens, startDate: day(30), endDate: day(32))],
                               startDate: day(30), endDate: day(32))
        check(me.overlap(with: later) == nil, "патувања без заеднички денови")
    }

    private static func sharedTrip(owner: String, member: String) -> Trip {
        var trip = sampleTrip()
        trip.ownerUID = owner
        trip.memberUIDs = [owner, member]
        trip.companions = [Companion(name: "Ana Owner", uid: owner), Companion(name: "Mila Member", uid: member)]
        return trip
    }

    private static func memberFollowsOwner() throws {
        let owner = "selftest-owner", member = "selftest-member"
        let ownerTrip = sharedTrip(owner: owner, member: member)
        let document = try unwrap(CloudCodec.encode(ownerTrip, myUID: owner), "документ на сопственикот")
        check(document["startDate"] != nil, "сопственикот не ги запишал датумите")
        let asMember = try unwrap(CloudCodec.decode(document, local: nil, myUID: member), "декодирање за членот").trip
        check(sameDay(asMember.startDate, ownerTrip.startDate) && sameDay(asMember.endDate, ownerTrip.endDate),
              "новиот член нема исти датуми")
        check(asMember.ownPlan != true, "новиот член не смее да има свој план")
        check(asMember.memberPlans?[owner] != nil, "планот на сопственикот не се гледа")
    }

    private static func memberOwnPlan() throws {
        let owner = "selftest-owner", member = "selftest-member"
        let ownerTrip = sharedTrip(owner: owner, member: member)
        let ownerDocument = try unwrap(CloudCodec.encode(ownerTrip, myUID: owner), "документ на сопственикот")

        // Членот доаѓа 3 дена подоцна, од Солун
        var memberTrip = ownerTrip
        memberTrip.startDate = ownerTrip.startDate.adding(days: 3)
        memberTrip.origin = thessaloniki
        memberTrip.ownPlan = true
        let memberDocument = try unwrap(CloudCodec.encode(memberTrip, myUID: member), "документ на членот")
        check(memberDocument["startDate"] == nil, "членот ги менува датумите на сопственикот")
        check(memberDocument["origin"] == nil, "членот го менува поаѓањето на сопственикот")
        let allPersonal = try unwrap(memberDocument["personal"] as? [String: Any], "personal")
        let personal = try unwrap(allPersonal[member] as? [String: Any], "personal.\(member)")
        check(personal["startDate"] != nil, "датумите на членот не се во personal")

        // Облакот: горе — сопственикот, во personal — секој свое
        var cloud = ownerDocument
        var personalMap: [String: Any] = [member: personal]
        if let ownerPersonal = (ownerDocument["personal"] as? [String: Any])?[owner] {
            personalMap[owner] = ownerPersonal
        }
        cloud["personal"] = personalMap

        let asMember = try unwrap(CloudCodec.decode(cloud, local: nil, myUID: member), "декодирање за членот").trip
        check(sameDay(asMember.startDate, memberTrip.startDate), "членот не ги гледа своите датуми")
        check(asMember.origin?.id == thessaloniki.id, "членот не го гледа своето поаѓање")
        check(asMember.ownPlan == true, "ownPlan не е запаметен")
        let ownerPlan = try unwrap(asMember.memberPlans?[owner], "планот на сопственикот кај членот")
        check(sameDay(ownerPlan.startDate, ownerTrip.startDate), "кај членот се сменети датумите на сопственикот")

        let asOwner = try unwrap(CloudCodec.decode(cloud, local: nil, myUID: owner), "декодирање за сопственикот").trip
        check(sameDay(asOwner.startDate, ownerTrip.startDate), "кај сопственикот се сменети неговите датуми")
        check(asOwner.origin?.id == skopje.id, "кај сопственикот се смени поаѓањето")
        let memberPlan = try unwrap(asOwner.memberPlans?[member], "планот на членот кај сопственикот")
        check(sameDay(memberPlan.startDate, memberTrip.startDate), "сопственикот не ги гледа датумите на членот")
        check(memberPlan.origin?.id == thessaloniki.id, "сопственикот не го гледа поаѓањето на членот")
    }
}
#endif
