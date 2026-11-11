import SwiftUI

// MARK: - Иконка

struct FamilyAvatar: View {
    let icon: String
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.42, weight: .light))
            .foregroundStyle(Theme.navy)
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.goldPale))
    }
}

// MARK: - Профил: „Моето семејство“

/// Децата и миленичињата - се внесуваат еднаш, а секое патување само избира кој оди.
struct FamilyProfileSection: View {
    @ObservedObject private var family = FamilyStore.shared
    @EnvironmentObject private var wardrobe: WardrobeStore
    @State private var adding: FamilyKind?
    @State private var editing: FamilyMember?

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !family.members.isEmpty {
                VStack(spacing: 0) {
                    ForEach(family.members) { member in
                        if member.id != family.members.first?.id {
                            Hairline().padding(.leading, 68)
                        }
                        row(member)
                    }
                }
                .luxCard(padding: 0, radius: 18)
            }

            HStack(spacing: 10) {
                addButton(.child)
                addButton(.pet)
            }

            Text(L("Секое дете и милениче добива своја листа во патувањата каде ќе го штиклираш, и своја гардероба со аутфити по денови.",
                   "Each child and pet gets their own list on the trips you tick them for, and their own wardrobe with outfits by day."))
                .font(.sans(12))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .sheet(item: $adding) { kind in
            FamilyMemberEditor(kind: kind, onSave: { family.save($0) })
                .presentationCornerRadius(28)
        }
        .sheet(item: $editing) { member in
            FamilyMemberEditor(kind: member.kind, existing: member,
                               onSave: { family.save($0) },
                               onDelete: { remove(member) },
                               deleteDetail: deleteDetail(member))
                .presentationCornerRadius(28)
        }
    }

    private func row(_ member: FamilyMember) -> some View {
        Button {
            editing = member
        } label: {
            HStack(spacing: 14) {
                FamilyAvatar(icon: member.icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(.serif(19))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(member.subtitle)
                        .font(.sans(12))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func addButton(_ kind: FamilyKind) -> some View {
        Button {
            adding = kind
        } label: {
            HStack(spacing: 8) {
                Image(systemName: kind == .child ? "figure.child" : "pawprint")
                    .font(.system(size: 13, weight: .regular))
                Text(kind == .child ? L("Додај дете", "Add a child") : L("Додај милениче", "Add a pet"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private func deleteDetail(_ member: FamilyMember) -> String {
        let count = wardrobe.items.filter { $0.ownerID == member.id }.count
        guard count > 0 else {
            return L("Патувањата остануваат какви што се.", "Your trips stay as they are.")
        }
        return L("Ќе се избришат и парчињата на \(member.name) во гардеробата (\(count)). Патувањата остануваат какви што се.",
                 "\(member.name)'s wardrobe pieces (\(count)) will be deleted too. Your trips stay as they are.")
    }

    private func remove(_ member: FamilyMember) {
        wardrobe.deleteAll(ownedBy: member.id)
        family.delete(member.id)
    }
}

// MARK: - Додај / уреди дете или милениче

struct FamilyMemberEditor: View {
    let kind: FamilyKind
    let existing: FamilyMember?
    let onSave: (FamilyMember) -> Void
    var onDelete: (() -> Void)?
    var deleteDetail: String?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var birthYear: Int
    @State private var birthMonth: Int
    @State private var petType: PetType
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool

    init(kind: FamilyKind, existing: FamilyMember? = nil, onSave: @escaping (FamilyMember) -> Void,
         onDelete: (() -> Void)? = nil, deleteDetail: String? = nil) {
        self.kind = kind
        self.existing = existing
        self.onSave = onSave
        self.onDelete = onDelete
        self.deleteDetail = deleteDetail
        let now = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: Date())
        _name = State(initialValue: existing?.name ?? "")
        _birthYear = State(initialValue: existing?.birthYear ?? ((now.year ?? 2026) - 3))
        _birthMonth = State(initialValue: existing?.birthMonth ?? (now.month ?? 1))
        _petType = State(initialValue: existing?.petType ?? .dog)
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var age: Int { FamilyText.age(birthYear: birthYear, birthMonth: birthMonth, on: Date()) }

    private var years: [Int] {
        let current = Calendar(identifier: .gregorian).component(.year, from: Date())
        var list = Array(((current - 17)...current).reversed())
        if !list.contains(birthYear) { list.append(birthYear) }
        return list
    }

    private var months: [String] {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        let symbols: [String] = formatter.standaloneMonthSymbols ?? []
        return symbols.map { $0.capitalized(with: AppLanguage.current.locale) }
    }

    private var monthName: String {
        let list = months
        return list.indices.contains(birthMonth - 1) ? list[birthMonth - 1] : "\(birthMonth)"
    }

    private var title: String {
        switch (kind, existing == nil) {
        case (.child, true): return L("Ново дете", "New child")
        case (.child, false): return L("Дете", "Child")
        case (.pet, true): return L("Ново милениче", "New pet")
        case (.pet, false): return L("Милениче", "Pet")
        }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Eyebrow(title, color: Theme.gold)
                        Spacer()
                        CircleIconButton(systemName: "xmark") { dismiss() }
                    }
                    nameField
                    if kind == .child { birthSection } else { petSection }
                    privacyNote
                    Button(action: save) {
                        Text(existing == nil ? L("Додај", "Add") : L("Зачувај", "Save"))
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(trimmed.isEmpty)
                    if existing != nil && onDelete != nil {
                        Button {
                            confirmDelete = true
                        } label: {
                            Text(L("Избриши", "Delete"))
                                .font(.sans(14, .medium))
                                .foregroundStyle(Theme.terracotta)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
                .containerRelativeFrame(.horizontal)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            if existing == nil { nameFocused = true }
        }
        .confirmationDialog(L("Да се избрише \(trimmed)?", "Delete \(trimmed)?"),
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L("Избриши", "Delete"), role: .destructive) {
                onDelete?()
                dismiss()
            }
            Button(L("Откажи", "Cancel"), role: .cancel) {}
        } message: {
            if let deleteDetail { Text(deleteDetail) }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(L("Име", "Name"))
            TextField("", text: $name,
                      prompt: Text(kind == .child ? L("пр. Ана", "e.g. Ana") : L("пр. Макс", "e.g. Max"))
                        .foregroundColor(Theme.muted.opacity(0.7)))
                .font(.serif(26))
                .foregroundStyle(Theme.ink)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($nameFocused)
            Hairline()
        }
    }

    private var birthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(L("Роден/а", "Born"))
            HStack(spacing: 10) {
                Menu {
                    Picker("", selection: $birthMonth) {
                        ForEach(Array(months.enumerated()), id: \.offset) { index, month in
                            Text(month).tag(index + 1)
                        }
                    }
                } label: {
                    pickerLabel(monthName)
                }
                Menu {
                    Picker("", selection: $birthYear) {
                        ForEach(years, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                } label: {
                    pickerLabel(String(birthYear))
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.gold)
                Text(ageLine)
                    .font(.sans(13, .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
            Text(L("Листата се прилагодува на возраста на денот кога патувате.",
                   "The list adapts to their age on the day you travel."))
                .font(.sans(12))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// „4 години · Предучилишно дете“
    private var ageLine: String {
        let text = FamilyText.age(age)
        let first = text.prefix(1).uppercased() + text.dropFirst()
        return first + " · " + AgeGroup(age: age).title
    }

    private func pickerLabel(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.serif(19))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .luxCard(padding: 0, radius: 14)
    }

    private var petSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(L("Вид", "Type"))
            HStack(spacing: 8) {
                ForEach(PetType.allCases) { type in
                    ChipButton(title: type.title, isSelected: petType == type, expand: true) {
                        withAnimation(.easeInOut(duration: 0.2)) { petType = type }
                    }
                }
            }
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock")
                .font(.system(size: 11))
                .padding(.top, 1)
            Text(L("Се чува само на твојот телефон и на твојот акаунт - сопатниците не го гледаат.",
                   "Kept only on your phone and in your account - travel companions can't see it."))
                .font(.sans(12))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.muted)
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        var member = existing ?? FamilyMember(kind: kind, name: trimmed)
        member.name = trimmed
        if kind == .child {
            member.birthYear = birthYear
            member.birthMonth = birthMonth
            member.petType = nil
        } else {
            member.petType = petType
            member.birthYear = nil
            member.birthMonth = nil
        }
        onSave(member)
        dismiss()
    }
}

// MARK: - Патување: кој оди

/// Во чекорот „Активности“: штиклирај кои деца и миленичиња патуваат.
struct FamilyTripPicker: View {
    @Binding var selection: [UUID]
    /// Тие што веќе се во патувањето, а ги нема во Профил (да може да се тргнат).
    var inTrip: [TripFamilyMember]

    @ObservedObject private var family = FamilyStore.shared
    @State private var adding: FamilyKind?

    init(selection: Binding<[UUID]>, inTrip: [TripFamilyMember] = []) {
        _selection = selection
        self.inTrip = inTrip
    }

    private struct Option: Identifiable {
        let id: UUID
        let name: String
        let icon: String
    }

    private var options: [Option] {
        var list = family.members.map { Option(id: $0.id, name: $0.name, icon: $0.icon) }
        for member in inTrip where !list.contains(where: { $0.id == member.id }) {
            list.append(Option(id: member.id, name: member.name, icon: member.icon))
        }
        return list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(L("Деца и миленичиња", "Kids and pets"))
            let list = options
            if list.isEmpty {
                Text(L("Патуваш со деца или милениче? Додај ги - секое добива своја листа.",
                       "Travelling with kids or a pet? Add them - each gets their own list."))
                    .font(.sans(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(list) { option in
                        chip(option)
                    }
                }
            }
            HStack(spacing: 18) {
                addLink(.child)
                addLink(.pet)
                Spacer()
            }
        }
        .sheet(item: $adding) { kind in
            FamilyMemberEditor(kind: kind, onSave: { member in
                FamilyStore.shared.save(member)
                if !selection.contains(member.id) { selection.append(member.id) }
            })
            .presentationCornerRadius(28)
        }
    }

    private func chip(_ option: Option) -> some View {
        let isOn = selection.contains(option.id)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isOn {
                    selection.removeAll { $0 == option.id }
                } else {
                    selection.append(option.id)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark" : option.icon)
                    .font(.system(size: 12, weight: isOn ? .bold : .regular))
                Text(option.name)
                    .font(.sans(13, isOn ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? Theme.goldLight : Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(isOn ? Theme.navy : Theme.surface))
            .overlay(Capsule().strokeBorder(isOn ? Theme.navy : Theme.hairline, lineWidth: 0.75))
        }
        .buttonStyle(PressableStyle())
    }

    private func addLink(_ kind: FamilyKind) -> some View {
        Button {
            adding = kind
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                Text(kind == .child ? L("Дете", "Child") : L("Милениче", "Pet"))
                    .font(.sans(13, .semibold))
            }
            .foregroundStyle(Theme.gold)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Патување: листите на децата и миленичињата

struct FamilyPackingSections: View {
    let trip: Trip
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var wardrobe: WardrobeStore
    @EnvironmentObject private var premium: PremiumStore
    @State private var addingFor: TripFamilyMember?
    @State private var sharing: TripFamilyMember?
    @State private var collapsed: Set<UUID> = []

    init(trip: Trip) {
        self.trip = trip
    }

    /// Моите се Premium; листа што некој ми ја споделил ја гледам секогаш.
    private var members: [TripFamilyMember] {
        (trip.family ?? []).filter { premium.isPremium || !$0.isMine }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(members) { member in
                FamilyListBlock(member: member,
                                pieces: pieces(of: member),
                                packedPieces: Set(trip.familyOutfitPacked?[member.id.uuidString] ?? []),
                                isCollapsed: collapsed.contains(member.id),
                                onCollapse: { toggleCollapse(member.id) },
                                onToggle: { toggle($0, of: member.id) },
                                onChange: { item, delta in changeQuantity(item, of: member.id, by: delta) },
                                onDelete: { remove($0, of: member.id) },
                                onAdd: { addingFor = member },
                                onTogglePiece: { togglePiece($0, of: member.id) },
                                onShare: shareAction(for: member))
            }
        }
        .sheet(item: $sharing) { member in
            FamilyShareSheet(trip: trip, member: member) { shares in
                mutateMember(member.id) { $0.shares = shares.isEmpty ? nil : shares }
            }
            .presentationCornerRadius(28)
        }
        .sheet(item: $addingFor) { member in
            AddItemSheet(initialCategory: .clothing, title: L("За \(member.name)", "For \(member.name)")) { item in
                add(item, to: member.id)
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(28)
        }
    }

    private func mutateMember(_ id: UUID, _ change: @escaping (inout TripFamilyMember) -> Void) {
        store.mutate(trip.id) { t in
            guard var family = t.family, let index = family.firstIndex(where: { $0.id == id }) else { return }
            change(&family[index])
            t.family = family
        }
    }

    /// Се споделува само листа на мое дете (не милениче, не листа што ми е споделена мене).
    private func shareAction(for member: TripFamilyMember) -> (() -> Void)? {
        guard member.isMine, member.kind == .child else { return nil }
        return { sharing = member }
    }

    /// Парчињата од аутфитите по денови на детето/миленичето (гардеробата е само кај мене).
    private func pieces(of member: TripFamilyMember) -> [WardrobeItem] {
        guard member.isMine else { return [] }
        return wardrobe.plannedItems(for: trip.projected(for: member.id)).map(\.item)
    }

    private func togglePiece(_ item: WardrobeItem, of member: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            store.mutate(trip.id) { $0.toggleOutfitPacked(item.id, person: member) }
        }
    }

    private func toggle(_ item: PackingItem, of member: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            mutateMember(member) { m in
                if let i = m.items.firstIndex(where: { $0.id == item.id }) { m.items[i].isPacked.toggle() }
            }
        }
    }

    private func changeQuantity(_ item: PackingItem, of member: UUID, by delta: Int) {
        mutateMember(member) { m in
            guard let i = m.items.firstIndex(where: { $0.id == item.id }) else { return }
            let value = max(1, m.items[i].quantity + delta)
            m.items[i].quantity = value
            m.items[i].wornCount = min(m.items[i].wornCount, value)
            m.items[i].quantityEdited = true
        }
    }

    private func remove(_ item: PackingItem, of member: UUID) {
        withAnimation {
            mutateMember(member) { m in
                m.items.removeAll { $0.id == item.id }
                if !item.isCustom {
                    var list = m.dismissed ?? []
                    list.append(item.identity)
                    m.dismissed = list
                }
            }
        }
    }

    private func add(_ item: PackingItem, to member: UUID) {
        mutateMember(member) { $0.items.append(item) }
    }

    private func toggleCollapse(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if collapsed.contains(id) {
                collapsed.remove(id)
            } else {
                collapsed.insert(id)
            }
        }
    }
}

/// Еден член: заглавие (име, возраст, спакувано) и листата.
private struct FamilyListBlock: View {
    let member: TripFamilyMember
    let pieces: [WardrobeItem]
    let packedPieces: Set<UUID>
    let isCollapsed: Bool
    let onCollapse: () -> Void
    let onToggle: (PackingItem) -> Void
    let onChange: (PackingItem, Int) -> Void
    let onDelete: (PackingItem) -> Void
    let onAdd: () -> Void
    let onTogglePiece: (WardrobeItem) -> Void
    /// nil = не може да се споделува (милениче, или листа што ми е споделена мене).
    let onShare: (() -> Void)?

    @EnvironmentObject private var wardrobe: WardrobeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if !isCollapsed {
                if !pieces.isEmpty { piecesCard }
                list
            }
        }
    }

    /// „4 години · го гледа и: Марко (Татко)“ / „4 години · споделено од Ана“
    private var subtitle: String {
        if !member.isMine, let owner = member.ownerName, !owner.isEmpty {
            return member.subtitle + " · " + L("споделено од \(owner)", "shared by \(owner)")
        }
        let names = (member.shares ?? []).map { $0.role == .other ? $0.name : "\($0.name) (\($0.role.title))" }
        guard !names.isEmpty else { return member.subtitle }
        return member.subtitle + " · " + L("ја гледа и: \(names.joined(separator: ", "))",
                                           "also sees it: \(names.joined(separator: ", "))")
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onCollapse) {
                HStack(spacing: 12) {
                    FamilyAvatar(icon: member.icon, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.name.uppercased())
                            .font(.sans(12, .semibold))
                            .tracking(2)
                            .foregroundStyle(Theme.navy)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.sans(11))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let onShare {
                Button(action: onShare) {
                    Image(systemName: member.isShared ? "person.2.fill" : "person.badge.plus")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(member.isShared ? Theme.goldLight : Theme.navy)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(member.isShared ? Theme.navy : Theme.surface))
                        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: member.isShared ? 0 : 0.75))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(L("Сподели листа", "Share list"))
            }

            Button(action: onCollapse) {
                HStack(spacing: 8) {
                    Text("\(member.packedCount)/\(member.items.count)")
                        .font(.codes(14))
                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Theme.muted)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 2)
    }

    /// Облеката од аутфитите по денови - се штиклира како и другото.
    private var piecesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "hanger")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(Theme.gold)
                Text(L("Од аутфитите", "From the outfits"))
                    .font(.sans(11, .semibold))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.navy)
                Spacer()
                Text("\(pieces.filter { packedPieces.contains($0.id) }.count)/\(pieces.count)")
                    .font(.codes(13))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 6)

            ForEach(pieces) { piece in
                pieceRow(piece, isPacked: packedPieces.contains(piece.id))
            }
        }
        .padding(.bottom, 6)
        .luxCard(padding: 0, fill: Theme.surface, radius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1)
        )
    }

    private func pieceRow(_ piece: WardrobeItem, isPacked: Bool) -> some View {
        Button {
            onTogglePiece(piece)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(isPacked ? Theme.navy : Color.clear)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(isPacked ? Theme.navy : Theme.muted.opacity(0.6), lineWidth: 1)
                    if isPacked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.goldLight)
                    }
                }
                .frame(width: 18, height: 18)

                pieceImage(piece)
                    .frame(width: 34, height: 34)
                    .opacity(isPacked ? 0.5 : 1)

                Text(piece.name)
                    .strikethrough(isPacked, color: Theme.muted.opacity(0.6))
                    .font(.sans(15))
                    .foregroundStyle(isPacked ? Theme.muted : Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func pieceImage(_ piece: WardrobeItem) -> some View {
        if let image = wardrobe.thumbnail(for: piece) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "hanger")
                .font(.system(size: 15, weight: .ultraLight))
                .foregroundStyle(Theme.muted)
        }
    }

    private var list: some View {
        let items = member.sortedItems
        return VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                PackingRow(item: item,
                           onToggle: { onToggle(item) },
                           onIncrease: { onChange(item, 1) },
                           onDecrease: { onChange(item, -1) },
                           onDelete: { onDelete(item) })
                if index < items.count - 1 {
                    Hairline().padding(.leading, 50)
                }
            }
            if !items.isEmpty { Hairline() }
            Button(action: onAdd) {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 18)
                    Text(L("Додај", "Add"))
                        .font(.sans(12, .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                    Spacer()
                }
                .foregroundStyle(Theme.gold)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .luxCard(padding: 0, radius: 16)
    }
}

