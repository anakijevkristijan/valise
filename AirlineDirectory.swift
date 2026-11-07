import Foundation

/// Уште авиокомпании, за да може секој лет да се најде. За нив немаме проверени мерки,
/// па добиваат типични правила според регионот и типот (види `Airlines.typical`).
/// Формат: IATA код | име | земја (ISO) | регион (eu, me, as, am, af, oc) | L = нискобуџетна
enum AirlineDirectory {
    static let data = """
    # ——— Кина, Хонг Конг, Макао ———
    9C|Spring Airlines|CN|as|L
    FM|Shanghai Airlines|CN|as|
    3U|Sichuan Airlines|CN|as|
    MF|Xiamen Airlines|CN|as|
    ZH|Shenzhen Airlines|CN|as|
    SC|Shandong Airlines|CN|as|
    TV|Tibet Airlines|CN|as|
    GJ|Loong Air|CN|as|
    8L|Lucky Air|CN|as|L
    PN|West Air|CN|as|L
    JD|Beijing Capital Airlines|CN|as|
    GS|Tianjin Airlines|CN|as|
    EU|Chengdu Airlines|CN|as|
    QW|Qingdao Airlines|CN|as|
    NS|Hebei Airlines|CN|as|
    KY|Kunming Airlines|CN|as|
    G5|China Express Airlines|CN|as|
    AQ|9 Air|CN|as|L
    UQ|Urumqi Air|CN|as|L
    FU|Fuzhou Airlines|CN|as|
    DR|Ruili Airlines|CN|as|
    JR|Joy Air|CN|as|
    GT|Air Guilin|CN|as|
    OQ|Chongqing Airlines|CN|as|
    RY|Jiangxi Air|CN|as|
    BK|Okay Airways|CN|as|
    KN|China United Airlines|CN|as|L
    DZ|Donghai Airlines|CN|as|
    GX|GX Airlines (Beibu Gulf)|CN|as|
    GY|Colorful Guizhou Airlines|CN|as|
    9D|Genghis Khan Airlines|CN|as|
    9H|Air Changan|CN|as|
    HX|Hong Kong Airlines|HK|as|
    HB|Greater Bay Airlines|HK|as|
    NX|Air Macau|MO|as|
    # ——— Јапонија, Кореја, Тајван, Монголија ———
    BC|Skymark Airlines|JP|as|
    ZG|ZIPAIR|JP|as|L
    GK|Jetstar Japan|JP|as|L
    IJ|Spring Japan|JP|as|L
    7G|StarFlyer|JP|as|
    6J|Solaseed Air|JP|as|
    HD|AIRDO|JP|as|
    JH|Fuji Dream Airlines|JP|as|
    NU|Japan Transocean Air|JP|as|
    FW|IBEX Airlines|JP|as|
    TW|T'way Air|KR|as|L
    LJ|Jin Air|KR|as|L
    BX|Air Busan|KR|as|L
    RS|Air Seoul|KR|as|L
    ZE|Eastar Jet|KR|as|L
    YP|Air Premia|KR|as|
    RF|Aero K|KR|as|L
    IT|Tigerair Taiwan|TW|as|L
    AE|Mandarin Airlines|TW|as|
    B7|UNI Air|TW|as|
    OM|MIAT Mongolian Airlines|MN|as|
    MR|Hunnu Air|MN|as|
    M0|Aero Mongolia|MN|as|
    # ——— Југоисточна Азија ———
    FD|Thai AirAsia|TH|as|L
    XJ|Thai AirAsia X|TH|as|L
    SL|Thai Lion Air|TH|as|L
    VZ|Thai Vietjet Air|TH|as|L
    PG|Bangkok Airways|TH|as|
    DD|Nok Air|TH|as|L
    D7|AirAsia X|MY|as|L
    FY|Firefly|MY|as|
    QZ|Indonesia AirAsia|ID|as|L
    Z2|Philippines AirAsia|PH|as|L
    QG|Citilink|ID|as|L
    ID|Batik Air Indonesia|ID|as|
    IU|Super Air Jet|ID|as|L
    IW|Wings Air|ID|as|
    SJ|Sriwijaya Air|ID|as|
    IN|NAM Air|ID|as|
    8B|TransNusa|ID|as|L
    6D|Pelita Air|ID|as|
    2P|PAL Express|PH|as|
    T6|AirSWIFT|PH|as|
    QH|Bamboo Airways|VN|as|
    VU|Vietravel Airlines|VN|as|
    K6|Air Cambodia|KH|as|
    QV|Lao Airlines|LA|as|
    8M|Myanmar Airways International|MM|as|
    UB|Myanmar National Airlines|MM|as|
    BI|Royal Brunei Airlines|BN|as|
    # ——— Јужна и Централна Азија ———
    QP|Akasa Air|IN|as|L
    9I|Alliance Air|IN|as|
    S5|Star Air|IN|as|
    IC|Fly91|IN|as|L
    PK|Pakistan International Airlines|PK|as|
    PA|Airblue|PK|as|
    ER|SereneAir|PK|as|
    PF|AirSial|PK|as|
    9P|Fly Jinnah|PK|as|L
    BG|Biman Bangladesh Airlines|BD|as|
    BS|US-Bangla Airlines|BD|as|
    VQ|NOVOAIR|BD|as|
    2A|Air Astra|BD|as|
    RA|Nepal Airlines|NP|as|
    U4|Buddha Air|NP|as|
    YT|Yeti Airlines|NP|as|
    H9|Himalaya Airlines|NP|as|
    N9|Shree Airlines|NP|as|
    8D|FitsAir|LK|as|
    Q2|Maldivian|MV|as|
    NR|Manta Air|MV|as|
    KB|Drukair – Royal Bhutan Airlines|BT|as|
    B3|Bhutan Airlines|BT|as|
    FG|Ariana Afghan Airlines|AF|as|
    RQ|Kam Air|AF|as|
    FS|FlyArystan|KZ|as|L
    DV|SCAT Airlines|KZ|as|
    IQ|Qazaq Air|KZ|as|
    HH|Qanot Sharq|UZ|as|
    C6|Centrum Air|UZ|as|
    SZ|Somon Air|TJ|as|
    7J|Tajik Air|TJ|as|
    ZM|Air Manas|KG|as|L
    YK|Avia Traffic Company|KG|as|
    T5|Turkmenistan Airlines|TM|as|
    # ——— Европа ———
    2L|Helvetic Airways|CH|eu|
    GM|Chair Airlines|CH|eu|
    4Y|Discover Airlines|DE|eu|
    X3|TUI fly Deutschland|DE|eu|
    DI|Marabu|DE|eu|
    SR|Sundair|DE|eu|
    VL|Lufthansa City Airlines|DE|eu|
    OR|TUI fly Netherlands|NL|eu|
    TB|TUI fly Belgium|BE|eu|
    TO|Transavia France|FR|eu|L
    SS|Corsair|FR|eu|
    TX|Air Caraïbes|FR|eu|
    BF|French bee|FR|eu|
    B0|La Compagnie|FR|eu|
    XK|Air Corsica|FR|eu|
    I2|Iberia Express|ES|eu|L
    YW|Air Nostrum|ES|eu|
    NT|Binter|ES|eu|
    PU|Plus Ultra|ES|eu|
    2W|World2fly|ES|eu|
    E9|Iberojet|ES|eu|
    S4|Azores Airlines|PT|eu|
    SP|SATA Air Açores|PT|eu|
    XZ|Aeroitalia|IT|eu|
    NO|Neos|IT|eu|
    BQ|SkyAlps|IT|eu|
    U8|TUS Airways|CY|eu|
    LM|Loganair|GB|eu|
    GR|Aurigny|GB|eu|
    SI|Blue Islands|GB|eu|
    N0|Norse Atlantic Airways|NO|eu|L
    WF|Widerøe|NO|eu|
    RC|Atlantic Airways|FO|eu|
    GL|Air Greenland|GL|eu|
    H4|HiSky|MD|eu|L
    A2|Animawings|RO|eu|
    XC|Corendon Airlines|TR|eu|L
    FH|Freebird Airlines|TR|eu|
    B2|Belavia|BY|eu|
    FV|Rossiya Airlines|RU|eu|
    S7|S7 Airlines|RU|eu|
    DP|Pobeda|RU|eu|L
    U6|Ural Airlines|RU|eu|
    UT|UTair|RU|eu|
    N4|Nordwind Airlines|RU|eu|
    WZ|Red Wings|RU|eu|
    A4|Azimuth|RU|eu|
    5N|Smartavia|RU|eu|
    R3|Yakutia Airlines|RU|eu|
    HZ|Aurora|RU|eu|
    # ——— Блиски Исток ———
    RX|Riyadh Air|SA|me|
    J9|Jazeera Airways|KW|me|L
    OV|SalamAir|OM|me|L
    3L|Air Arabia Abu Dhabi|AE|me|L
    IA|Iraqi Airways|IQ|me|
    IF|Fly Baghdad|IQ|me|
    IR|Iran Air|IR|me|
    W5|Mahan Air|IR|me|
    EP|Iran Aseman Airlines|IR|me|
    QB|Qeshm Air|IR|me|
    Y9|Kish Air|IR|me|
    RB|Syrian Air|SY|me|
    6Q|Cham Wings Airlines|SY|me|
    IY|Yemenia|YE|me|
    6H|Israir|IL|me|
    IZ|Arkia|IL|me|
    # ——— Африка ———
    BJ|Nouvelair|TN|af|
    3O|Air Arabia Maroc|MA|af|L
    E5|Air Arabia Egypt|EG|af|L
    SM|Air Cairo|EG|af|L
    NP|Nile Air|EG|af|
    FT|FlyEgypt|EG|af|L
    SF|Tassili Airlines|DZ|af|
    LN|Libyan Airlines|LY|af|
    8U|Afriqiyah Airways|LY|af|
    SD|Sudan Airways|SD|af|
    JM|Jambojet|KE|af|L
    UR|Uganda Airlines|UG|af|
    TC|Air Tanzania|TZ|af|
    PW|Precision Air|TZ|af|
    UM|Air Zimbabwe|ZW|af|
    FN|Fastjet|ZW|af|L
    BP|Air Botswana|BW|af|
    4Z|Airlink|ZA|af|
    5Z|CemAir|ZA|af|
    TM|LAM Mozambique Airlines|MZ|af|
    MK|Air Mauritius|MU|af|
    HM|Air Seychelles|SC|af|
    MD|Madagascar Airlines|MG|af|
    UU|Air Austral|RE|af|
    P4|Air Peace|NG|af|
    W3|Arik Air|NG|af|
    QI|Ibom Air|NG|af|
    OF|Overland Airways|NG|af|
    Q9|Green Africa|NG|af|L
    AW|Africa World Airlines|GH|af|
    HF|Air Côte d'Ivoire|CI|af|
    KP|ASKY Airlines|TG|af|
    HC|Air Sénégal|SN|af|
    2J|Air Burkina|BF|af|
    L6|Mauritania Airlines|MR|af|
    QC|Camair-Co|CM|af|
    DT|TAAG Angola Airlines|AO|af|
    8Z|Congo Airways|CD|af|
    P0|Proflight Zambia|ZM|af|
    ZN|Zambia Airways|ZM|af|
    QM|Malawi Airlines|MW|af|
    VR|Cabo Verde Airlines|CV|af|
    # ——— Америка ———
    G4|Allegiant Air|US|am|L
    SY|Sun Country Airlines|US|am|L
    MX|Breeze Airways|US|am|L
    XP|Avelo Airlines|US|am|L
    LF|Contour Airlines|US|am|
    9K|Cape Air|US|am|
    9X|Southern Airways Express|US|am|
    XE|JSX|US|am|
    TS|Air Transat|CA|am|
    F8|Flair Airlines|CA|am|L
    4N|Air North|CA|am|
    PB|PAL Airlines|CA|am|
    MO|Calm Air|CA|am|
    5T|Canadian North|CA|am|
    3H|Air Inuit|CA|am|
    UP|Bahamasair|BS|am|
    KX|Cayman Airways|KY|am|
    JY|interCaribbean Airways|TC|am|
    WM|Winair|SX|am|
    DM|Arajet|DO|am|L
    CU|Cubana|CU|am|
    3S|Air Antilles|GP|am|
    PY|Surinam Airways|SR|am|
    RZ|Sansa|CR|am|
    5U|TAG Airlines|GT|am|
    P5|Wingo|CO|am|L
    9R|SATENA|CO|am|
    FO|Flybondi|AR|am|L
    OY|Andes Líneas Aéreas|AR|am|
    OB|Boliviana de Aviación|BO|am|
    2I|Star Perú|PE|am|
    ZP|Paranair|PY|am|
    V0|Conviasa|VE|am|
    9V|Avior Airlines|VE|am|
    QL|LASER Airlines|VE|am|
    5R|Rutaca|VE|am|
    7M|MAP Linhas Aéreas|BR|am|
    # ——— Австралија и Океанија ———
    ZL|Rex Airlines|AU|oc|
    TL|Airnorth|AU|oc|
    S8|Sounds Air|NZ|oc|
    3C|Air Chathams|NZ|oc|
    PX|Air Niugini|PG|oc|
    CG|PNG Air|PG|oc|
    IE|Solomon Airlines|SB|oc|
    SB|Aircalin|NC|oc|
    TN|Air Tahiti Nui|PF|oc|
    VT|Air Tahiti|PF|oc|
    ON|Nauru Airlines|NR|oc|
    OL|Samoa Airways|WS|oc|
    GZ|Air Rarotonga|CK|oc|
    """
}
