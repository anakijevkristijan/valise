import SwiftUI

// MARK: - Колаж (стикерите наредени како flat lay)

struct OutfitCollage: View {
    let items: [WardrobeItem]
    @EnvironmentObject private var wardrobe: WardrobeStore

    /// Позиција (центар 0…1) и големина (дел од ширината) по категорија.
    private static func slot(_ category: WardrobeCategory) -> (x: CGFloat, y: CGFloat, size: CGFloat) {
        switch category {
        case .outerwear: return (0.33, 0.33, 0.58)
        case .top: return (0.64, 0.30, 0.50)
        case .dress: return (0.50, 0.42, 0.66)
        case .bottom: return (0.50, 0.68, 0.52)
        case .shoes: return (0.76, 0.85, 0.32)
        case .bag: return (0.22, 0.80, 0.32)
        case .accessory: return (0.84, 0.13, 0.24)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let slot = Self.slot(item.category)
                    let sameBefore = items.prefix(index).filter { $0.category == item.category }.count
                    let nudge = CGFloat(sameBefore) * 0.08
                    if let image = wardrobe.image(for: item) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: side * slot.size, height: side * slot.size)
                            .shadow(color: Theme.navy.opacity(0.14), radius: 6, x: 0, y: 4)
                            .rotationEffect(.degrees(sameBefore == 0 ? 0 : (sameBefore % 2 == 0 ? -6 : 6)))
                            .position(x: geo.size.width * min(slot.x + nudge, 0.85),
                                      y: geo.size.height * min(slot.y + nudge * 0.5, 0.88))
                    }
                }
                if items.isEmpty {
                    Image(systemName: "hanger")
                        .font(.system(size: side * 0.22, weight: .ultraLight))
                        .foregroundStyle(Theme.muted.opacity(0.5))
                }
            }
        }
    }
}

struct OutfitCard: View {
    let outfit: Outfit
    @EnvironmentObject private var wardrobe: WardrobeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            OutfitCollage(items: wardrobe.items(in: outfit))
                .aspectRatio(1, contentMode: .fit)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75))
            VStack(alignment: .leading, spacing: 2) {
                Text(outfit.name)
                    .font(.serif(16))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(L("\(outfit.itemIDs.count) парчиња", "\(outfit.itemIDs.count) pieces"))
                    .font(.sans(11))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Стикер-плочка

struct WardrobeItemTile: View {
    let item: WardrobeItem
    var isSelected: Bool = false
    var badge: String? = nil
    @EnvironmentObject private var wardrobe: WardrobeStore

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image = wardrobe.image(for: item) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .shadow(color: Theme.navy.opacity(0.14), radius: 6, x: 0, y: 4)
                    } else {
                        Image(systemName: "hanger")
                            .font(.system(size: 28, weight: .ultraLight))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .aspectRatio(0.9, contentMode: .fit)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isSelected ? Theme.navy : Theme.hairline, lineWidth: isSelected ? 2 : 0.75)
                )

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.goldLight)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.navy))
                        .offset(x: -6, y: 6)
                }
            }
            VStack(spacing: 2) {
                Text(item.name)
                    .font(.sans(12, .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if let badge {
                    Text(badge)
                        .font(.sans(10, .semibold))
                        .foregroundStyle(Theme.terracotta)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Сезони (филтер)

struct SeasonFilter: View {
    @Binding var season: Season?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ChipButton(title: L("Сите", "All"), isSelected: season == nil) { season = nil }
                ForEach(Season.allCases) { option in
                    Button {
                        season = option
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: option.icon)
                                .font(.system(size: 11))
                            Text(option.title)
                                .font(.sans(13, season == option ? .semibold : .medium))
                        }
                        .foregroundStyle(season == option ? Theme.goldLight : Theme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(season == option ? Theme.navy : Theme.surface))
                        .overlay(Capsule().strokeBorder(season == option ? Theme.navy : Theme.hairline, lineWidth: 0.75))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Составувач на аутфит

struct OutfitBuilderView: View {
    let existing: Outfit?
    var startSeason: Season?
    /// Ако се составува за ден од патување — покажи кое парче веќе е облечено.
    var trip: Trip?
    var dayKey: String?
    var onSave: (Outfit) -> Void = { _ in }

    @EnvironmentObject private var wardrobe: WardrobeStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selected: [UUID]
    @State private var season: Season?
    @State private var showAddItem = false

    init(existing: Outfit? = nil, startSeason: Season? = nil, trip: Trip? = nil, dayKey: String? = nil,
         onSave: @escaping (Outfit) -> Void = { _ in }) {
        self.existing = existing
        self.startSeason = startSeason
        self.trip = trip
        self.dayKey = dayKey
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _selected = State(initialValue: existing?.itemIDs ?? [])
        _season = State(initialValue: existing == nil ? startSeason : nil)
    }

    private var selectedItems: [WardrobeItem] {
        selected.compactMap { wardrobe.item($0) }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Eyebrow(existing == nil ? L("Нов аутфит", "New outfit") : L("Аутфит", "Outfit"), color: Theme.gold)
                        Spacer()
                        CircleIconButton(systemName: "xmark") { dismiss() }
                    }

                    OutfitCollage(items: selectedItems)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: 320)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selected)

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(L("Име", "Name"))
                        TextField("", text: $name, prompt: Text(L("пр. Вечера во Рим", "e.g. Dinner in Rome")).foregroundColor(Theme.muted.opacity(0.7)))
                            .font(.serif(22))
                            .foregroundStyle(Theme.ink)
                        Hairline()
                    }

                    SeasonFilter(season: $season)

                    if wardrobe.items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L("Гардеробата е празна. Прво додај неколку парчиња.", "Your wardrobe is empty. Add a few pieces first."))
                                .font(.sans(14))
                                .foregroundStyle(Theme.inkSoft)
                            Button { showAddItem = true } label: {
                                Label(L("Додај парче", "Add a piece"), systemImage: "plus").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }

                    ForEach(WardrobeCategory.allCases) { category in
                        let list = wardrobe.items(in: category, season: season)
                        if !list.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Eyebrow(category.title)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 12) {
                                    ForEach(list) { item in
                                        Button { toggle(item.id) } label: {
                                            WardrobeItemTile(item: item,
                                                             isSelected: selected.contains(item.id),
                                                             badge: wornBadge(item))
                                        }
                                        .buttonStyle(PressableStyle())
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        var outfit = existing ?? Outfit(name: "", itemIDs: [])
                        outfit.name = trimmed.isEmpty ? defaultName : trimmed
                        outfit.itemIDs = selected
                        wardrobe.save(outfit: outfit)
                        onSave(outfit)
                        dismiss()
                    } label: {
                        Text(L("Зачувај аутфит", "Save outfit"))
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selected.isEmpty)
                }
                .padding(24)
                .containerRelativeFrame(.horizontal)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showAddItem) {
            AddWardrobeItemView()
                .environmentObject(wardrobe)
        }
    }

    private func wornBadge(_ item: WardrobeItem) -> String? {
        guard let trip else { return nil }
        let times = wardrobe.usage(of: item.id, in: trip, excluding: dayKey)
        return times > 0 ? RepeatText.badge(times) : nil
    }

    private var defaultName: String {
        L("Аутфит \(wardrobe.outfits.count + 1)", "Outfit \(wardrobe.outfits.count + 1)")
    }

    private func toggle(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let index = selected.firstIndex(of: id) {
                selected.remove(at: index)
            } else {
                selected.append(id)
            }
        }
    }
}
