import Foundation

// MARK: - Вид облека (во рамките на групата)

/// Точниот вид на парчето: маица, џемпер, дуксер, сукња…
/// Секој вид знае во кој ред од листата за пакување се брои (џемпер → „Џемпер / дуксер“, не во маици).
enum WardrobeKind: String, Codable, CaseIterable, Identifiable {
    // Горни делови
    case tshirt, cropTop, longSleeve, shirt, sweater, hoodie, cardigan
    // Панталони и шорцеви
    case jeans, trousers, smartTrousers, leggings, shorts
    // Фустани и сукњи
    case dress, skirt, jumpsuit, eveningDress
    // Јакни и палта
    case lightJacket, blazer, warmJacket, coat, raincoat
    // Обувки
    case sneakers, sandals, smartShoes, heels, boots, hikingBoots, trainingShoes
    // Плажа и спорт
    case swimwear, sportswear
    // Торби
    case bag, backpack
    // Додатоци
    case jewellery, sunglasses, hat, scarf, belt, otherAccessory

    var id: String { rawValue }

    var category: WardrobeCategory {
        switch self {
        case .tshirt, .cropTop, .longSleeve, .shirt, .sweater, .hoodie, .cardigan: return .top
        case .jeans, .trousers, .smartTrousers, .leggings, .shorts: return .bottom
        case .dress, .skirt, .jumpsuit, .eveningDress: return .dress
        case .lightJacket, .blazer, .warmJacket, .coat, .raincoat: return .outerwear
        case .sneakers, .sandals, .smartShoes, .heels, .boots, .hikingBoots, .trainingShoes: return .shoes
        case .swimwear, .sportswear: return .active
        case .bag, .backpack: return .bag
        case .jewellery, .sunglasses, .hat, .scarf, .belt, .otherAccessory: return .accessory
        }
    }

    static func kinds(in category: WardrobeCategory) -> [WardrobeKind] {
        allCases.filter { $0.category == category }
    }

    /// Групи каде што видот може да се претпостави без прашање (фустан, торба, додаток).
    static func safeDefault(for category: WardrobeCategory) -> WardrobeKind? {
        switch category {
        case .dress: return .dress
        case .bag: return .bag
        case .accessory: return .otherAccessory
        default: return nil
        }
    }

    // MARK: Имиња

    private struct Names {
        let chipMK: String, chipEN: String
        let headMK: String, headEN: String
        let oneMK: String, manyMK: String
        let oneEN: String, manyEN: String
    }

