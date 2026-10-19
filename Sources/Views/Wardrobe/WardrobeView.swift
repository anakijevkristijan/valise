import SwiftUI

/// Таб „Гардероба“: парчиња и аутфити, по сезони.
struct WardrobeView: View {
    @EnvironmentObject private var wardrobe: WardrobeStore

    enum Pane: String { case pieces, outfits }

    @State private var section: Pane = .pieces
    @State private var season: Season?
    @State private var showAddItem = false
    @State private var editingItem: WardrobeItem?
    @State private var showNewOutfit = false
    @State private var editingOutfit: Outfit?

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        sectionPicker
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
    }

    // MARK: Заглавие

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("VALISE")
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
            }
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
                       text: L("Сликај ја јакната, фармерките, омилените чевли — секое парче станува стикер со кој составуваш аутфити.",
                               "Photograph your jacket, jeans, favourite shoes — each piece becomes a sticker you can style into outfits."),
                       action: L("Додај прво парче", "Add your first piece")) { showAddItem = true }
        } else {
            ForEach(WardrobeCategory.allCases) { category in
                let list = wardrobe.items(in: category, season: season)
                if !list.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Eyebrow(category.title)
                            Spacer()
                            Text("\(list.count)")
                                .font(.codes(14))
                                .foregroundStyle(Theme.muted)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 14) {
                            ForEach(list) { item in
                                let inOutfits = wardrobe.outfitCount(of: item.id)
                                WardrobeItemTile(item: item,
                                                 badge: inOutfits > 0 ? PieceText.inOutfits(inOutfits) : nil)
                                    .contextMenu {
                                        Button(L("Уреди", "Edit"), systemImage: "pencil") { editingItem = item }
                                        Button(L("Избриши", "Delete"), systemImage: "trash", role: .destructive) {
                                            withAnimation { wardrobe.delete(item.id) }
                                        }
                                    }
                                    .onTapGesture { editingItem = item }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Аутфити

    @ViewBuilder
    private var outfitsContent: some View {
        let list = wardrobe.outfits.filter { wardrobe.outfitFits($0, season) }.sorted { $0.createdAt > $1.createdAt }
        if wardrobe.outfits.isEmpty {
            emptyState(icon: "sparkles",
                       title: L("Состави аутфит", "Style an outfit"),
                       text: L("Избери парчиња од гардеробата и зачувај ги како аутфит — потоа планирај што носиш секој ден од патувањето.",
                               "Pick pieces from your wardrobe and save them as an outfit — then plan what you'll wear each day of your trip."),
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
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .toolbarBackground(Theme.paper, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .tabItem { Label(L("Патувања", "Trips"), systemImage: "airplane") }
                .tag(0)
            WardrobeView()
                .toolbarBackground(Theme.paper, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .tabItem { Label(L("Гардероба", "Wardrobe"), systemImage: "hanger") }
                .tag(1)
        }
        .tint(Theme.navy)
    }
}
