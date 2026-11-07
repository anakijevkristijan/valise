import Foundation
import UserNotifications
import Combine

/// Локални потсетници (без сервер): ги закажува самиот телефон, ништо не излегува од него.
/// - 3 дена пред тргнување (19:00): колку работи уште не се спакувани
/// - ден пред тргнување (19:00): што фали, или „сè е спакувано“
/// - на денот на тргнување (08:00): „Пред излез“ — шпорет, прозорци, клучеви (Premium)
/// - ден пред враќање (20:00): спакувај се за дома (патувања од 3+ дена)
/// Се закажуваат одново по секоја промена на патувањата, за бројките да се точни.
enum TripReminders {
    static let enabledKey = "remindersEnabled"
    static let askedKey = "remindersAsked"
    private static let prefix = "trip."

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Системското прашање за дозвола. Враќа дали е дозволено.
    @discardableResult
    static func requestPermission() async -> Bool {
        UserDefaults.standard.set(true, forKey: askedKey)
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        return granted
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Ги брише старите и ги закажува потсетниците за претстојните патувања.
    static func reschedule(trips: [Trip], premium: Bool) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        guard isEnabled, !ScreenshotMode.isOn else { return }
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        // iOS чува најмногу 64 закажани известувања — доволно за следните 15 патувања
        let upcoming = trips
            .filter { $0.endDate.startOfDay >= Date().startOfDay }
            .sorted { $0.startDate < $1.startDate }
            .prefix(15)
        for trip in upcoming {
            for request in requests(for: trip, premium: premium) {
                try? await center.add(request)
            }
        }
    }

    // MARK: Пораки

    private static func requests(for trip: Trip, premium: Bool) -> [UNNotificationRequest] {
        let place = trip.placeSummary
        let total = trip.myItems.count
        let left = max(0, total - trip.packedCount)
        let start = trip.startDate.startOfDay
        var result: [UNNotificationRequest] = []

        // 3 дена пред (само ако уште има што да се спакува)
        if left > 0, let date = time(start.adding(days: -3), hour: 19) {
            result.append(make(trip, "pack3", at: date,
                               title: L("\(place) за 3 дена", "\(place) in 3 days"),
                               body: L("Време е за пакување — на листата уште \(things(left)).",
                                       "Time to pack — \(thingsEN(left)) left on your list.")))
        }

        // Ден пред
        if let date = time(start.adding(days: -1), hour: 19) {
            let body: String
            if left == 0 {
                body = L("Сè е спакувано. Провери само документи и полнач.", "Everything's packed. Just check documents and charger.")
            } else if left == 1 {
                body = L("Уште 1 работа не е спакувана.", "1 thing still to pack.")
            } else {
                body = L("Уште \(left) работи не се спакувани.", "\(left) things still to pack.")
            }
            result.append(make(trip, "pack1", at: date,
                               title: L("Утре патуваш: \(place)", "Tomorrow: \(place)"),
                               body: body))
        }

        // На денот на тргнување — „Пред излез“ (Premium)
        if premium, let date = time(start, hour: 8) {
            result.append(make(trip, "exit", at: date,
                               title: L("Пред излез од дома", "Before you leave home"),
                               body: L("Шпорет, прозорци, полнач, клучеви — брза проверка пред \(place).",
                                       "Stove, windows, charger, keys — a quick check before \(place).")))
        }

        // Ден пред враќање
        if trip.dayCount >= 3, let date = time(trip.endDate.startOfDay.adding(days: -1), hour: 20) {
            result.append(make(trip, "home", at: date,
                               title: L("Утре се враќаш од \(place)", "Heading home from \(place) tomorrow"),
                               body: L("Спакувај се навреме — полначи, документи и облеката од шкафот.",
                                       "Pack in good time — chargers, documents and the clothes in the wardrobe.")))
        }
        return result
    }

    private static func make(_ trip: Trip, _ kind: String, at date: Date, title: String, body: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = trip.id.uuidString
        content.userInfo = ["tripID": trip.id.uuidString]
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        return UNNotificationRequest(identifier: "\(prefix)\(trip.id.uuidString).\(kind)", content: content, trigger: trigger)
    }

    /// Денот во дадениот час — само ако е во иднина.
    private static func time(_ day: Date, hour: Int) -> Date? {
        guard let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day),
              date > Date() else { return nil }
        return date
    }

    private static func things(_ n: Int) -> String {
        n == 1 ? "1 работа" : "\(n) работи"
    }

    private static func thingsEN(_ n: Int) -> String {
        n == 1 ? "1 thing" : "\(n) things"
    }
}

// MARK: - Допир на известувањето → го отвора патувањето

@MainActor
final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()

    /// Патувањето што треба да се отвори (го зема почетната).
    @Published var openTripID: UUID?
    /// Се зголемува при секој допир — табот се префрла на „Патувања“.
    @Published var showTrips = 0
    /// Дозволата за известувања (nil = уште непроверено).
    @Published private(set) var authorization: UNAuthorizationStatus?

    func refreshAuthorization() async {
        let status = await TripReminders.authorizationStatus()
        authorization = status
        // Дозволено → токен за известувањата од пријателите
        if status == .authorized || status == .provisional || status == .ephemeral {
            PushService.shared.registerWithApple()
        }
    }

    func open(_ id: UUID) {
        openTripID = id
        showTrips += 1
    }
}
