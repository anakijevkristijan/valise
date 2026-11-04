import SwiftUI

/// Старата облека што не можеше да се препознае од името: со еден допир — маица, џемпер, дуксер…
/// Подреденото парче исчезнува од листата; кога ќе се подреди сè, прозорецот сам се затвора.
struct SortWardrobeKindsView: View {
    @EnvironmentObject private var wardrobe: WardrobeStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let pending = wardrobe.itemsNeedingKind

        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Eyebrow(L("Подреди", "Sort"), color: Theme.gold)
                        Spacer()
                        CircleIconButton(systemName: "xmark") { dismiss() }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Што е секое парче?", "What is each piece?"))
                            .font(.serif(30))
                            .foregroundStyle(Theme.ink)
                        Text(L("Еден допир по парче — за листата да знае дали е маица, џемпер или дуксер, и да го брои на вистинското место.",
                               "One tap per piece — so the list knows if it's a T-shirt, a sweater or a hoodie, and counts it in the right place."))
                            .font(.sans(14))
                            .foregroundStyle(Theme.inkSoft)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if pending.isEmpty {
                        Label(L("Сè е подредено.", "All sorted."), systemImage: "checkmark.circle")
                            .font(.sans(15, .semibold))
                            .foregroundStyle(Theme.sage)
                    }

                    ForEach(pending) { item in
                        row(item)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
                .padding(24)
                .containerRelativeFrame(.horizontal)
            }
            .scrollIndicators(.hidden)
        }
        .onChange(of: pending.isEmpty) { _, done in
            if done {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { dismiss() }
            }
        }
    }

    private func row(_ item: WardrobeItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if let image = wardrobe.thumbnail(for: item) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "hanger")
                        .font(.system(size: 20, weight: .ultraLight))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(width: 64, height: 72)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.stone.opacity(0.6)))

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.sans(15, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(item.category.title)
                        .font(.sans(11))
                        .foregroundStyle(Theme.muted)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 6)], spacing: 6) {
                    ForEach(WardrobeKind.kinds(in: item.category)) { kind in
                        KindChip(title: kind.title, isSelected: false) {
                            assign(kind, to: item)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75))
    }

    private func assign(_ kind: WardrobeKind, to item: WardrobeItem) {
        var updated = item
        updated.kind = kind
        updated.category = kind.category
        withAnimation(.easeInOut(duration: 0.25)) {
            wardrobe.update(updated)
        }
    }
}