    private var names: Names {
        func n(_ chipMK: String, _ chipEN: String, _ headMK: String, _ headEN: String,
               _ oneMK: String, _ manyMK: String, _ oneEN: String, _ manyEN: String) -> Names {
            Names(chipMK: chipMK, chipEN: chipEN, headMK: headMK, headEN: headEN,
                  oneMK: oneMK, manyMK: manyMK, oneEN: oneEN, manyEN: manyEN)
        }
        switch self {
        case .tshirt: return n("Маица", "T-shirt", "Маици", "T-shirts", "маица", "маици", "T-shirt", "T-shirts")
        case .cropTop: return n("Топ / кроп топ", "Top / crop top", "Топови", "Tops", "топ", "топа", "top", "tops")
        case .longSleeve: return n("Долги ракави", "Long sleeve", "Блузи со долги ракави", "Long sleeves",
                                   "блуза со долги ракави", "блузи со долги ракави", "long-sleeve top", "long-sleeve tops")
        case .shirt: return n("Кошула", "Shirt", "Кошули", "Shirts", "кошула", "кошули", "shirt", "shirts")
        case .sweater: return n("Џемпер", "Sweater", "Џемпери", "Sweaters", "џемпер", "џемпера", "sweater", "sweaters")
        case .hoodie: return n("Дуксер", "Hoodie", "Дуксери", "Hoodies", "дуксер", "дуксера", "hoodie", "hoodies")
        case .cardigan: return n("Кардиган", "Cardigan", "Кардигани", "Cardigans", "кардиган", "кардигана", "cardigan", "cardigans")
        case .jeans: return n("Фармерки", "Jeans", "Фармерки", "Jeans", "фармерки", "фармерки", "pair of jeans", "pairs of jeans")
        case .trousers: return n("Панталони", "Trousers", "Панталони", "Trousers", "панталони", "панталони", "pair of trousers", "pairs of trousers")
        case .smartTrousers: return n("Елегантни панталони", "Smart trousers", "Елегантни панталони", "Smart trousers",
                                      "елегантни панталони", "елегантни панталони", "pair of smart trousers", "pairs of smart trousers")
        case .leggings: return n("Хеланки", "Leggings", "Хеланки", "Leggings", "хеланки", "хеланки", "pair of leggings", "pairs of leggings")
        case .shorts: return n("Шорцеви", "Shorts", "Шорцеви", "Shorts", "шорцеви", "шорцеви", "pair of shorts", "pairs of shorts")
        case .dress: return n("Фустан", "Dress", "Фустани", "Dresses", "фустан", "фустани", "dress", "dresses")
        case .skirt: return n("Сукња", "Skirt", "Сукњи", "Skirts", "сукња", "сукњи", "skirt", "skirts")
        case .jumpsuit: return n("Комбинезон", "Jumpsuit", "Комбинезони", "Jumpsuits", "комбинезон", "комбинезона", "jumpsuit", "jumpsuits")
        case .eveningDress: return n("Вечерен фустан", "Evening dress", "Вечерни фустани", "Evening dresses",
                                     "вечерен фустан", "вечерни фустани", "evening dress", "evening dresses")
        case .lightJacket: return n("Лесна јакна", "Light jacket", "Лесни јакни", "Light jackets", "лесна јакна", "лесни јакни", "light jacket", "light jackets")
        case .blazer: return n("Сако", "Blazer", "Сакоа", "Blazers", "сако", "сакоа", "blazer", "blazers")
        case .warmJacket: return n("Топла јакна", "Warm jacket", "Топли јакни", "Warm jackets", "топла јакна", "топли јакни", "warm jacket", "warm jackets")
        case .coat: return n("Палто", "Coat", "Палта", "Coats", "палто", "палта", "coat", "coats")
        case .raincoat: return n("Кабаница", "Rain jacket", "Кабаници", "Rain jackets", "кабаница", "кабаници", "rain jacket", "rain jackets")
        case .sneakers: return n("Патики", "Sneakers", "Патики", "Sneakers", "пар патики", "пара патики", "pair of sneakers", "pairs of sneakers")
        case .sandals: return n("Сандали / папучи", "Sandals", "Сандали и папучи", "Sandals", "пар сандали", "пара сандали", "pair of sandals", "pairs of sandals")
        case .smartShoes: return n("Елегантни обувки", "Smart shoes", "Елегантни обувки", "Smart shoes",
                                   "пар елегантни обувки", "пара елегантни обувки", "pair of smart shoes", "pairs of smart shoes")
        case .heels: return n("Штикли", "Heels", "Штикли", "Heels", "пар штикли", "пара штикли", "pair of heels", "pairs of heels")
        case .boots: return n("Чизми / боти", "Boots", "Чизми и боти", "Boots", "пар чизми", "пара чизми", "pair of boots", "pairs of boots")
        case .hikingBoots: return n("Планинарски", "Hiking boots", "Планинарски чевли", "Hiking boots",
                                    "пар планинарски чевли", "пара планинарски чевли", "pair of hiking boots", "pairs of hiking boots")
        case .trainingShoes: return n("За тренинг", "Training shoes", "Патики за тренинг", "Training shoes",
                                      "пар патики за тренинг", "пара патики за тренинг", "pair of training shoes", "pairs of training shoes")
        case .swimwear: return n("Костим за капење", "Swimwear", "Костими за капење", "Swimwear",
                                 "костим за капење", "костими за капење", "swimsuit", "swimsuits")
        case .sportswear: return n("Спортска облека", "Sportswear", "Спортска облека", "Sportswear",
                                   "спортски комплет", "спортски комплети", "sports set", "sports sets")
        case .bag: return n("Торба", "Bag", "Торби", "Bags", "торба", "торби", "bag", "bags")
        case .backpack: return n("Ранец", "Backpack", "Ранци", "Backpacks", "ранец", "ранци", "backpack", "backpacks")
        case .jewellery: return n("Накит", "Jewellery", "Накит", "Jewellery", "парче накит", "парчиња накит", "piece of jewellery", "pieces of jewellery")
        case .sunglasses: return n("Очила", "Sunglasses", "Очила", "Sunglasses", "пар очила", "пара очила", "pair of sunglasses", "pairs of sunglasses")
        case .hat: return n("Капа / шапка", "Hat / cap", "Капи и шапки", "Hats", "капа", "капи", "hat", "hats")
        case .scarf: return n("Шал", "Scarf", "Шалови", "Scarves", "шал", "шала", "scarf", "scarves")
        case .belt: return n("Каиш", "Belt", "Каиши", "Belts", "каиш", "каиши", "belt", "belts")
        case .otherAccessory: return n("Друго", "Other", "Друго", "Other", "додаток", "додатоци", "accessory", "accessories")
        }
    }

