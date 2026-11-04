import SwiftUI

// MARK: - Колаж (стикерите наредени како flat lay)

struct OutfitCollage: View {
    let items: [WardrobeItem]
    @EnvironmentObject private var wardrobe: WardrobeStore

    /// Позиција (центар 0…1) и големина (дел од ширината) по вид и група.
    private static func slot(_ item: WardrobeItem) -> (x: CGFloat, y: CGFloat, size: CGFloat) {
        switch item.effectiveKind {
        case .skirt?: return (0.50, 0.68, 0.48)          // сукњата е долу, како панталоните
        case .swimwear?: return (0.50, 0.42, 0.44)
        case .sportswear?: return (0.50, 0.45, 0.56)
        default: break
        }
        switch item.category {
        case .outerwear: return (0.33, 0.33, 0.58)
        case .top: return (0.64, 0.30, 0.50)
        case .dress: return (0.50, 0.42, 0.66)
        case .bottom: return (0.50, 0.68, 0.52)
        case .shoes: return (0.76, 0.85, 0.32)
        case .active: return (0.50, 0.45, 0.50)
        case .bag: return (0.22, 0.80, 0.32)
        case .accessory: return (0.84, 0.13, 0.24)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let slot = Self.slot(item)
                    let sameBefore = items.prefix(index).filter { $0.category == item.category }.count
                    let nudge = CGFloat(sameBefore) * 0.08
                    let isPhoto = item.isPhoto ?? false
                    let size = side * slot.size * (isPhoto ? 0.82 : 1)
                    let tilt: Double = isPhoto ? (index % 2 == 0 ? -4 : 4) : (sameBefore == 0 ? 0 : (sameBefore % 2 == 0 ? -6 : 6))
                    if let image = wardrobe.thumbnail(for: item) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size, height: size)
                            .shadow(color: Theme.navy.opacity(0.14), radius: 6, x: 0, y: 4)
                            .rotationEffect(.degrees(tilt))
                            .position(x: geo.size.width * min(slot.x + nudge, 0.85),
                                      y: geo.size.height * min(slot.y + nudge * 0.5, 0.88))
                            // Маицата под џемперот, џемперот под јакната
                            .zIndex(item.layer)
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
                Text(PieceText.pieces(outfit.itemIDs.count))
                    .font(.sans(11))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 2)
        }
    }
}

/// „1 парче“, „5 парчиња“…
enum PieceText {
    static func pieces(_ n: Int) -> String {
        n == 1 ? L("1 парче", "1 piece") : L("\(n) парчиња", "\(n) pieces")
    }

    static func outfits(_ n: Int) -> String {
        n == 1 ? L("1 аутфит", "1 outfit") : L("\(n) аутфити", "\(n) outfits")
    }

    static func inOutfits(_ n: Int) -> String {
        n == 1 ? L("во 1 аутфит", "in 1 outfit") : L("во \(n) аутфити", "in \(n) outfits")
    }
}

// MARK: - Стикер-плочка

struct WardrobeItemTile: View {
    let item: WardrobeItem
    var isSelected: Bool = false
    /// Мал текст под името (пр. „веќе еднаш“).
    var badge: String? = nil
    var badgeIsWarning: Bool = false
    /// Број во аголот (пр. 2 → „2×“).
    var count: Int? = nil
    @EnvironmentObject private var wardrobe: WardrobeStore

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image = wardrobe.thumbnail(for: item) {
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
                .overlay(alignment: .topLeading) {
                    if let count, count > 0 {
                        Text("\(count)×")
                            .font(.sans(11, .bold))
                            .foregroundStyle(Theme.ticketText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(badgeIsWarning ? Theme.terracotta : Theme.gold))
                            .offset(x: 6, y: 6)
                    }
                }

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
                        .foregroundStyle(badgeIsWarning ? Theme.terracotta : Theme.gold)
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

// MARK: - Листата наспроти аутфитите

/// „Маици и топови 3/5 · Џемпер / дуксер 1/2 …“ — зелено кога е исполнето, црвено кога е над планираното.
struct TargetChips: View {
    let targets: [ClothingTarget]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(targets) { target in
                    let color = target.status == .over ? Theme.terracotta : (target.status == .exact ? Theme.sage : Theme.gold)
                    HStack(spacing: 4) {
                        Image(systemName: target.status == .over ? "exclamationmark.triangle.fill"
                              : (target.status == .exact ? "checkmark" : "hanger"))
                            .font(.system(size: 9, weight: .bold))
                        Text(target.label)
                            .font(.sans(11, .semibold))
                    }
                    .foregroundStyle(color)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(color.opacity(0.12)))
                }
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
    }
}

