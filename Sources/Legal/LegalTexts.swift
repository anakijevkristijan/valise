// Генерирано од legal/*.md — Политика за приватност и Услови за користење (MK/EN).
// Истите текстови се објавени и на веб-страницата (за App Store Connect).
import Foundation

enum LegalDoc: String, Identifiable {
    case privacy, terms
    var id: String { rawValue }
}

enum LegalTexts {
    /// Е-пошта за поддршка (празно додека не се внесе вистинска).
    static let supportEmail: String = {
        let value = "[support email]"
        return value.hasPrefix("[") ? "" : value
    }()

    static func markdown(_ doc: LegalDoc) -> String {
        switch (doc, AppLanguage.current) {
        case (.privacy, .mk): return privacyMK
        case (.privacy, .en): return privacyEN
        case (.terms, .mk): return termsMK
        case (.terms, .en): return termsEN
        }
    }

    static let privacyMK = #"""
    # Политика за приватност

    Важи од: 28 октомври 2026

    Tripdrobe („апликацијата“) ја развива и одржува [Име и презиме], [Адреса, град], Северна Македонија („ние“). Ние сме одговорни за обработката на твоите лични податоци. За сè што е поврзано со приватноста пиши на [е-пошта за поддршка].

    Накратко: собираме само она што е потребно за апликацијата да работи. Немаме реклами, не го следиме твоето однесување и не продаваме податоци.

    ## Кои податоци ги собираме

    **Акаунт.** Име, е-пошта и идентификатор на акаунтот. Ако се најавиш со Google или Apple, од нив ги добиваме името и е-поштата (кај Apple може да биде скриена адреса). Лозинката ја чува Firebase Authentication и ние не ја гледаме.

    **Телефонски број (по избор).** Ако го внесеш, останува на твојот телефон. Во базата праќаме само шифриран отпечаток (SHA-256) од бројот и од е-поштата, за да можат пријателите да те најдат кога те канат на патување.

    **Патувања.** Дестинација, датуми, превоз, авиокомпанија и багаж, листи за пакување, листата „Пред излез“ и имињата на сопатниците што ги додаваш.

    **Заеднички патувања.** Деталите на патувањето и делот „Заедно“ (што се носи и кој го носи) ги гледаат сите членови на тоа патување. Твојата лична листа ја гледаш само ти.

    **Гардероба и аутфити.** Фотографии од облека што ги правиш или избираш, категории, сезони, аутфити и план по денови. Пред да се зачува сликата, апликацијата го отстранува лицето, а слика на која останува лице не се зачувува. Гардеробата ја гледаш само ти.

    **Контакти.** Кога каниш пријател, го користиме само контактот што ќе го избереш (име и број или е-пошта) за да направиме шифриран клуч за поканата. Твојот именик не се праќа никаде.

    **Купувања.** Плаќањето го води Apple. Ние добиваме само потврда дека Premium е купен, без податоци за картичката.

    **Што не собираме:** локација на уредот, аналитика, рекламни идентификатори и снимки од екранот.

    ## Зошто ги користиме и врз која основа

    - За да ти ја овозможиме апликацијата (договор со тебе): акаунт, синхронизација меѓу уредите, заеднички патувања, гардероба, прогноза и Premium.
    - За безбедност и спречување злоупотреба (легитимен интерес).
    - Пристап до камерата, фотографиите и контактите бараме само преку системското прашање на iOS и само кога ја користиш таа функција. Можеш да го повлечеш секогаш во Поставки на iPhone.

    ## Со кого ги делиме

    Само со услугите без кои апликацијата не може да работи:

    - **Google (Firebase Authentication, Cloud Firestore, Google Sign-In)** – најава и чување на податоците.
    - **Apple** – Најава со Apple, купувања преку App Store, пребарување места (Apple Maps / MapKit) и, во верзијата од App Store, прогнозата (Apple Weather / WeatherKit). Се праќаат тоа што го пребаруваш, координатите на дестинацијата и датумите.
    - **Open-Meteo** – прогноза само во тест-верзиите. Се праќаат координатите на дестинацијата и датумите.
    - **Wikimedia (Wikipedia, Wikidata, Commons)** – фотографии од дестинацијата. Се праќаат името и координатите на местото.

    Како и при секое барање на интернет, овие услуги ја гледаат IP адресата на уредот. Податоците не ги продаваме и не ги делиме за реклами.

    ## Каде се чуваат

    Патувањата, гардеробата и профилот се чуваат во базата Google Cloud Firestore во Европската Унија (регион eur3). Податоците за најава (Firebase Authentication) Google може да ги обработува и во САД и во други држави; за пренос надвор од ЕУ/ЕЕП користи ја Рамката за приватност на податоци ЕУ–САД и стандардни договорни клаузули. Податоците патуваат шифрирано, а пристапот до базата е ограничен со безбедносни правила.