// MARK: - Сподели ја листата на детето со избран сопатник

/// Листата на детето по правило ја гледам само јас. Тука се бира кој уште (мајка, татко или друг сопатник).
struct FamilyShareSheet: View {
    let trip: Trip
    let member: TripFamilyMember
    let onSave: ([FamilyShare]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var shares: [FamilyShare]

    init(trip: Trip, member: TripFamilyMember, onSave: @escaping ([FamilyShare]) -> Void) {
        self.trip = trip
        self.member = member
        self.onSave = onSave
        _shares = State(initialValue: member.shares ?? [])
    }

    /// Само сопатници со акаунт - без акаунт нема каде да ја видат.
    private var candidates: [Companion] { trip.travelers.filter(\.hasAccount) }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Eyebrow(L("Сподели листа", "Share list"), color: Theme.gold)
                        Spacer()
                        CircleIconButton(systemName: "xmark") { dismiss() }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(member.name)
                            .font(.serif(32))
                            .foregroundStyle(Theme.ink)
                        Text(L("Избери кој, освен тебе, ќе ја гледа и штиклира оваа листа. Никој друг од патувањето не ја гледа.",
                               "Choose who, besides you, can see and tick off this list. Nobody else on the trip sees it."))
                            .font(.sans(14))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if candidates.isEmpty {
                        emptyCard
                    } else {
                        VStack(spacing: 10) {
                            ForEach(candidates) { companion in
                                personCard(companion)
                            }
                        }

                        Button {
                            onSave(shares)
                            dismiss()
                        } label: {
                            Text(L("Зачувај", "Save"))
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock")
                            .font(.system(size: 12, weight: .light))
                            .padding(.top, 2)
                        Text(L("Се споделува само листата за пакување. Гардеробата и аутфитите остануваат само кај тебе.",
                               "Only the packing list is shared. The wardrobe and outfits stay with you."))
                            .font(.sans(12))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Theme.muted)
                }
                .padding(24)
                .containerRelativeFrame(.horizontal)
            }
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Нема со кого да се сподели", "Nobody to share with yet"))
                .font(.sans(15, .semibold))
                .foregroundStyle(Theme.ink)
            Text(L("Прво додај го другиот родител како сопатник во ова патување (Сопатници → Од контакти). Штом се приклучи со својот акаунт, ќе се појави тука.",
                   "First add the other parent as a travel companion on this trip (Travel companions → From contacts). Once they join with their account, they'll appear here."))
                .font(.sans(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .luxCard(padding: 18)
    }

    private func personCard(_ companion: Companion) -> some View {
        let uid = companion.uid ?? ""
        let share = shares.first { $0.uid == uid }
        return VStack(alignment: .leading, spacing: 14) {
            Button {
                toggle(companion)
            } label: {
                HStack(spacing: 12) {
                    Text(String(companion.firstName.prefix(1)).uppercased())
                        .font(.serif(15))
                        .foregroundStyle(Theme.goldLight)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.navy))
                    Text(companion.name)
                        .font(.sans(16, .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: share != nil ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(share != nil ? Theme.navy : Theme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let share {
                HStack(spacing: 8) {
                    ForEach(FamilyRole.allCases) { role in
                        ChipButton(title: role.title, isSelected: share.role == role) {
                            setRole(role, for: uid)
                        }
                    }
                }
            }
        }
        .luxCard(padding: 16)
    }

    private func toggle(_ companion: Companion) {
        guard let uid = companion.uid else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            if let index = shares.firstIndex(where: { $0.uid == uid }) {
                shares.remove(at: index)
            } else {
                shares.append(FamilyShare(uid: uid, name: companion.firstName, role: .other))
            }
        }
    }

    private func setRole(_ role: FamilyRole, for uid: String) {
        guard let index = shares.firstIndex(where: { $0.uid == uid }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { shares[index].role = role }
    }
}
