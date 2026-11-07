import SwiftUI
import UserNotifications

/// Во патувањето, еднаш: „Да те потсетам?“ — дури тогаш системското прашање за известувања.
/// (Подобро отколку да се бара дозвола веднаш при отворање на апликацијата.)
struct ReminderOfferCard: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var premium: PremiumStore
    @AppStorage(TripReminders.askedKey) private var asked = false
    @ObservedObject private var router = NotificationRouter.shared

    var body: some View {
        if !asked && router.authorization == .notDetermined && !ScreenshotMode.isOn {
            card
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bell")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Theme.navy)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.goldPale))
                Text(L("Да те потсетам?", "Want a reminder?"))
                    .font(.sans(15, .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Text(L("3 дена и ден пред патувањето — колку работи уште не се спакувани. И кога пријател те додава во патување или те означува да понесеш нешто.",
                   "3 days and 1 day before the trip — how much is still left to pack. And when a friend adds you to a trip or asks you to bring something."))
                .font(.sans(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button {
                    Task { await allow() }
                } label: {
                    Text(L("Да, потсети ме", "Yes, remind me"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { asked = true }
                } label: {
                    Text(L("Не сега", "Not now"))
                        .font(.sans(13, .medium))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .luxCard(padding: 16, radius: 18)
    }

    private func allow() async {
        await TripReminders.requestPermission()
        await router.refreshAuthorization()
        withAnimation(.easeInOut(duration: 0.25)) { asked = true }
        await TripReminders.reschedule(trips: store.trips, premium: premium.isPremium)
    }
}