    ## Колку долго ги чуваме

    Додека го имаш акаунтот. Од телефонот податоците се бришат при одјава. Кога ќе го избришеш акаунтот (Поставки → Избриши акаунт), веднаш се бришат профилот, гардеробата, аутфитите, патувањата чиј сопственик си, како и твојата листа и членство во туѓите патувања. Тоа што си го додал во делот „Заедно“ на туѓо патување останува кај другите членови.

    ## Твоите права

    Имаш право да побараш пристап до податоците, исправка, бришење, ограничување на обработката и пренос, како и да се спротивставиш на обработката. Повеќето можеш сам во апликацијата, а за сè друго пиши на [е-пошта за поддршка]. Ќе ти одговориме најдоцна за 30 дена. Имаш право на приговор до Агенцијата за заштита на личните податоци (azlp.mk) или до надлежниот орган во државата каде што живееш.

    **Жители на Калифорнија:** не продаваме и не „споделуваме“ лични податоци според CCPA/CPRA и имаш право да дознаеш кои податоци ги имаме и да побараш бришење. Апликацијата не следи корисници низ други апликации и сајтови, па сигналите „Do Not Track“ немаат што да сменат.

    ## Деца

    Tripdrobe не е наменета за деца под 13 години. При регистрација прашуваме за датумот на раѓање, не создаваме акаунт за помлади од 13 години и не го чуваме датумот. Ако дознаеме дека имаме податоци од дете под 13 години, ги бришеме. Во државите каде што до 16 години е потребна согласност од родител, помладите корисници ја користат апликацијата со дозвола од родител.

    ## Промени

    Ако ја смениме оваа политика, ќе те известиме во апликацијата. Датумот на почетокот покажува кога е последната промена.

    ## Контакт

    [Име и презиме], [Адреса, град], Северна Македонија · [е-пошта за поддршка]
    """#

    static let privacyEN = #"""
    # Privacy Policy

    Effective: October 28, 2026

    Tripdrobe (“the app”) is developed and run by [Full name], [Address, city], North Macedonia (“we”). We are responsible for processing your personal data. For anything about privacy, write to [support email].

    In short: we collect only what the app needs to work. No ads, no behavioural tracking, and we never sell data.

    ## What we collect

    **Account.** Name, email and an account identifier. If you sign in with Google or Apple, we receive your name and email from them (with Apple this may be a private relay address). Your password is handled by Firebase Authentication; we never see it.

    **Phone number (optional).** If you enter it, it stays on your phone. We upload only a one-way fingerprint (SHA-256) of your number and email so friends can find you when they invite you to a trip.

    **Trips.** Destination, dates, transport, airline and bags, packing lists, the “Before you leave” checklist and the names of companions you add.

    **Shared trips.** Trip details and the “Together” section (what is brought and by whom) are visible to every member of that trip. Your personal list is visible only to you.

    **Wardrobe and outfits.** Photos of clothes you take or choose, categories, seasons, outfits and your day-by-day plan. Before a photo is saved, the app removes any face, and a photo that still shows a face is not saved. Your wardrobe is visible only to you.

    **Contacts.** When you invite a friend, we use only the contact you pick (name and phone or email) to create an encrypted invite key. Your address book is never uploaded.

    **Purchases.** Payments are handled by Apple. We only receive confirmation that Premium was bought, never card details.

    **What we don't collect:** device location, analytics, advertising identifiers or screen recordings.

    ## Why we use it and on what basis

    - To provide the app (our contract with you): your account, sync across devices, shared trips, wardrobe, forecast and Premium.
    - For security and to prevent abuse (legitimate interest).
    - We ask for camera, photos and contacts access only through the iOS system prompt and only when you use that feature. You can withdraw it anytime in iPhone Settings.

    ## Who we share it with

    Only with the services the app cannot work without:

    - **Google (Firebase Authentication, Cloud Firestore, Google Sign-In)** – sign-in and data storage.
    - **Apple** – Sign in with Apple, App Store purchases, place search (Apple Maps / MapKit) and, in the App Store version, the forecast (Apple Weather / WeatherKit); what you search for, the destination's coordinates and the dates are sent.
    - **Open-Meteo** – forecast in test builds only; the destination's coordinates and dates are sent.
    - **Wikimedia (Wikipedia, Wikidata, Commons)** – destination photos; the place's name and coordinates are sent.

    As with any internet request, these services see your device's IP address. We do not sell data or share it for advertising.

    ## Where it is stored

    Your trips, wardrobe and profile are stored in Google Cloud Firestore in the European Union (region eur3). Sign-in data (Firebase Authentication) may also be processed by Google in the US and other countries; for transfers outside the EU/EEA Google relies on the EU–US Data Privacy Framework and Standard Contractual Clauses. Data is encrypted in transit and database access is restricted by security rules.

