import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: TripStore
    @AppStorage("userName") private var userName: String = ""

    @State private var path: [UUID] = []
    @State private var showWizard = false
    @State private var showSettings = false
    @State private var pendingTripID: UUID?
    @State private var showPast = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                LuxBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        header

                        if store.upcoming.isEmpty {
                            emptyState
                        } else {
                            upcomingSection
                        }

                        if !store.past.isEmpty {
                            pastSection
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 130)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)

                if !store.upcoming.isEmpty {
                    newTripBar
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                TripDetailView(tripID: id)
            }
        }
        .fullScreenCover(isPresented: $showWizard, onDismiss: openPendingTrip) {
            TripWizardView { newID in
                pendingTripID = newID
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
        }
    }

    // MARK: Заглавие

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Eyebrow(Fmt.weekdayLong(Date()))
                Spacer()
                Button { showSettings = true } label: {
                    Text(initial)
                        .font(.serif(17, .medium))
                        .foregroundStyle(Theme.goldDeep)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Theme.surface))
                        .overlay(Circle().strokeBorder(Theme.gold.opacity(0.5), lineWidth: 0.75))
                }
                .buttonStyle(PressableStyle())
            }

            Text("\(greeting),\n\(firstName).")
                .font(.serif(38))
                .foregroundStyle(Theme.ink)
                .lineSpacing(1)

            if let next = store.upcoming.first {
                Text(subtitle(for: next))
                    .font(.sans(15))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.top, 6)
    }

    private var firstName: String {
        userName.split(separator: " ").first.map(String.init) ?? userName
    }

    private var initial: String {
        firstName.first.map { String($0).uppercased() } ?? "V"
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Добро утро"
        case 12..<18: return "Добар ден"
        default: return "Добра вечер"
        }
    }

    private func subtitle(for trip: Trip) -> String {
        if trip.isOngoing { return "Уживај во \(trip.destination.name)." }
        if trip.daysUntil <= 3 { return "\(trip.destination.name) е речиси тука. Време е за пакување." }
        return "Следна станица: \(trip.destination.name)."
    }

    // MARK: Патувања

    @ViewBuilder
    private var upcomingSection: some View {
        let trips = store.upcoming
        if let first = trips.first {
            NavigationLink(value: first.id) {
                TripHeroCard(trip: first)
            }
            .buttonStyle(PressableStyle())
            .contextMenu { deleteButton(first) }
        }

        if trips.count > 1 {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow("Наскоро", color: Theme.muted)
                ForEach(trips.dropFirst()) { trip in
                    NavigationLink(value: trip.id) {
                        TripRowCard(trip: trip)
                    }
                    .buttonStyle(PressableStyle())
                    .contextMenu { deleteButton(trip) }
                }
            }
        }
    }

    private var pastSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeInOut) { showPast.toggle() }
            } label: {
                HStack {
                    Eyebrow("Минати патувања · \(store.past.count)", color: Theme.muted)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .rotationEffect(.degrees(showPast ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showPast {
                ForEach(store.past) { trip in
                    NavigationLink(value: trip.id) {
                        TripRowCard(trip: trip)
                            .opacity(0.75)
                    }
                    .buttonStyle(PressableStyle())
                    .contextMenu { deleteButton(trip) }
                }
            }
        }
    }

    private func deleteButton(_ trip: Trip) -> some View {
        Button("Избриши патување", systemImage: "trash", role: .destructive) {
            withAnimation { store.delete(trip.id) }
        }
    }

    // MARK: Празна состојба

    private var emptyState: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(Theme.goldLight.opacity(0.55))
                    .frame(width: 148, height: 148)
                Circle()
                    .strokeBorder(Theme.gold.opacity(0.35), lineWidth: 0.75)
                    .frame(width: 186, height: 186)
                Image(systemName: "globe.europe.africa")
                    .font(.system(size: 54, weight: .ultraLight))
                    .foregroundStyle(Theme.goldDeep)
            }
            .padding(.top, 20)

            VStack(spacing: 10) {
                Text("Каде следно?")
                    .font(.serif(30))
                    .foregroundStyle(Theme.ink)
                Text("Кажи ми каде одиш и со што патуваш — јас ќе ја подготвам листата, ќе го проверам времето и ќе пресметам дали сè собира.")
                    .font(.sans(15))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }

            Button { showWizard = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Ново патување")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 6)
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 22)
        .luxCard(padding: 0, radius: 30)
    }

    private var newTripBar: some View {
        Button { showWizard = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("Ново патување")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .frame(maxWidth: 420)
        .padding(.horizontal, 32)
        .padding(.bottom, 14)
        .padding(.top, 30)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Theme.ivory.opacity(0), Theme.ivory.opacity(0.95), Theme.ivory],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
    }

    private func openPendingTrip() {
        guard let id = pendingTripID else { return }
        pendingTripID = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            path.append(id)
        }
    }
}

// MARK: - Голема картичка за следното патување

struct TripHeroCard: View {
    let trip: Trip

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(colors: [Theme.tint(trip.tint), Theme.surface],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Image(systemName: trip.transport.icon)
                .font(.system(size: 150, weight: .ultraLight))
                .foregroundStyle(Theme.gold.opacity(0.13))
                .rotationEffect(.degrees(trip.transport == .plane ? -18 : 0))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: 26, y: 18)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Eyebrow(trip.isOngoing ? "Во тек" : "Следно патување", color: Theme.goldDeep)
                    Spacer()
                    Pill(text: trip.countdownText, icon: "calendar")
                }

                Spacer(minLength: 30)

                Text(trip.destination.flag)
                    .font(.system(size: 26))
                    .padding(.bottom, 4)
                Text(trip.destination.name)
                    .font(.serif(44))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text("\(trip.destination.country) · \(Fmt.range(trip.startDate, trip.endDate))")
                    .font(.sans(15))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 4)

                Hairline()
                    .padding(.vertical, 18)

                HStack(alignment: .center, spacing: 18) {
                    stat(icon: trip.weather.first?.icon ?? "cloud.sun",
                         value: trip.weatherSummary.shortText ?? "—",
                         label: "Време")
                    stat(icon: trip.bag.kind.icon,
                         value: "\(Int((trip.fillRatio * 100).rounded()))%",
                         label: "Багаж")
                    Spacer()
                    VStack(spacing: 4) {
                        ProgressRing(progress: trip.progress, size: 56)
                        Text("спакувано")
                            .font(.sans(10, .medium))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            .padding(24)
        }
        .frame(minHeight: 330)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 0.75)
        )
        .shadow(color: Theme.ink.opacity(0.07), radius: 28, x: 0, y: 16)
    }

    private func stat(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.goldDeep)
                Text(value)
                    .font(.serif(18, .medium))
                    .foregroundStyle(Theme.ink)
            }
            Text(label)
                .font(.sans(11, .medium))
                .foregroundStyle(Theme.muted)
        }
    }
}

// MARK: - Мала картичка

struct TripRowCard: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 16) {
            Text(trip.destination.flag)
                .font(.system(size: 24))
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.tint(trip.tint)))

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.destination.name)
                    .font(.serif(21))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("\(Fmt.range(trip.startDate, trip.endDate)) · \(trip.countdownText)")
                    .font(.sans(13))
                    .foregroundStyle(Theme.inkSoft)
            }

            Spacer()

            ProgressRing(progress: trip.progress, size: 42, lineWidth: 3)
        }
        .luxCard(padding: 16, radius: 22)
    }
}