    /// Кратко име за избор („Џемпер“).
    var title: String { L(names.chipMK, names.chipEN) }

    /// Наслов во гардеробата („Џемпери“).
    var header: String { L(names.headMK, names.headEN) }

    /// „1 маица“, „3 џемпера“, „2 пара патики“…
    func count(_ n: Int) -> String {
        n == 1 ? L("1 \(names.oneMK)", "1 \(names.oneEN)") : L("\(n) \(names.manyMK)", "\(n) \(names.manyEN)")
    }

    // MARK: Врска со листата за пакување

    /// Редовите од листата во кои се брои, по редослед (првиот што постои во листата).
    var packingKeys: [String] {
        switch self {
        case .tshirt, .cropTop: return ["tshirts"]
        case .longSleeve: return ["longSleeves"]
        case .shirt: return ["shirt"]
        case .sweater, .hoodie, .cardigan: return ["sweater"]
        case .jeans, .trousers, .leggings: return ["trousers", "longTrousers"]
        case .smartTrousers: return ["smartTrousers"]
        case .shorts: return ["shorts"]
        case .dress, .skirt, .jumpsuit: return ["dress"]
        case .eveningDress: return ["eveningDress"]
        case .lightJacket, .blazer: return ["lightJacket"]
        case .warmJacket, .coat: return ["warmJacket"]
        case .raincoat: return ["raincoat"]
        case .sneakers: return ["sneakers"]
        case .sandals: return ["sandals"]
        case .smartShoes, .heels: return ["smartShoes", "dressShoes"]
        case .boots: return ["boots"]
        case .hikingBoots: return ["hikingBoots"]
        case .trainingShoes: return ["trainingShoes"]
        case .swimwear: return ["swimwear"]
        case .sportswear: return ["sportswear"]
        case .bag: return ["daypack"]
        case .backpack: return ["daypack", "hikingPack"]
        case .jewellery: return ["jewellery"]
        case .sunglasses: return ["sunglasses"]
        case .hat: return ["sunHat", "winterSet"]
        case .scarf: return ["winterSet"]
        case .belt, .otherAccessory: return []
        }
    }

    /// Ако листата го нема редот, а парчето е во аутфитите — кој ред сам се додава.
    /// nil = не се додава (пр. шал во лето не значи „капа, шал и ракавици“).
    var newRowKey: String? {
        switch self {
        case .hat, .scarf, .belt, .otherAccessory: return nil
        default: return packingKeys.first
        }
    }

    /// Каде оди нов ред во листата.
    var rowCategory: ItemCategory {
        switch category {
        case .top, .bottom, .dress: return .clothing
        case .outerwear: return self == .raincoat ? .accessories : .clothing
        case .shoes: return .shoes
        case .active: return .activity
        case .bag, .accessory: return .accessories
        }
    }

    /// Редови што гардеробата ги покрива (за споредба листа ↔ аутфити).
    static let coveredKeys: Set<String> = Set(allCases.flatMap(\.packingKeys))
        .union(WardrobeCategory.allCases.flatMap(\.legacyKeys))

