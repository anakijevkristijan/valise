import SwiftUI

/// Една картичка за сè што е Premium во патувањето (наместо празни места).
struct PremiumTeaserCard: View {
    @EnvironmentObject private var premium: PremiumStore
    @State private var showPaywall = false

    var body: some View {
        Button { showPaywall = true } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("PREMIUM", systemImage: "lock.fill")
                        .font(.sans(10, .bold))
                        .tracking(1.6)
                        .foregroundStyle(Theme.goldLight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.navy))
                    Spacer()
                }
                Text(L("Отклучи го целото патување", "Unlock the whole trip"))
                    .font(.serif(22))
                    .foregroundStyle(Theme.ink)
                VStack(alignment: .leading, spacing: 9) {
                    row("cloud.sun", L("Прогноза и колку од секое парче да спакуваш", "Forecast and how many of each to pack"))
                    row("airplane", L("Авиокомпанија, багаж и дали ќе собере", "Airline, baggage and whether it fits"))
                    row("hanger", L("Аутфити од твојата гардероба", "Outfits from your own wardrobe"))
                    row("person.2", L("Пријатели и заедничка листа", "Friends and a shared list"))
                    row("camera.aperture", L("Story и „Пред излез“", "Story and “Before you leave”"))
                }
                Text(L("Пробај бесплатно →", "Try it free →"))
                    .font(.sans(14, .semibold))
                    .foregroundStyle(Theme.navy)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .luxCard(padding: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
        .sheet(isPresented: $showPaywall) {
            PremiumSheet().environmentObject(premium)
        }
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Theme.gold)
                .frame(width: 22)
            Text(text)
                .font(.sans(14))
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

/// Мал ред за заклучена можност (пр. во чекорите за ново патување).
struct PremiumLockRow: View {
    let icon: String
    let title: String
    let detail: String
    @EnvironmentObject private var premium: PremiumStore
    @State private var showPaywall = false

    var body: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.goldPale.opacity(0.7)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.sans(15, .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(.sans(12))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.navy)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .sheet(isPresented: $showPaywall) {
            PremiumSheet().environmentObject(premium)
        }
    }
}

/// Цел екран за заклучен таб (Гардероба).
struct PremiumGateView: View {
    let icon: String
    let title: String
    let detail: String
    @EnvironmentObject private var premium: PremiumStore
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .ultraLight))
                    .foregroundStyle(Theme.gold)
                Text(title)
                    .font(.serif(32))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.sans(15))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Button { showPaywall = true } label: {
                    Text(L("Отклучи со Premium", "Unlock with Premium"))
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
            }
            .padding(28)
            .frame(maxWidth: 560)
        }
        .sheet(isPresented: $showPaywall) {
            PremiumSheet().environmentObject(premium)
        }
    }
}