    ## How long we keep it

    For as long as you have an account. Data on your phone is removed when you sign out. When you delete your account (Settings → Delete account), we immediately delete your profile, wardrobe, outfits, the trips you own, and your list and membership in other people's trips. Items you added to the “Together” section of someone else's trip stay with the other members.

    ## Your rights

    You can request access, correction, deletion, restriction or portability of your data, and you can object to processing. Most of this you can do yourself in the app; for anything else write to [support email]. We reply within 30 days. You may complain to the Personal Data Protection Agency of North Macedonia (azlp.mk) or to the data protection authority where you live.

    **California residents:** we do not sell or “share” personal information under the CCPA/CPRA, and you have the right to know what we hold and to ask for deletion. The app does not track you across other apps or websites, so “Do Not Track” signals have nothing to change.

    ## Children

    Tripdrobe is not intended for children under 13. At sign-up we ask for a date of birth, we don't create an account for anyone under 13, and we don't keep the date. If we learn that we hold data from a child under 13, we delete it. Where local law requires parental consent up to age 16, younger users use the app with a parent's permission.

    ## Changes

    If we change this policy, we will let you know in the app. The date at the top shows the latest change.

    ## Contact

    [Full name], [Address, city], North Macedonia · [support email]
    """#

    static let termsMK = #"""
    # Услови за користење

    Важи од: 28 октомври 2026

    Овие услови важат за апликацијата Tripdrobe што ја нуди [Име и презиме], [Адреса, град], Северна Македонија („ние“). Кога создаваш акаунт или ја користиш апликацијата, се согласуваш со нив и со Политиката за приватност.

    ## 1. Кој може да ја користи

    Мора да имаш најмалку 13 години. Ако си помлад од полнолетството во твојата држава, ти треба дозвола од родител. Акаунтот е личен и ти си одговорен за пристапот до него.

    ## 2. Што нуди Tripdrobe

    Листи за пакување, прогноза, правила за багаж, гардероба, аутфити и заеднички патувања. Прогнозата, правилата за багаж на авиокомпаниите и предлозите за пакување се само информативни и може да се сменат или да не се точни. Пред патување секогаш провери ги правилата кај авиокомпанијата. Не одговараме за доплати за багаж, заборавени работи или одлуки донесени врз основа на прогнозата.

    ## 3. Premium

    Бесплатно можеш да направиш колку сакаш патувања со листа за пакување. Premium (прогноза, авиокомпании и багаж, гардероба и аутфити, пријатели, Story, „Пред излез“ и теми) се купува преку App Store како месечна или годишна претплата. Цената, периодот и условите на пробата се прикажани пред плаќањето.

    - **Претплатата се обновува автоматски** и се наплаќа преку твојот Apple ID на крајот на секој период, сè додека не ја откажеш најмалку 24 часа пред крајот на тековниот период.
    - **Бесплатна проба:** ако ја има, на крајот на пробата се наплаќа првиот период, освен ако не ја откажеш барем 24 часа пред тоа. Пробата се нуди еднаш по Apple ID.
    - **Откажување и управување:** Поставки на iPhone → твоето име → Претплати. По откажувањето Premium останува до крајот на платениот период.

    Плаќањето, сметките и враќањето пари ги води Apple според своите услови, па барањето за враќање пари се праќа до Apple. Купувањето можеш да го вратиш на нов уред со „Врати купување“. Ако ја смениме цената на претплатата, Apple однапред ќе те извести и ќе побара согласност кога тоа е потребно.

    ## 4. Твојата содржина

    Фотографиите, листите и аутфитите се твои. Ни даваш ограничена дозвола да ги чуваме и обработуваме само за да ти ја овозможиме апликацијата и да ги прикажеме на членовите на патувањата што ги споделуваш.

    Ставај само фотографии што се твои или имаш право да ги користиш, без луѓе на нив. Забранета е незаконска содржина, содржина што крши туѓи права, вознемирување и секаква содржина што сексуализира деца. Покани само луѓе што сакаат да патуваат со тебе.

    ## 5. Авторски права

    Ако мислиш дека содржина во Tripdrobe ги крши твоите авторски права, пиши на [е-пошта за поддршка]. Опиши го делото, каде се наоѓа и остави контакт. Ако пријавата е основана, ја отстрануваме содржината, а акаунтите што постојано кршат туѓи права ги исклучуваме. Фотографиите од дестинациите се од Wikimedia Commons и се прикажуваат со авторот и лиценцата.

    ## 6. Престанок

    Акаунтот можеш да го избришеш секогаш во Поставки. Можеме да суспендираме акаунт што ги крши овие услови.

    ## 7. Одговорност