    /// Облека и обувки — секогаш се споредуваат со аутфитите (останатото само ако е во некој аутфит).
    static let coreKeys: Set<String> = [
        "tshirts", "longSleeves", "shirt", "sweater",
        "trousers", "longTrousers", "smartTrousers", "shorts",
        "dress", "eveningDress", "lightJacket", "warmJacket",
        "sneakers", "sandals", "smartShoes", "dressShoes", "boots", "hikingBoots", "trainingShoes"
    ]

    // MARK: Волумен и тежина (свиткано, како во листата)

    var volume: Double {
        switch self {
        case .tshirt: return 0.6
        case .cropTop: return 0.4
        case .longSleeve: return 0.8
        case .shirt: return 0.9
        case .sweater: return 1.6
        case .hoodie: return 1.8
        case .cardigan: return 1.4
        case .jeans: return 1.3
        case .trousers, .smartTrousers: return 1.2
        case .leggings: return 0.6
        case .shorts: return 0.7
        case .dress: return 0.8
        case .skirt: return 0.7
        case .jumpsuit, .eveningDress: return 1.0
        case .lightJacket, .blazer: return 2.0
        case .warmJacket: return 5.0
        case .coat: return 4.5
        case .raincoat: return 0.6
        case .sneakers, .trainingShoes: return 4.0
        case .sandals: return 1.5
        case .smartShoes, .heels: return 2.5
        case .boots, .hikingBoots: return 5.0
        case .swimwear: return 0.2
        case .sportswear: return 0.7
        case .bag: return 2.5
        case .backpack: return 3.0
        case .jewellery: return 0.1
        case .sunglasses: return 0.2
        case .hat: return 0.8
        case .scarf: return 0.6
        case .belt, .otherAccessory: return 0.3
        }
    }

    var weight: Double {
        switch self {
        case .tshirt: return 0.18
        case .cropTop: return 0.12
        case .longSleeve: return 0.22
        case .shirt: return 0.25
        case .sweater: return 0.45
        case .hoodie: return 0.5
        case .cardigan: return 0.4
        case .jeans: return 0.55
        case .trousers, .smartTrousers: return 0.45
        case .leggings: return 0.2
        case .shorts: return 0.25
        case .dress, .skirt: return 0.25
        case .jumpsuit, .eveningDress: return 0.35
        case .lightJacket: return 0.5
        case .blazer: return 0.6
        case .warmJacket: return 1.2
        case .coat: return 1.3
        case .raincoat: return 0.3
        case .sneakers: return 0.8
        case .trainingShoes: return 0.7
        case .sandals: return 0.4
        case .smartShoes, .heels: return 0.5
        case .boots: return 1.2
        case .hikingBoots: return 1.3
        case .swimwear: return 0.1
        case .sportswear: return 0.25
        case .bag: return 0.5
        case .backpack: return 0.6
        case .jewellery, .sunglasses: return 0.05
        case .hat: return 0.1
        case .scarf, .belt: return 0.15
        case .otherAccessory: return 0.1
        }
    }

    // MARK: Слика на аутфитот

    /// Редослед на слоеви: маицата под џемперот, џемперот под јакната.
    var layer: Double {
        switch self {
        case .jeans, .trousers, .smartTrousers, .leggings, .shorts, .skirt: return 1
        case .dress, .jumpsuit, .eveningDress: return 1
        case .tshirt, .cropTop, .longSleeve, .shirt, .swimwear, .sportswear: return 2
        case .sweater, .hoodie, .cardigan: return 3
        case .lightJacket, .blazer, .warmJacket, .coat, .raincoat: return 4
        case .sneakers, .sandals, .smartShoes, .heels, .boots, .hikingBoots, .trainingShoes: return 5
        case .bag, .backpack: return 5
        case .jewellery, .sunglasses, .hat, .scarf, .belt, .otherAccessory: return 6
        }
    }

    // MARK: Погодување од името

