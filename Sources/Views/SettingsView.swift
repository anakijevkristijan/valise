import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""

    @State private var draftName = ""
    @State private var confirmReset = false

    var body: some View {
        ZStack {
            Theme.ivory.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Eyebrow("Профил")
                        Spacer()
                        CircleIconButton(systemName: "xmark") { save(); dismiss() }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Твоето име")
                            .font(.sans(13, .medium))
                            .foregroundStyle(Theme.muted)
                        TextField("", text: $draftName)
                            .font(.serif(26))
                            .foregroundStyle(Theme.ink)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit(save)
                        Hairline()
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        infoRow("suitcase", "Патувања", "\(store.trips.count)")
                        Hairline()
                        infoRow("airplane", "Авиокомпании во базата", "\(Airlines.all.count - 1)")
                        Hairline()
                        infoRow("clock", "Мерки за багаж ажурирани", Airlines.dataUpdated)
                        Hairline()
                        infoRow("cloud.sun", "Временска прогноза", "Open-Meteo")
                    }
                    .luxCard(padding: 20)

                    Text("Мерките за багаж се информативни. Авиокомпаниите ги менуваат често — пред лет секогаш провери на нивниот сајт.")
                        .font(.sans(13))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Text("Избриши ги сите патувања")
                            .foregroundStyle(Theme.terracotta)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Text("Valise 1.0")
                        .font(.serif(14))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
                .padding(24)
            }
        }
        .onAppear { draftName = userName }
        .onDisappear(perform: save)
        .confirmationDialog("Да се избришат сите патувања?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Избриши сè", role: .destructive) { store.deleteAll() }
        }
        .presentationCornerRadius(30)
    }

    private func save() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { userName = trimmed }
    }

    private func infoRow(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.goldDeep)
                .frame(width: 24)
            Text(title)
                .font(.sans(15))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(value)
                .font(.serif(16))
                .foregroundStyle(Theme.inkSoft)
        }
    }
}
