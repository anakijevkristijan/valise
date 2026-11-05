import SwiftUI
import UserNotifications

/// По најавата: телефонскиот број, за пријателите да те најдат од своите контакти.
/// Се чува само шифриран отпечаток. Може да се прескокне и да се внесе подоцна во Профил.
struct PhoneStepView: View {
    static let askedKey = "phoneAsked"

    @EnvironmentObject private var account: AccountService
    @AppStorage("userName") private var userName: String = ""
    @AppStorage(PhoneStepView.askedKey) private var asked: Bool = false

    /// Целиот број со кодот на земјата (+38970123456).
    @State private var phone = ""
    /// „Провери го бројот“ или „Овој број веќе е додаден во друг акаунт…“
    @State private var problem: String?
    @State private var saving = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("TRIPDROBE")
                        .font(.sans(12, .semibold))
                        .tracking(4)
                        .foregroundStyle(Theme.navy)
                        .padding(.top, 20)
                        .padding(.bottom, 40)

                    Eyebrow(L("Пријатели", "Friends"), color: Theme.gold)
                        .padding(.bottom, 12)

                    Text(L("Твојот\nтелефонски број", "Your\nphone number"))
                        .font(.serif(34))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(2)
                        .padding(.bottom, 14)

                    Text(L("Пријателите што те имаат во контакти ќе те најдат и ќе те додадат во патување — без кодови и линкови.",
                           "Friends who have you in their contacts can find you and add you to a trip — no codes, no links."))
                        .font(.sans(15))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 28)

                    VStack(alignment: .leading, spacing: 10) {
                        // Кодот на земјата е веќе внесен (според телефонот) — се допишува само бројот
                        PhoneNumberField(number: $phone, fontSize: 26)
                        Rectangle()
                            .fill(phone.isEmpty ? Theme.hairline : Theme.navy)
                            .frame(height: 1)
                        if let problem {
                            Text(problem)
                                .font(.sans(13, .medium))
                                .foregroundStyle(Theme.terracotta)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.bottom, 14)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.gold)
                            .padding(.top, 2)
                        Text(L("Не го чуваме самиот број — само шифриран отпечаток. Никој не може да го види.",
                               "We never store the number itself — only an encrypted fingerprint. No one can see it."))
                            .font(.sans(12))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 28)

                    Button(action: save) {
                        HStack(spacing: 10) {
                            if saving { ProgressView().tint(Theme.goldLight) }
                            Text(L("Продолжи", "Continue"))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(phone.trimmingCharacters(in: .whitespaces).isEmpty || saving)

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { asked = true }
                    } label: {
                        Text(L("Прескокни — ќе го внесам подоцна во Профил", "Skip — I'll add it later in Profile"))
                            .font(.sans(14, .medium))
                            .foregroundStyle(Theme.navy)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.horizontal)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }
            // Бројот од регистрацијата не можеше да се зачува (пр. веќе е во друг акаунт)
            if let pending = account.pendingPhoneProblem {
                phone = pending.number
                problem = pending.message
                account.pendingPhoneProblem = nil
            }
        }
        .onChange(of: phone) { _, _ in problem = nil }
    }

    private func save() {
        guard PhoneID.normalize(phone) != nil else {
            problem = L("Провери го бројот.", "Please check the number.")
            return
        }
        problem = nil
        saving = true
        Task { @MainActor in
            // Ист број не може во два акаунта
            if let failure = await account.updateProfile(name: userName, phone: phone) {
                saving = false
                withAnimation(.easeInOut(duration: 0.2)) { problem = failure }
                return
            }
            // Пријателите ќе те додаваат во патувања → прашај за известувања (еднаш)
            if await TripReminders.authorizationStatus() == .notDetermined {
                await TripReminders.requestPermission()
                await NotificationRouter.shared.refreshAuthorization()
            }
            saving = false
            withAnimation(.easeInOut(duration: 0.3)) { asked = true }
        }
    }
}