    /// Од името на парчето („Сив дуксер“, „Black skirt“…). `category` = само видови од таа група.
    static func guess(_ name: String, in category: WardrobeCategory?) -> WardrobeKind? {
        let folded = fold(name)
        guard !folded.isEmpty else { return nil }
        let words = folded.split { !$0.isLetter }.map(String.init)
        for rule in rules where category == nil || rule.kind.category == category {
            if rule.keywords.contains(where: { matches($0, folded: folded, words: words) }) {
                return rule.kind
            }
        }
        return nil
    }

    /// Видови што порано беа во друга група и сега се селат (сукња од „Долни“, костим, спортска облека).
    var movesOnMigration: Bool {
        self == .skirt || self == .swimwear || self == .sportswear
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// „=топ“ = цел збор; со празно место или цртичка = дел од текстот; инаку збор што почнува така.
    private static func matches(_ keyword: String, folded: String, words: [String]) -> Bool {
        if keyword.hasPrefix("=") {
            let word = String(keyword.dropFirst())
            return words.contains(word)
        }
        if keyword.contains(where: { !$0.isLetter }) {
            return folded.contains(keyword)
        }
        return words.contains { $0.hasPrefix(keyword) }
    }

    private struct Rule {
        let kind: WardrobeKind
        let keywords: [String]
    }

    /// Редоследот е важен: попрецизното прво („вечерен фустан“ пред „фустан“, „t-shirt“ пред „shirt“).
    private static let rules: [Rule] = {
        let raw: [(WardrobeKind, [String])] = [
            (.eveningDress, ["вечерен фустан", "вечерен", "вечерна", "свечен", "evening", "gala", "гала"]),
            (.jumpsuit, ["комбинезон", "kombinezon", "jumpsuit", "overall"]),
            (.skirt, ["сукњ", "suknj", "skirt"]),
            (.swimwear, ["костим за капење", "kostim za kapenje", "бикини", "bikini", "swim", "kupac", "капаќ"]),
            (.heels, ["штикл", "stikl", "heel", "потпетиц", "potpetic"]),
            (.hikingBoots, ["планинарск", "planinarsk", "hiking"]),
            (.trainingShoes, ["за тренинг", "za trening", "running", "трчање", "training shoe"]),
            (.boots, ["чизм", "cizm", "=боти", "=бот", "=boti", "boot", "ботуш"]),
            (.sandals, ["сандал", "sandal", "папуч", "papuc", "јапанк", "japank", "flip", "slide", "натикач", "natikac"]),
            (.sneakers, ["патик", "patik", "sneaker", "кецк", "keck", "trainer", "nike", "adidas", "converse", "=vans", "new balance"]),
            (.smartShoes, ["чевл", "cevl", "loafer", "мокасин", "mokasin", "oxford", "балерин", "balerin", "dress shoe", "елегантни обувки"]),
            (.raincoat, ["кабаниц", "kabanic", "raincoat", "rain jacket", "мантил за дожд"]),
            (.blazer, ["=сако", "=sako", "blazer", "блејзер", "blejzer"]),
            (.coat, ["палт", "palt", "мантил", "mantil", "=coat", "trench", "тренч"]),
            (.warmJacket, ["зимск", "zimsk", "пуфер", "pufer", "puffer", "перјан", "perjan", "парка", "parka",
                           "топла јакна", "topla jakna", "down jacket", "winter"]),
            (.lightJacket, ["јакн", "jakn", "jacket", "бомбер", "bomber", "ветровк", "vetrovk", "windbreaker"]),
            (.hoodie, ["дуксер", "duks", "hoodie", "худи", "hudi", "sweatshirt"]),
            (.cardigan, ["кардиган", "kardigan", "cardigan"]),
            (.sweater, ["џемпер", "dzemper", "djemper", "sweater", "jumper", "пуловер", "pulover", "pullover",
                        "плетен", "pleten", "knit", "ролка", "rolka", "turtleneck"]),
            (.shirt, ["кошул", "kosul", "koshul"]),
            (.longSleeve, ["блуз", "bluz", "долги ракави", "dolgi rakavi", "long sleeve", "long-sleeve", "longsleeve"]),
            (.tshirt, ["маиц", "majic", "majc", "t-shirt", "tshirt", "=tee", "=polo", "=поло"]),
            (.shirt, ["=shirt", "=shirts", "button-down"]),
            (.cropTop, ["кроп", "krop", "crop", "=топ", "=топови", "=top", "=tops", "бустие", "bustier",
                        "корсет", "korset", "без ракави", "bez rakavi", "tank", "bralette"]),
            (.jeans, ["фармерк", "farmerk", "jeans", "denim", "тексас", "teksas"]),
            (.leggings, ["хеланк", "helank", "legging"]),
            (.smartTrousers, ["елегантни панталони", "официјални панталони", "smart trousers", "dress pants", "suit pants"]),
            (.shorts, ["шорц", "sorc", "short", "бермуд", "bermud"]),
            (.trousers, ["панталон", "pantalon", "trouser", "pants", "chino", "карго", "cargo", "jogger"]),
            (.sportswear, ["спортск", "sportsk", "тренерк", "trenerk", "sport", "=gym", "фитнес", "fitnes", "yoga", "јога"]),
            (.dress, ["фустан", "fustan", "dress"]),
            (.backpack, ["ранец", "ranec", "ранч", "ranc", "раниц", "ranic", "backpack"]),
            (.bag, ["торб", "torb", "чант", "cant", "=bag", "handbag", "tote", "clutch", "клач"]),
            (.jewellery, ["накит", "nakit", "гердан", "gerdan", "огрлиц", "ogrlic", "обетк", "obetk", "минѓуш", "mindjus",
                          "прстен", "prsten", "нараквиц", "narakvic", "ланче", "lance", "jewel", "necklace", "earring",
                          "bracelet", "=ring", "=rings", "часовник", "casovnik", "=watch"]),
            (.sunglasses, ["очила", "ocila", "glasses", "sunglass"]),
            (.hat, ["=капа", "=капи", "=kapa", "шапка", "sapka", "шешир", "sesir", "=hat", "=cap", "beanie"]),
            (.scarf, ["=шал", "=sal", "шамија", "scarf", "марама", "marama"]),
            (.belt, ["каиш", "kais", "ремен", "remen", "belt"])
        ]
        return raw.map { kind, words in
            Rule(kind: kind, keywords: words.map { word in
                word.hasPrefix("=") ? "=" + WardrobeKind.fold(String(word.dropFirst())) : WardrobeKind.fold(word)
            })
        }
    }()
}

// MARK: - Групи по вид (за приказ во гардеробата)

struct WardrobeKindGroup: Identifiable {
    let id: String
    let title: String
    let items: [WardrobeItem]

