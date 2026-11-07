import SwiftUI

/// Таб „Гардероба“: парчиња и аутфити, по сезони.
struct WardrobeView: View {
    @EnvironmentObject private var wardrobe: WardrobeStore
    @EnvironmentObject private var account: AccountService
    @State private var showAccount = false

    enum Pane: String { case pieces, outfits }

    @State private var section: Pane = ScreenshotMode.screen == "looks" ? .outfits : .pieces
    @State private var season: Season?
    /// Филтер по група во „Парчиња“ - nil = сите.
    @State private var categoryFilter: WardrobeCategory?
    @State private var showAddItem = false
    @State private var editingItem: WardrobeItem?
    @State private var showNewOutfit = false
    @State private var editingOutfit: Outfit?
    @State private var showSortKinds = false

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        sectionPicker
                        if section == .pieces && !wardrobe.items.isEmpty {
                            categoryPicker
                        }
                        SeasonFilter(season: $season)
                        if section == .pieces { piecesContent } else { outfitsContent }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.horizontal)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showAccount) {
            AccountView(startWith: .signIn)
                .environmentObject(account)
        }
        .sheet(isPresented: $showAddItem) {
            AddWardrobeItemView()
                .environmentObject(wardrobe)
                .presentationCornerRadius(28)
        }
        .sheet(item: $editingItem) { item in
            EditWardrobeItemView(item: item)
                .environmentObject(wardrobe)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showNewOutfit) {
            OutfitBuilderView(startSeason: season)
                .environmentObject(wardrobe)
                .presentationCornerRadius(28)
        }
        .sheet(item: $editingOutfit) { outfit in
            OutfitBuilderView(existing: outfit)
                .environmentObject(wardrobe)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showSortKinds) {
            SortWardrobeKindsView()
                .environmentObject(wardrobe)
                .presentationCornerRadius(28)
        }
    }

    // MARK: Заглавие

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("TRIPDROBE")
                    .font(.sans(12, .semibold))
                    .tracking(4)
                    .foregroundStyle(Theme.navy)
                Spacer()
                Button {
                    if section == .pieces { showAddItem = true } else { showNewOutfit = true }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Theme.goldLight)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.navy))
                }
                .buttonStyle(PressableStyle())
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Гардероба", "Wardrobe"))
                    .font(.serif(36))
                    .foregroundStyle(Theme.ink)
                Text(L("\(wardrobe.items.count) парчиња · \(wardrobe.outfits.count) аутфити",
                       "\(wardrobe.items.count) pieces · \(wardrobe.outfits.count) outfits"))
                    .font(.sans(14))
                    .foregroundStyle(Theme.inkSoft)
                cloudStatus
                    .padding(.top, 4)
            }
        }
    }

    /// Каде се чува гардеробата.
    @ViewBuilder
    private var cloudStatus: some View {
        switch wardrobe.cloudState {
        case .off:
            Button {
                showAccount = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "iphone")
                        .font(.system(size: 11))
                    Text(L("Само на овој телефон · Најави се за да се чува на акаунтот",
                           "Only on this phone · Sign in to keep it in your account"))
                        .font(.sans(11, .medium))
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(Theme.terracotta)
            }
            .buttonStyle(.plain)
        case .syncing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini).tint(Theme.muted)
                Text(L("Се зачувува на акаунтот…", "Saving to your account…"))
                    .font(.sans(11, .medium))
            }
            .foregroundStyle(Theme.muted)
        case .synced:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.icloud")
                    .font(.system(size: 11))
                Text(L("Зачувано на твојот акаунт", "Saved to your account"))
                    .font(.sans(11, .medium))
            }
            .foregroundStyle(Theme.sage)
        case .failed:
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.icloud")
                    .font(.system(size: 11))
                Text(L("Не се зачувува на акаунтот - објави ги новите правила во Firebase (firestore.rules).",
                       "Not saving to your account - publish the new Firebase rules (firestore.rules)."))
                    .font(.sans(11, .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.terracotta)
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: 20) {
            tab(.pieces, L("Парчиња", "Pieces"))
            tab(.outfits, L("Аутфити", "Outfits"))
            Spacer()
        }
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func tab(_ value: Pane, _ title: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { section = value }
        } label: {
            Text(title.uppercased())
                .font(.sans(12, .semibold))
                .tracking(1.6)
                .foregroundStyle(section == value ? Theme.navy : Theme.muted)
                .padding(.bottom, 11)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(section == value ? Theme.navy : Color.clear)
                        .frame(height: 1.5)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: Парчиња

    @ViewBuilder
    private var piecesContent: some View {
        if wardrobe.items.isEmpty {
            emptyState(icon: "hanger",
                       title: L("Твојата гардероба", "Your wardrobe"),
                       text: L("Сликај ја јакната, фармерките, омилените чевли - секое парче станува стикер со кој составуваш аутфити.",
                               "Photograph your jacket, jeans, favourite shoes - each piece becomes a sticker you can style into outfits."),
                       action: L("Додај прво парче", "Add your first piece")) { showAddItem = true }
        } else {
            let pending = wardrobe.itemsNeedingKind.count
            if pending > 0 {
                sortKindsCard(pending)
            }
            let shown = WardrobeCategory.allCases.filter { categoryFilter == nil || $0 == categoryFilter }
            if shown.allSatisfy({ wardrobe.items(in: $0, season: season).isEmpty }) {
                Text(season == nil ? L("Нема парчиња во оваа група.", "No pieces in this group.")
                                   : L("Нема парчиња во оваа група за оваа сезона.", "No pieces in this group for this season."))
                    .font(.sans(14))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
            }
            ForEach(shown) { category in
                let list = wardrobe.items(in: category, season: season)
                if !list.isEmpty {
                    let groups = WardrobeKindGroup.groups(list)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Eyebrow(category.title)
                            Spacer()
                            Text("\(list.count)")
                                .font(.codes(14))
                                .foregroundStyle(Theme.muted)
                        }
                        // Подгрупи по вид: Маици · Топови · Џемпери · Дуксери…
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                if groups.count > 1 {
                                    HStack(spacing: 6) {
                                        Text(group.title)
                                            .font(.sans(12, .semibold))
                                            .foregroundStyle(group.id == "none" ? Theme.terracotta : Theme.inkSoft)
                                        Text("\(group.items.count)")
                                            .font(.codes(13))
                                            .foregroundStyle(Theme.muted)
                                    }
                                }
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 14) {
                                    ForEach(group.items) { item in
                                        itemTile(item)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Групи: Сите · Горни делови · Фустани и сукњи… (само групите што имаат парчиња).
    private var categoryPicker: some View {
        let present = WardrobeCategory.allCases.filter { category in
            category == categoryFilter || wardrobe.items.contains { $0.category == category }
        }
        return ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ChipButton(title: L("Сите", "All"), isSelected: categoryFilter == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) { categoryFilter = nil }
                }
                ForEach(present) { category in
                    let count = wardrobe.items.filter { $0.category == category }.count
                    ChipButton(title: "\(category.title) \(count)", isSelected: categoryFilter == category) {
                        withAnimation(.easeInOut(duration: 0.2)) { categoryFilter = category }
                    }
                }
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
    }

    private func itemTile(_ item: WardrobeItem) -> some View {
        let inOutfits = wardrobe.outfitCount(of: item.id)
        return WardrobeItemTile(item: item,
                                badge: inOutfits > 0 ? PieceText.inOutfits(inOutfits) : nil)
            .contextMenu {
                Button(L("Уреди", "Edit"), systemImage: "pencil") { editingItem = item }
                Button(L("Избриши", "Delete"), systemImage: "trash", role: .destructive) {
                    withAnimation { wardrobe.delete(item.id) }
                }
            }
            .onTapGesture { editingItem = item }
    }

    /// Стара облека без вид - со еден допир по парче, за листата да брои точно.
    private func sortKindsCard(_ count: Int) -> some View {
        Button { showSortKinds = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Theme.navy)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.goldPale))
                VStack(alignment: .leading, spacing: 3) {
                    Text(count == 1 ? L("1 парче без вид", "1 piece without a type")
                                    : L("\(count) парчиња без вид", "\(count) pieces without a type"))
                        .font(.sans(15, .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(L("Подреди ги - маица, џемпер, дуксер… за точна листа",
                           "Sort them - T-shirt, sweater, hoodie… for an accurate list"))
                        .font(.sans(12))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .luxCard(padding: 14, radius: 18)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Аутфити

    @ViewBuilder
    private var outfitsContent: some View {
        let list = wardrobe.outfits.filter { wardrobe.outfitFits($0, season) }.sorted { $0.createdAt > $1.createdAt }
        if wardrobe.outfits.isEmpty {
            emptyState(icon: "sparkles",
                       title: L("Состави аутфит", "Style an outfit"),
                       text: L("Избери парчиња од гардеробата и зачувај ги како аутфит - потоа планирај што носиш секој ден од патувањето.",
                               "Pick pieces from your wardrobe and save them as an outfit - then plan what you'll wear each day of your trip."),
                       action: L("Нов аутфит", "New outfit")) { showNewOutfit = true }
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 18) {
                ForEach(list) { outfit in
                    Button { editingOutfit = outfit } label: {
                        OutfitCard(outfit: outfit)
                    }
                    .buttonStyle(PressableStyle())
                    .contextMenu {
                        Button(L("Избриши", "Delete"), systemImage: "trash", role: .destructive) {
                            withAnimation { wardrobe.deleteOutfit(outfit.id) }
                        }
                    }
                }
            }
        }
    }

    private func emptyState(icon: String, title: String, text: String, action: String, perform: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(Theme.gold)
            Text(title)
                .font(.serif(26))
                .foregroundStyle(Theme.ink)
            Text(text)
                .font(.sans(15))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(3)
            Button(action: perform) {
                HStack(spacing: 10) {
                    Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                    Text(action)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 6)
        }
        .padding(.top, 8)
    }
}

/// Главни табови: Патувања и Гардероба.
struct MainTabView: View {
    @EnvironmentObject private var premium: PremiumStore
    @State private var tab = ScreenshotMode.tab
    @ObservedObject private var router = NotificationRouter.shared

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .modifier(TabBarLook())
                .tabItem { Label(L("Патувања", "Trips"), systemImage: "airplane") }
                .tag(0)
            Group {
                if premium.isPremium {
                    WardrobeView()
                } else {
                    PremiumGateView(icon: "hanger",
                                    title: L("Твојата гардероба,\nспремна за пат.", "Your wardrobe,\nready to travel."),
                                    detail: L("Фотографирај ја облеката, составувај аутфити и испланирај што ќе облечеш секој ден од патувањето. Листата сама брои колку парчиња ти требаат.",
                                              "Photograph your clothes, build outfits and plan what you'll wear each day of the trip. The list counts how many pieces you need."))
                }
            }
                .modifier(TabBarLook())
                .tabItem { Label(L("Гардероба", "Wardrobe"), systemImage: "hanger") }
                .tag(1)
        }
        .tint(Theme.navy)
        // Допир на потсетник → таб „Патувања“ (почетната го отвора патувањето)
        .onChange(of: router.showTrips) { _, _ in tab = 0 }
    }
}

/// На iOS 26+ таб-лентата е Liquid Glass (системска); на постарите - во бојата на хартијата.
struct TabBarLook: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
        } else {
            content
                .toolbarBackground(Theme.paper, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
        }
    }
}
