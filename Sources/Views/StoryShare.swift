import SwiftUI
import UIKit
import PhotosUI

/// Слика 9:16 за Instagram Story (360×640 pt → 1080×1920 px).
struct StoryCardView: View {
    let trip: Trip
    let photo: UIImage?
    /// Автор и лиценца на фотографијата (Wikimedia бара потпис).
    var credit: String? = nil

    private var foreground: Color { photo == nil ? Theme.navy : .white }

    private var eyebrow: String {
        trip.isOngoing ? L("Во моментов", "Right now") : L("Следна станица", "Next stop")
    }

    var body: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 360, height: 640)
                    .clipped()
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.35), location: 0),
                        .init(color: .black.opacity(0.0), location: 0.25),
                        .init(color: .black.opacity(0.05), location: 0.45),
                        .init(color: .black.opacity(0.6), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Theme.paper
                Text(trip.destinationCode)
                    .font(.codes(220))
                    .foregroundStyle(Theme.navy.opacity(0.05))
                    .offset(y: -120)
            }

            VStack(spacing: 0) {
                Text("TRIPDROBE")
                    .font(.sans(11, .semibold))
                    .tracking(5)
                    .foregroundStyle(foreground)
                    .padding(.top, 46)

                Spacer()

                VStack(spacing: 10) {
                    Text(eyebrow.uppercased())
                        .font(.sans(9, .semibold))
                        .tracking(3)
                        .foregroundStyle(foreground.opacity(0.9))
                    Text(trip.destination.name)
                        .font(.serif(46))
                        .foregroundStyle(foreground)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                    Rectangle()
                        .fill(foreground.opacity(0.8))
                        .frame(width: 28, height: 0.75)
                    Text(Fmt.range(trip.startDate, trip.endDate).uppercased())
                        .font(.sans(9, .medium))
                        .tracking(2.4)
                        .foregroundStyle(foreground)
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 24)

                BoardingPassCard(trip: trip, style: .story)
                    .padding(.horizontal, 22)
                    .padding(.bottom, credit == nil ? 40 : 24)

                if let credit {
                    Text(credit)
                        .font(.sans(6.5, .medium))
                        .foregroundStyle(foreground.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 12)
                }
            }
        }
        .frame(width: 360, height: 640)
        .clipped()
        .environment(\.colorScheme, .light)
    }
}

/// Дизајнирани позадини — секогаш има убав избор, и без фотографии.
struct StoryBackdrop: View {
    let kind: Int
    let trip: Trip

    var body: some View {
        ZStack {
            if kind == 0 {
                LinearGradient(colors: [Theme.ticket(trip.tint), Theme.ticket(trip.tint).opacity(0.82), Theme.navy],
                               startPoint: .top, endPoint: .bottom)
                MotifPattern(motif: Theme.current.motif == .none ? .sparkles : Theme.current.motif,
                             color: Theme.ticketText, opacity: 0.09, spacing: 54, size: 14)
            } else {
                LinearGradient(colors: [Theme.gold, Theme.navy], startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(trip.destinationCode)
                    .font(.codes(240))
                    .foregroundStyle(Color.white.opacity(0.08))
                    .offset(y: -120)
            }
        }
        .frame(width: 360, height: 640)
        .clipped()
    }
}

/// Избор на позадина за Story: фотографии од дестинацијата, дизајнирани позадини, своја слика или без слика.
struct StorySheet: View {
    let trip: Trip

    private enum Option: Hashable {
        case blank
        case imported
        case styled(Int)
        case remote(URL)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var remotes: [URL] = []
    @State private var selected: Option = .styled(0)
    @State private var userChose = false
    @State private var images: [URL: UIImage] = [:]
    @State private var credits: [URL: String] = [:]
    @State private var styledImages: [Int: UIImage] = [:]
    @State private var importedImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var rendered: UIImage?
    @State private var isLoadingList = true

    private var options: [Option] {
        var list: [Option] = []
        if importedImage != nil { list.append(.imported) }
        list += remotes.map { Option.remote($0) }
        list += [.styled(0), .styled(1), .blank]
        return list
    }

    private var currentPhoto: UIImage? {
        switch selected {
        case .blank: return nil
        case .imported: return importedImage
        case .styled(let kind): return styledImages[kind]
        case .remote(let url): return images[url]
        }
    }

    private var currentCredit: String? {
        if case .remote(let url) = selected {
            return credits[url] ?? L("Фото: Wikimedia Commons", "Photo: Wikimedia Commons")
        }
        return nil
    }

    private var placeholders: Int {
        isLoadingList ? max(0, PhotoService.storyTarget - remotes.count) : 0
    }

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 16) {
                HStack {
                    Eyebrow("Instagram Story", color: Theme.gold)
                    Spacer()
                    CircleIconButton(systemName: "xmark") { dismiss() }
                }

                GeometryReader { geo in
                    let scale = min(geo.size.width / 360, geo.size.height / 640)
                    StoryCardView(trip: trip, photo: currentPhoto, credit: currentCredit)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Theme.navy.opacity(0.16), radius: 24, x: 0, y: 12)
                        .scaleEffect(scale)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .animation(.easeInOut(duration: 0.3), value: selected)
                        .contentShape(Rectangle())
                        .onTapGesture { next() }
                }