    /// Парчињата од една група (пр. „Горни делови“) поделени по вид: Маици · Џемпери · Дуксери…
    static func groups(_ items: [WardrobeItem]) -> [WardrobeKindGroup] {
        var result: [WardrobeKindGroup] = []
        for kind in WardrobeKind.allCases {
            let list = items.filter { $0.effectiveKind == kind }
            if !list.isEmpty {
                result.append(WardrobeKindGroup(id: kind.rawValue, title: kind.header, items: list))
            }
        }
        let rest = items.filter { $0.effectiveKind == nil }
        if !rest.isEmpty {
            result.append(WardrobeKindGroup(id: "none", title: L("Без вид", "No type yet"), items: rest))
        }
        return result
    }
}

// MARK: - Парчето и неговиот вид

extension WardrobeItem {
    var kind: WardrobeKind? {
        get { kindID.flatMap(WardrobeKind.init(rawValue:)) }
        set { kindID = newValue?.rawValue }
    }

    /// Видот што важи: избраниот (ако одговара на групата) или сигурниот за групата.
    var effectiveKind: WardrobeKind? {
        if let kind, kind.category == category { return kind }
        return WardrobeKind.safeDefault(for: category)
    }

    /// Треба да се избере вид (маица, џемпер…), за листата да знае каде да го брои.
    var needsKind: Bool { effectiveKind == nil }

    /// Редовите од листата во кои се брои. Без вид — како порано, по групата.
    var packingKeys: [String] { effectiveKind?.packingKeys ?? category.legacyKeys }

