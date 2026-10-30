import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var premium: PremiumStore
    @EnvironmentObject private var account: AccountService
    @AppStorage("userName") private var userName: String = ""

    @State private var path: [UUID] = []
    @State private var showWizard = false
    @State private var showSettings = false
    @State private var pendingTripID: UUID?
    @AppStorage("homeFilter") private var filter: PassFilter = .upcoming

    enum PassFilter: String, CaseIterable {
        case upcoming, past, all

        var title: String {
            switch self {
            case .upcoming: return L("Претстојни", "Upcoming")
            case .past: return L("Поминати", "Past")
            case .all: return L("Сите", "All")
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                PaperBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        header

                        if store.trips.isEmpty {
                            emptyState
                        } else {
                            passesSection
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 50)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.horizontal)
                }
                .scrollIndicators(.hidden)
                .refreshable { await store.refreshAllUpcoming() }
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
            .environmentObject(premium)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
                .environmentObject(premium)
                .environmentObject(account)
        }
    }

    // MARK: Заглавие

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                Text("TRIPDROBE")
                    .font(.sans(12, .semibold))
                    .tracking(4)
                    .foregroundStyle(Theme.navy)
                Spacer()
                if !store.trips.isEmpty {
                    Button { showWizard = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Theme.goldLight)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Theme.navy))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(L("Ново патување", "New trip"))
                }
                Button { showSettings = true } label: {
                    Text(initial)
                        .font(.serif(16))
                        .foregroundStyle(Theme.navy)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().strokeBorder(Theme.navy.opacity(0.35), lineWidth: 0.75))
                }
                .accessibilityLabel(L("Профил и поставки", "Profile and settings"))
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

    // MARK: Патувања — пасови во мрежа

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 230), spacing: 14)]

    /// Филтер горе (Претстојни · Поминати · Сите), а „Ново патување“ секогаш е првата картичка.
    private var passesSection: some View {
        let shown: [Trip] = {
            switch filter {
            case .upcoming: return store.upcoming
            case .past: return store.past
            case .all: return store.upcoming + store.past
            }
        }()

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 18) {
                ForEach(PassFilter.allCases, id: \.self) { option in
                    filterTab(option)
                }
                Spacer()
            }
            .overlay(alignment: .bottom) { Hairline() }

            LazyVGrid(columns: columns, spacing: 14) {
                if filter != .past {
                    Button { showWizard = true } label: {
                        NewPassTile()
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(L("Ново патување", "New trip"))
                }
                ForEach(shown) { trip in
                    NavigationLink(value: trip.id) {
                        PassTile(trip: trip, dimmed: trip.isPast)
                    }
                    .buttonStyle(PressableStyle())
                    .contextMenu { deleteButton(trip) }
                }
            }

            if shown.isEmpty && filter == .past {
                Text(L("Сè уште нема поминати патувања.", "No past trips yet."))
                    .font(.sans(14))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func filterTab(_ option: PassFilter) -> some View {
        let count: Int = {
            switch option {
            case .upcoming: return store.upcoming.count
            case .past: return store.past.count
            case .all: return store.trips.count
            }
        }()
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { filter = option }
        } label: {
            HStack(spacing: 5) {
                Text(option.title.uppercased())
                    .font(.sans(12, .semibold))
                    .tracking(1.4)
                Text("\(count)")
                    .font(.codes(14))
                    .opacity(0.6)
            }
            .foregroundStyle(filter == option ? Theme.navy : Theme.muted)
            .padding(.bottom, 11)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(filter == option ? Theme.navy : Color.clear)
                    .frame(height: 1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    private func openPendingTrip() {
        guard let id = pendingTripID else { return }
        pendingTripID = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            path.append(id)
        }
    }
}
