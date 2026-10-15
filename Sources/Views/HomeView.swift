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
                PaperBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
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
                    .padding(.top, 10)
                    .padding(.bottom, 130)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.horizontal)
                }
                .scrollIndicators(.hidden)
                .refreshable { await store.refreshAllUpcoming() }

                if !store.upcoming.isEmpty {
                    newTripBar
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                TripDetailView(tripID: id)
            }
        }
        .task { await store.refreshAllUpcoming() }
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
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                Text("VALISE")
                    .font(.sans(12, .semibold))
                    .tracking(4)
                    .foregroundStyle(Theme.navy)
                Spacer()
                Button { showSettings = true } label: {
                    Text(initial)
                        .font(.serif(16))
                        .foregroundStyle(Theme.navy)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().strokeBorder(Theme.navy.opacity(0.35), lineWidth: 0.75))
                }
                .buttonStyle(PressableStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(Fmt.weekdayLong(Date()))
                Text("\(greeting),\n\(firstName).")
                    .font(.serif(36))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(1)
            }
            .padding(.top, 8)

            if let next = store.upcoming.first {
                Text(subtitle(for: next))
                    .font(.sans(15))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.top, 4)
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
        case 5..<12: return L("Добро утро", "Good morning")
        case 12..<18: return L("Добар ден", "Good afternoon")
        default: return L("Добра вечер", "Good evening")
        }
    }

    private func subtitle(for trip: Trip) -> String {
        if trip.isOngoing { return L("Уживај во \(trip.destination.name).", "Enjoy \(trip.destination.name).") }
        if trip.daysUntil <= 3 {
            return L("\(trip.destination.name) е речиси тука. Време е за пакување.", "\(trip.destination.name) is almost here. Time to pack.")
        }
        return L("Твојата карта за \(trip.destination.name) е спремна.", "Your ticket to \(trip.destination.name) is ready.")
    }

    // MARK: Патувања

    @ViewBuilder
    private var upcomingSection: some View {
        let trips = store.upcoming
        if let first = trips.first {
            NavigationLink(value: first.id) {
                BoardingPassCard(trip: first)
            }
            .buttonStyle(PressableStyle())
            .contextMenu { deleteButton(first) }
        }

        if trips.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(L("Наскоро", "Coming up"))
                ForEach(trips.dropFirst()) { trip in
                    NavigationLink(value: trip.id) {
                        TicketRow(trip: trip)
                    }
                    .buttonStyle(PressableStyle())
                    .contextMenu { deleteButton(trip) }
                }
            }
        }
    }

    private var pastSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut) { showPast.toggle() }
            } label: {
                HStack {
                    Eyebrow(L("Минати патувања", "Past trips") + " · \(store.past.count)")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .rotationEffect(.degrees(showPast ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showPast {
                ForEach(store.past) { trip in
                    NavigationLink(value: trip.id) {
                        TicketRow(trip: trip)
                            .opacity(0.7)
                    }
                    .buttonStyle(PressableStyle())
                    .contextMenu { deleteButton(trip) }
                }
            }
        }
    }

    private func deleteButton(_ trip: Trip) -> some View {
        Button(L("Избриши патување", "Delete trip"), systemImage: "trash", role: .destructive) {
            withAnimation { store.delete(trip.id) }
        }
    }

    // MARK: Празна состојба

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 24) {
            ZStack {
                TicketHalf(side: .top)
                    .fill(Theme.navy.opacity(0.06))
                    .frame(height: 120)
                VStack(spacing: 10) {
                    Text("SKP  ✈︎  ???")
                        .font(.codes(30))
                        .foregroundStyle(Theme.navy.opacity(0.75))
                    Text(L("ТВОЈАТА СЛЕДНА КАРТА", "YOUR NEXT TICKET"))
                        .font(.sans(10, .semibold))
                        .tracking(2.4)
                        .foregroundStyle(Theme.gold)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L("Каде следно?", "Where to next?"))
                    .font(.serif(30))
                    .foregroundStyle(Theme.ink)
                Text(L("Кажи ми каде одиш и со што патуваш. Ќе ја подготвам листата, ќе го проверам времето и ќе пресметам дали сè собира.",
                       "Tell me where you're going and how. I'll prepare your list, check the weather and make sure everything fits."))
                    .font(.sans(15))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(3)
            }

            Button { showWizard = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text(L("Ново патување", "New trip"))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.top, 8)
    }

    private var newTripBar: some View {
        Button { showWizard = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text(L("Ново патување", "New trip"))
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .frame(maxWidth: 420)
        .padding(.horizontal, 32)
        .padding(.bottom, 14)
        .padding(.top, 30)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Theme.paper.opacity(0), Theme.paper.opacity(0.95), Theme.paper],
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