    var volume: Double { effectiveKind?.volume ?? category.volume }
    var weight: Double { effectiveKind?.weight ?? category.weight }
    var layer: Double { effectiveKind?.layer ?? 2 }

    /// Постоечка облека (пред видовите): видот се погодува од името; сукња, костим и спортска облека
    /// се селат во новите групи. Што не може да се погоди — останува „Без вид“ за да се подреди со допир.
    func migratedKind() -> WardrobeItem {
        guard kind == nil else { return self }
        var copy = self
        if let found = WardrobeKind.guess(name, in: category) {
            copy.kind = found
        } else if let found = WardrobeKind.guess(name, in: nil), found.movesOnMigration {
            copy.kind = found
            copy.category = found.category
        }
        return copy
    }
}

// MARK: - Имиња на редовите од листата (за „фалат 2 маици“)

enum PackingRowText {
    static func count(_ key: String, _ n: Int) -> String {
        let one = n == 1
        func w(_ oneMK: String, _ manyMK: String, _ oneEN: String, _ manyEN: String) -> String {
            one ? L("1 \(oneMK)", "1 \(oneEN)") : L("\(n) \(manyMK)", "\(n) \(manyEN)")
        }
        switch key {
        case "tshirts": return w("маица", "маици", "T-shirt", "T-shirts")
        case "longSleeves": return w("блуза со долги ракави", "блузи со долги ракави", "long-sleeve top", "long-sleeve tops")
        case "shirt": return w("кошула", "кошули", "shirt", "shirts")
        case "sweater": return w("џемпер или дуксер", "џемпери или дуксери", "sweater or hoodie", "sweaters or hoodies")
        case "trousers", "longTrousers": return w("панталони", "панталони", "pair of trousers", "pairs of trousers")
        case "smartTrousers": return w("елегантни панталони", "елегантни панталони", "pair of smart trousers", "pairs of smart trousers")
        case "shorts": return w("шорцеви", "шорцеви", "pair of shorts", "pairs of shorts")
        case "dress": return w("фустан или сукња", "фустани или сукњи", "dress or skirt", "dresses or skirts")
        case "eveningDress": return w("фустан за вечер", "фустани за вечер", "evening dress", "evening dresses")
        case "lightJacket": return w("лесна јакна", "лесни јакни", "light jacket", "light jackets")
        case "warmJacket": return w("топла јакна", "топли јакни", "warm jacket", "warm jackets")
        case "raincoat": return w("кабаница", "кабаници", "rain jacket", "rain jackets")
        case "sneakers": return w("пар патики", "пара патики", "pair of sneakers", "pairs of sneakers")
        case "sandals": return w("пар сандали", "пара сандали", "pair of sandals", "pairs of sandals")
        case "smartShoes", "dressShoes": return w("пар елегантни обувки", "пара елегантни обувки", "pair of smart shoes", "pairs of smart shoes")
        case "boots": return w("пар чизми", "пара чизми", "pair of boots", "pairs of boots")
        case "hikingBoots": return w("пар планинарски чевли", "пара планинарски чевли", "pair of hiking boots", "pairs of hiking boots")
        case "trainingShoes": return w("пар патики за тренинг", "пара патики за тренинг", "pair of training shoes", "pairs of training shoes")
        case "swimwear": return w("костим за капење", "костими за капење", "swimsuit", "swimsuits")
        case "sportswear": return w("спортски комплет", "спортски комплети", "sports set", "sports sets")
        case "daypack", "hikingPack": return w("торба", "торби", "bag", "bags")
        case "jewellery": return w("парче накит", "парчиња накит", "piece of jewellery", "pieces of jewellery")
        case "sunglasses": return w("пар очила", "пара очила", "pair of sunglasses", "pairs of sunglasses")
        case "sunHat": return w("капа за сонце", "капи за сонце", "sun hat", "sun hats")
        case "winterSet": return w("капа или шал", "капи или шалови", "hat or scarf", "hats or scarves")
        default:
            let name = Catalog.name(key) ?? key
            return "\(n) × \(name)"
        }
    }
}
