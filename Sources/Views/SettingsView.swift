import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @AppStorage(AppLanguage.storageKey) private var language: String = AppLanguage.mk.rawValue

    @State private var draftName = ""
    @State private var confirmReset = false

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Eyebrow(L("Профил", "Profile"), color: Theme.gold)
                        Spacer()
                        CircleIconButton(systemName: "xmark") { save(); dismiss() }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(L("Твоето име", "Your name"))
                        TextField("", text: $draftName)
                            .font(.serif(26))
                            .foregroundStyle(Theme.ink)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit(save)
                        Hairline()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(L("Јазик", "Language"))
                        HStack(spacing: 8) {
                            ForEach(AppLanguage.allCases) { lang in
                                ChipButton(title: lang.nativeName, isSelected: language == lang.rawValue, expand: true) {
                                    save()
                                    language = lang.rawValue
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        infoRow("suitcase", L("Патувања", "Trips"), "\(store.trips.count)")
                        Hairline()
                        infoRow("airplane", L("Авиокомпании во базата", "Airlines in the database"), "\(Airlines.all.count - 1)")
                        Hairline()
                        infoRow("clock", L("Мерки за багаж", "Baggage sizes"), Airlines.dataUpdated)
                        Hairline()
                        infoRow("cloud.sun", L("Прогноза", "Forecast"), "Open-Meteo")
                        Hairline()
                        infoRow("photo", L("Фотографии", "Photos"), "Wikimedia")
                    }
                    .luxCard(padding: 20)

                    Text(L("Мерките за багаж се информативни. Авиокомпаниите ги менуваат често — пред лет секогаш провери на нивниот сајт.",
                           "Baggage sizes are a guide. Airlines change them often — always check their website before you fly."))
                        .font(.sans(13))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Text(L("Избриши ги сите патувања", "Delete all trips"))
                            .foregroundStyle(Theme.terracotta)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Text("VALISE 1.3")
                        .font(.sans(10, .semibold))
                        .tracking(3)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
                .padding(24)
                .containerRelativeFrame(.horizontal)
            }
        }
        .onAppear { draftName = userName }
        .onDisappear(perform: save)
        .confirmationDialog(L("Да се избришат сите патувања?", "Delete all trips?"), isPresented: $confirmReset, titleVisibility: .visible) {
            Button(L("Избриши сè", "Delete everything"), role: .destructive) { store.deleteAll() }
        }
        .presentationCornerRadius(28)
    }

    private func save() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { userName = trimmed }
    }

    private func infoRow(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Theme.gold)
                .frame(width: 22)
            Text(title)
                .font(.sans(15))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(value)
                .font(.serif(15))
                .foregroundStyle(Theme.inkSoft)
        }
    }
}
