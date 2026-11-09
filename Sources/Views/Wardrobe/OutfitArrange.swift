import SwiftUI

// MARK: - Рачно местење на парчињата во аутфитот (Premium)

/// Влечи за да преместиш, спои два прста за големина и вртење, „Напред“ / „Назад“ за слоевите.
/// Распоредот е во делови од колажот (0…1), па изгледа исто на картичката, во патувањето и тука.
struct OutfitArrangeView: View {
    let items: [WardrobeItem]
    /// nil = назад на автоматскиот распоред.
    let onDone: ([String: PieceLayout]?) -> Void

    @EnvironmentObject private var wardrobe: WardrobeStore
    @Environment(\.dismiss) private var dismiss

    @State private var pieces: [String: PieceLayout]
    @State private var selected: String?
    /// Движење што уште трае (се додава врз зачуваното).
    @State private var active: String?
    @State private var drag: CGSize = .zero
    @State private var scale: CGFloat = 1
    @State private var turn: Angle = .zero
    /// Големината на платното (за поместувањето во делови од колажот).
    @State private var canvasSize: CGSize = .zero

    init(items: [WardrobeItem], layout: [String: PieceLayout]?, onDone: @escaping ([String: PieceLayout]?) -> Void) {
        self.items = items
        self.onDone = onDone
        var start = OutfitCollage.autoLayout(items)
        for (key, value) in layout ?? [:] where start[key] != nil {
            start[key] = value
        }
        _pieces = State(initialValue: Self.ranked(start))
        _selected = State(initialValue: nil)
    }

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Eyebrow(L("Намести го аутфитот", "Arrange the outfit"), color: Theme.gold)
                    Spacer()
                    CircleIconButton(systemName: "xmark") { dismiss() }
                }
                Text(L("Влечи парче за да го преместиш. Со два прста го смалуваш, зголемуваш и вртиш.",
                       "Drag a piece to move it. Use two fingers to resize and rotate it."))
                    .font(.sans(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                canvas
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)

                toolbar

                Spacer(minLength: 0)

                Button {
                    onDone(nil)
                    dismiss()
                } label: {
                    Text(L("Врати автоматски", "Back to automatic"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    commitAll()
                    onDone(pieces)
                    dismiss()
                } label: {
                    Text(L("Готово", "Done"))
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(24)
        }
    }

    // MARK: Платно

    private var canvas: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { selected = nil }
                ForEach(items) { item in
                    pieceView(item, size: size)
                }
            }
            .frame(width: size.width, height: size.height)
            .simultaneousGesture(pinchAndTurn)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75))
    }

    @ViewBuilder
    private func pieceView(_ item: WardrobeItem, size: CGSize) -> some View {
        let key = item.id.uuidString
        if let base = pieces[key], let image = wardrobe.thumbnail(for: item) {
            let live = key == active ? Self.moved(base, drag: drag, scale: scale, turn: turn, in: size) : base
            let box = live.frame(in: size)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: box.width, height: box.height)
                .overlay(selectionOutline(key == selected))
                .shadow(color: Theme.navy.opacity(0.14), radius: 6, x: 0, y: 4)
                .rotationEffect(.degrees(live.r))
                .contentShape(Rectangle())
                .onTapGesture { selected = key }
                .gesture(moveGesture(key, size: size))
                .position(x: box.midX, y: box.midY)
                .zIndex(live.z)
        }
    }

    @ViewBuilder
    private func selectionOutline(_ isOn: Bool) -> some View {
        if isOn {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.gold, style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
        }
    }

    // MARK: Движења

    private func moveGesture(_ key: String, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                begin(key)
                if canvasSize != size { canvasSize = size }
                drag = value.translation
            }
            .onEnded { _ in
                guard active == key, let base = pieces[key] else { return }
                pieces[key] = Self.moved(base, drag: drag, scale: 1, turn: .zero, in: size)
                drag = .zero
            }
    }

    /// Два прста: големина и вртење на избраното парче.
    private var pinchAndTurn: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard let key = selected else { return }
                begin(key)
                scale = value.magnification
            }
            .onEnded { _ in
                guard let key = active, let base = pieces[key] else { return }
                pieces[key] = Self.moved(base, drag: .zero, scale: scale, turn: .zero, in: .zero)
                scale = 1
            }
            .simultaneously(with: RotateGesture()
                .onChanged { value in
                    guard let key = selected else { return }
                    begin(key)
                    turn = value.rotation
                }
                .onEnded { _ in
                    guard let key = active, let base = pieces[key] else { return }
                    pieces[key] = Self.moved(base, drag: .zero, scale: 1, turn: turn, in: .zero)
                    turn = .zero
                })
    }

    private func begin(_ key: String) {
        if active != key {
            commitAll()
            active = key
        }
        if selected != key { selected = key }
    }

    /// Недовршеното движење се запишува (пр. пред „Готово“ или друго парче).
    private func commitAll() {
        guard let key = active, let base = pieces[key] else { return }
        if drag != .zero || scale != 1 || turn != .zero {
            pieces[key] = Self.moved(base, drag: drag, scale: scale, turn: turn, in: canvasSize)
        }
        drag = .zero
        scale = 1
        turn = .zero
    }

    /// Ново место: поместено, зголемено/смалено (од центарот) и свртено.
    static func moved(_ base: PieceLayout, drag: CGSize, scale: CGFloat, turn: Angle, in size: CGSize) -> PieceLayout {
        var piece = base
        if size.width > 0, size.height > 0 {
            piece.x = min(max(base.x + Double(drag.width / size.width), 0), 1)
            piece.y = min(max(base.y + Double(drag.height / size.height), 0), 1)
        }
        let biggest = max(base.w, base.h, 0.01)
        let factor = min(max(Double(scale), 0.12 / biggest), 1.3 / biggest)
        piece.w = base.w * factor
        piece.h = base.h * factor
        piece.r = base.r + turn.degrees
        return piece
    }

    // MARK: Копчиња

    private var toolbar: some View {
        HStack(spacing: 6) {
            tool("minus.magnifyingglass", L("Помало", "Smaller")) { resize(0.88) }
            tool("plus.magnifyingglass", L("Поголемо", "Bigger")) { resize(1.12) }
            tool("rotate.right", L("Сврти", "Rotate")) { rotate(15) }
            tool("square.3.layers.3d.top.filled", L("Напред", "To front")) { layer(front: true) }
            tool("square.3.layers.3d.bottom.filled", L("Назад", "To back")) { layer(front: false) }
        }
        .disabled(selected == nil)
        .opacity(selected == nil ? 0.45 : 1)
    }

    private func tool(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .frame(height: 20)
                Text(title)
                    .font(.sans(10, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Theme.navy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .luxCard(padding: 0, radius: 14)
        }
        .buttonStyle(PressableStyle())
    }

    private func resize(_ factor: CGFloat) {
        commitAll()
        guard let key = selected, let base = pieces[key] else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            pieces[key] = Self.moved(base, drag: .zero, scale: factor, turn: .zero, in: .zero)
        }
    }

    private func rotate(_ degrees: Double) {
        commitAll()
        guard let key = selected, let base = pieces[key] else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            pieces[key] = Self.moved(base, drag: .zero, scale: 1, turn: .degrees(degrees), in: .zero)
        }
    }

    private func layer(front: Bool) {
        commitAll()
        guard let key = selected, var piece = pieces[key] else { return }
        let others = pieces.filter { $0.key != key }.map { $0.value.z }
        piece.z = front ? (others.max() ?? 0) + 1 : (others.min() ?? 0) - 1
        var updated = pieces
        updated[key] = piece
        pieces = Self.ranked(updated)
    }

    /// Слоевите повторно 0, 1, 2… (редот останува).
    private static func ranked(_ layout: [String: PieceLayout]) -> [String: PieceLayout] {
        let keys = layout.keys.sorted { a, b in
            let za = layout[a]?.z ?? 0
            let zb = layout[b]?.z ?? 0
            return za == zb ? a < b : za < zb
        }
        var result = layout
        for (rank, key) in keys.enumerated() {
            result[key]?.z = Double(rank)
        }
        return result
    }
}