enum TargetText {
    /// „2 маици, 1 џемпер или дуксер“ — или nil ако сè е покриено.
    static func missing(_ targets: [ClothingTarget]) -> String? {
        let parts = targets.filter { $0.missing > 0 }.map { $0.countText($0.missing) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// „Горни дела 7/6“ — што е над планираното, или nil.
    static func over(_ targets: [ClothingTarget]) -> String? {
        let parts = targets.filter { $0.over > 0 }.map(\.label)
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

// MARK: - Мала порака што исчезнува

struct ToastBanner: View {
    let text: String
    var isWarning: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isWarning ? "arrow.2.squarepath" : "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .padding(.top, 1)
            Text(text)
                .font(.sans(13, .medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.ticketText)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isWarning ? Theme.terracotta : Theme.navy)
                .shadow(color: Theme.navy.opacity(0.25), radius: 14, x: 0, y: 8)
        )
        .padding(.horizontal, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Составувач на аутфит

struct OutfitBuilderView: View {
    let existing: Outfit?
    var startSeason: Season?
    /// Ако се составува за патување — брои колку пати е облечено секое парче.
    var trip: Trip?
    var onSave: (Outfit) -> Void = { _ in }

    @EnvironmentObject private var wardrobe: WardrobeStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selected: [UUID]
    @State private var season: Season?
    @State private var showAddItem = false
    @State private var toast: String?
    @State private var toastToken = 0

    /// Над ова — предупредување за еден аутфит.
    private let manyPieces = 7

    init(existing: Outfit? = nil, startSeason: Season? = nil, trip: Trip? = nil,
         onSave: @escaping (Outfit) -> Void = { _ in }) {
        self.existing = existing
        self.startSeason = startSeason
        self.trip = trip
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _selected = State(initialValue: existing?.itemIDs ?? [])
        _season = State(initialValue: existing == nil ? startSeason : nil)
    }

    private var selectedItems: [WardrobeItem] {
        selected.compactMap { wardrobe.item($0) }
    }

    var body: some View {
        ZStack(alignment: .top) {
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
                        .frame(maxWidth: 300)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75))
                        .overlay(alignment: .topLeading) {
                            Text(PieceText.pieces(selected.count))
                                .font(.sans(11, .semibold))
                                .foregroundStyle(selected.count > manyPieces ? Theme.ticketText : Theme.navy)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(selected.count > manyPieces ? Theme.terracotta : Theme.goldPale))
                                .padding(12)
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selected)

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(L("Име", "Name"))
                        TextField("", text: $name, prompt: Text(L("пр. Вечера во Рим", "e.g. Dinner in Rome")).foregroundColor(Theme.muted.opacity(0.7)))
                            .font(.serif(22))
                            .foregroundStyle(Theme.ink)
                        Hairline()
                    }

                    SeasonFilter(season: $season)

                    if trip != nil {
                        Text(L("Бројот во аголот = колку пати парчето е веќе облечено на ова патување.",
                               "The number in the corner = how many times you already wear the piece on this trip."))
                            .font(.sans(12))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

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
                                        let info = reuse(item)
                                        Button { toggle(item) } label: {
                                            WardrobeItemTile(item: item,
                                                             isSelected: selected.contains(item.id),
                                                             badge: info.label,
                                                             badgeIsWarning: trip != nil,
                                                             count: trip != nil ? info.count : nil)
                                        }
                                        .buttonStyle(PressableStyle())
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(24)
                .padding(.bottom, 8)
                .containerRelativeFrame(.horizontal)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) { bottomBar }

            if let toast {
                ToastBanner(text: toast)
                    .padding(.top, 12)
                    .zIndex(2)
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddWardrobeItemView()
                .environmentObject(wardrobe)
        }
    }

    // MARK: Долна лента: бројач + зачувај

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if selected.count > manyPieces {
                warningLine(L("\(selected.count) парчиња е многу за еден аутфит — дали ти треба сè?",
                              "\(selected.count) pieces is a lot for one outfit — do you need them all?"),
                            color: Theme.terracotta)
            }

            if let trip {
                let targets = wardrobe.targets(for: trip, extra: selected, excludingOutfit: existing?.id)
                if !targets.isEmpty {
                    TargetChips(targets: targets)
                    if let over = TargetText.over(targets) {
                        warningLine(L("Го надминуваш планираното во листата: \(over).",
                                      "You're over what the list planned: \(over)."),
                                    color: Theme.terracotta)
                    }
                    if let missing = TargetText.missing(targets) {
                        warningLine(L("Според листата уште ти требаат: \(missing).",
                                      "The list still needs: \(missing)."),
                                    color: Theme.gold)
                    }
                }
                let load = wardrobe.load(for: trip, extra: selected, excludingOutfit: existing?.id)
                let color = load.level == .over ? Theme.terracotta : (load.level == .tight ? Theme.gold : Theme.sage)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(L("Вкупно за патувањето:", "Whole trip:"))
                        .font(.sans(12))
                        .foregroundStyle(Theme.inkSoft)
                    Text(PieceText.pieces(load.pieces))
                        .font(.sans(12, .bold))
                        .foregroundStyle(Theme.ink)
                    if load.repeated > 0 {
                        Text("· " + L("\(load.repeated) повторени", "\(load.repeated) repeated"))
                            .font(.sans(12))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                    Text(load.headline)
                        .font(.sans(11, .semibold))
                        .foregroundStyle(color)
                }
                if load.level != .ok {
                    warningLine(load.advice, color: color)
                }
            }

            Button {
                save()
            } label: {
                Text(L("Зачувај аутфит", "Save outfit"))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selected.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            Theme.paper
                .opacity(0.97)
                .ignoresSafeArea()
                .overlay(alignment: .top) { Hairline() }
        )
    }

    private func warningLine(_ text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11, weight: .semibold))
                .padding(.top, 1)
            Text(text)
                .font(.sans(12, .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(color)
    }

    // MARK: Повторувања

    /// Колку пати е веќе облечено (на патувањето) или во колку аутфити е (во гардеробата).
    private func reuse(_ item: WardrobeItem) -> (count: Int, label: String?) {
        if let trip {
            let times = wardrobe.usage(of: item.id, in: trip, excludingOutfit: existing?.id)
            return (times, times > 0 ? RepeatText.badge(times) : nil)
        }
        let outfits = wardrobe.outfitCount(of: item.id, excluding: existing?.id)
        return (outfits, outfits > 0 ? PieceText.inOutfits(outfits) : nil)
    }

    private func toggle(_ item: WardrobeItem) {
        let adding = !selected.contains(item.id)
        withAnimation(.easeInOut(duration: 0.2)) {
            if let index = selected.firstIndex(of: item.id) {
                selected.remove(at: index)
            } else {
                selected.append(item.id)
            }
        }
        guard adding else { return }

        // Предупредување: аутфитите го надминуваат планираното во листата (пр. 7 маици, а планирани 6) —
        // само за редот каде што се брои ова парче (џемперот не ги полни маиците)
        if let trip,
           let target = wardrobe.targets(for: trip, extra: selected, excludingOutfit: existing?.id)
               .first(where: { item.packingKeys.contains($0.key) && $0.over > 0 }) {
            show(L("Го надминуваш планираното: \(target.label). Листата предвидува \(target.need).",
                   "Over the plan: \(target.label). The list planned \(target.need)."))
            return
        }

        let info = reuse(item)
        guard info.count > 0 else { return }
        if trip != nil {
            show(L("„\(item.name)“ — ова ти е веќе искористено \(RepeatText.times(info.count)) на патувањето.",
                   "“\(item.name)” — you already wear this \(RepeatText.times(info.count)) on this trip."))
        } else {
            show(L("„\(item.name)“ веќе го имаш \(PieceText.inOutfits(info.count)).",
                   "“\(item.name)” is already \(PieceText.inOutfits(info.count))."))
        }
    }

    private func show(_ text: String) {
        toastToken += 1
        let token = toastToken
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { toast = text }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            if token == toastToken {
                withAnimation(.easeOut(duration: 0.3)) { toast = nil }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var outfit = existing ?? Outfit(name: "", itemIDs: [])
        outfit.name = trimmed.isEmpty ? defaultName : trimmed
        outfit.itemIDs = selected
        wardrobe.save(outfit: outfit)
        onSave(outfit)
        dismiss()
    }

    private var defaultName: String {
        L("Аутфит \(wardrobe.outfits.count + 1)", "Outfit \(wardrobe.outfits.count + 1)")
    }
}