                Text(hint)
                    .font(.sans(12))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)

                strip

                if let rendered {
                    let image = Image(uiImage: rendered)
                    ShareLink(item: image,
                              preview: SharePreview(trip.destination.name, image: image)) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .semibold))
                            Text(L("Сподели", "Share"))
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button {} label: {
                        HStack(spacing: 10) {
                            ProgressView().tint(Theme.goldLight)
                            Text(L("Сподели", "Share"))
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .task { await load() }
        .onChange(of: pickerItem) { _, item in
            Task { await importPhoto(item) }
        }
    }

    private var hint: String {
        let name = trip.destination.name
        if isLoadingList {
            return L("Барам фотографии од \(name)… \(remotes.count)/\(PhotoService.storyTarget)",
                     "Finding photos of \(name)… \(remotes.count)/\(PhotoService.storyTarget)")
        }
        if remotes.isEmpty {
            return L("Нема фотографии без луѓе за \(name) — избери позадина или „+“ за своја слика.",
                     "No people-free photos of \(name) — pick a backdrop or “+” for your own.")
        }
        return L("\(remotes.count) фотографии · допри ја сликата за следна", "\(remotes.count) photos · tap the image for the next one")
    }

    // MARK: Лента со избор

    private var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        thumbFrame(isSelected: false) {
                            VStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .light))
                                Text(L("Моја", "Mine"))
                                    .font(.sans(9, .semibold))
                                    .tracking(1)
                                    .textCase(.uppercase)
                            }
                            .foregroundStyle(Theme.navy)
                        }
                    }

                    ForEach(options, id: \.self) { option in
                        Button { choose(option) } label: {
                            thumbFrame(isSelected: option == selected) { thumbContent(option) }
                        }
                        .buttonStyle(PressableStyle())
                        .id(option)
                    }

                    // Места за фотографиите што уште се проверуваат — бројот не скока
                    ForEach(0..<placeholders, id: \.self) { _ in
                        thumbFrame(isSelected: false) {
                            ZStack {
                                Theme.stone.opacity(0.6)
                                ProgressView().controlSize(.mini).tint(Theme.muted)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selected) { _, value in
                withAnimation { proxy.scrollTo(value, anchor: .center) }
            }
        }
        .frame(height: 76)
    }

    private func thumbFrame<Content: View>(isSelected: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: 54, height: 72)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surface))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Theme.navy : Theme.hairline, lineWidth: isSelected ? 2 : 0.75)
            )
    }

    @ViewBuilder
    private func thumbContent(_ option: Option) -> some View {
        switch option {
        case .blank:
            ZStack {
                Theme.paper
                Text(trip.destinationCode)
                    .font(.codes(15))
                    .foregroundStyle(Theme.navy.opacity(0.6))
            }
        case .imported:
            if let importedImage {
                Image(uiImage: importedImage).resizable().scaledToFill()
            }
        case .styled(let kind):
            if let image = styledImages[kind] {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Theme.navy
            }
        case .remote(let url):
            if let image = images[url] {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Theme.stone
            }
        }
    }

    // MARK: Логика

    /// Дизајнираните позадини веднаш, па проверените фотографии (по 4 паралелно, до 8, секогаш истите).
    @MainActor
    private func load() async {
        for kind in 0..<2 {
            let renderer = ImageRenderer(content: StoryBackdrop(kind: kind, trip: trip))
            renderer.scale = 2
            styledImages[kind] = renderer.uiImage
        }
        render()

        _ = await PhotoService.verifiedPhotos(for: trip.destination) { url, image in
            guard !remotes.contains(url) else { return }
            images[url] = image
            credits[url] = PhotoService.credit(for: url)?.text
            remotes.append(url)
            if !userChose && importedImage == nil && remotes.count == 1 {
                selected = .remote(url)
                render()
            }
        }
        isLoadingList = false
    }

    @MainActor
    private func choose(_ option: Option) {
        userChose = true
        selected = option
        render()
    }

    @MainActor
    private func next() {
        let list = options
        guard list.count > 1, let index = list.firstIndex(of: selected) else { return }
        choose(list[(index + 1) % list.count])
    }

    @MainActor
    private func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let original = UIImage(data: data) else { return }
        importedImage = original.downscaled(maxSide: 1800)
        userChose = true
        selected = .imported
        render()
        pickerItem = nil
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: StoryCardView(trip: trip, photo: currentPhoto, credit: currentCredit))
        renderer.scale = 3
        rendered = renderer.uiImage
    }
}

extension UIImage {
    /// Намалена копија — за брзо рендерирање на Story.
    func downscaled(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return self }
        let ratio = maxSide / longest
        let target = CGSize(width: size.width * ratio, height: size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