    Апликацијата се нуди „каква што е“. Колку што дозволува законот, не одговараме за индиректна штета. Ништо во овие услови не ги ограничува правата што ги имаш како потрошувач според законите на твојата држава.

    ## 8. Apple

    Овие услови се договор помеѓу тебе и нас, не со Apple. Apple не е одговорен за апликацијата, нејзината содржина, одржувањето и поддршката. Ако апликацијата не одговара на некоја важечка гаранција, можеш да го известиш Apple и Apple ќе ти ја врати цената; Apple нема други гаранциски обврски. За побарувања поврзани со апликацијата (одговорност за производот, усогласеност со прописите, заштита на потрошувачите, интелектуална сопственост) одговорни сме ние, а не Apple. Изјавуваш дека не се наоѓаш во држава под ембарго на САД и не си на листа на лица со забрана. Apple и неговите подружници се трети корисници на овие услови и можат да ги спроведуваат. Важат и Условите на Apple Media Services.

    ## 9. Право и промени

    За овие услови важи правото на Република Северна Македонија, без да се ограничат задолжителните права на потрошувачите во твојата држава. Ако ги смениме условите, ќе те известиме во апликацијата.

    ## 10. Контакт

    [Име и презиме], [Адреса, град], Северна Македонија · [е-пошта за поддршка]
    """#

    static let termsEN = #"""
    # Terms of Use

    Effective: October 28, 2026

    These terms apply to the Tripdrobe app offered by [Full name], [Address, city], North Macedonia (“we”). By creating an account or using the app you agree to them and to the Privacy Policy.

    ## 1. Who can use it

    You must be at least 13 years old. If you are under the age of majority where you live, you need a parent's permission. Your account is personal and you are responsible for access to it.

    ## 2. What Tripdrobe offers

    Packing lists, forecasts, baggage rules, a wardrobe, outfits and shared trips. Forecasts, airline baggage rules and packing suggestions are for information only and may change or be inaccurate. Always check your airline's rules before you travel. We are not responsible for baggage fees, forgotten items or decisions made based on the forecast.

    ## 3. Premium

    You can create as many trips with a packing list as you like for free. Premium (forecast, airlines and baggage, wardrobe and outfits, friends, Story, “Before you leave” and themes) is bought through the App Store as a monthly or yearly subscription. The price, the billing period and any trial terms are shown before you pay.

    - **Subscriptions renew automatically** and are charged to your Apple ID at the end of each period until you cancel at least 24 hours before the end of the current period.
    - **Free trial:** if offered, the first period is charged when the trial ends unless you cancel at least 24 hours before. A trial is offered once per Apple ID.
    - **Cancel and manage:** iPhone Settings → your name → Subscriptions. After cancelling, Premium stays active until the end of the paid period.

    Payments, billing and refunds are handled by Apple under its own terms, so refund requests go to Apple. You can restore your purchase on a new device with “Restore purchase”. If we change a subscription price, Apple notifies you in advance and asks for consent where required.

    ## 4. Your content

    Your photos, lists and outfits are yours. You give us a limited permission to store and process them only to provide the app and to show them to members of trips you share.

    Upload only photos that you own or have the right to use, with no people in them. Illegal content, content that infringes others' rights, harassment and any content that sexualises children are prohibited. Invite only people who want to travel with you.

    ## 5. Copyright

    If you believe content in Tripdrobe infringes your copyright, write to [support email]. Describe the work, where it appears and how to reach you. If the notice is valid we remove the content, and we close accounts that repeatedly infringe. Destination photos come from Wikimedia Commons and are shown with their author and licence.

    ## 6. Ending

    You can delete your account anytime in Settings. We may suspend an account that breaks these terms.

    ## 7. Liability

    The app is provided “as is”. To the extent permitted by law, we are not liable for indirect damages. Nothing in these terms limits the rights you have as a consumer under the laws of your country.

    ## 8. Apple

    These terms are between you and us, not Apple. Apple is not responsible for the app, its content, maintenance or support. If the app fails to conform to any applicable warranty, you may notify Apple and Apple will refund the purchase price; Apple has no other warranty obligation. We, not Apple, are responsible for any claims relating to the app (product liability, legal or regulatory compliance, consumer protection, intellectual property). You confirm that you are not located in a country subject to a U.S. Government embargo and are not on any U.S. Government list of prohibited or restricted parties. Apple and its subsidiaries are third-party beneficiaries of these terms and may enforce them. The Apple Media Services Terms also apply.

    ## 9. Law and changes

    These terms are governed by the law of the Republic of North Macedonia, without limiting the mandatory consumer rights of your country. If we change the terms, we will let you know in the app.

    ## 10. Contact

    [Full name], [Address, city], North Macedonia · [support email]
    """#
}
