import SwiftUI
import UIKit
import PhotosUI

/// Слика 9:16 за Instagram Story (360×640 pt → 1080×1920 px).
struct StoryCardView: View {
    let trip: Trip
    let photo: UIImage?

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
                Text("VALISE")
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
                    .padding(.bottom, 40)
            }
        }
        .frame(width: 360, height: 640)
        .clipped()
        .environment(\.colorScheme, .light)
    }
}

/// Избор на позадина за Story: фотографии од дестинацијата, своја слика или без слика.
struct StorySheet: View {
    let trip: Trip

    private enum Option: Hashable {
        case blank
        case imported
        case remote(URL)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var options: [Option] = [.blank]
    @State private var selected: Option = .blank
    @State private var images: [URL: UIImage] = [:]
    @State private var importedImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var rendered: UIImage?
    @State private var isLoadingList = true
    @State private var loadingURL: URL?

    private var currentPhoto: UIImage? {
        switch selected {
        case .blank: return nil
        case .imported: return importedImage
        case .remote(let url): return images[url]
        }
    }

    private var photoCount: Int { options.filter { $0 != .blank }.count }

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
                    ZStack {
                        StoryCardView(trip: trip, photo: currentPhoto)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: Theme.navy.opacity(0.16), radius: 24, x: 0, y: 12)
                            .scaleEffect(scale)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .animation(.easeInOut(duration: 0.3), value: selected)

                        if loadingURL != nil {
                            ProgressView()
                                .tint(.white)
                                .padding(14)
                                .background(Circle().fill(.black.opacity(0.35)))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { next() }
                }

                Text(hint)
                    .font(.sans(12))
                    .foregroundStyle(Theme.muted)

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
        .task { await loadOptions() }
        .onChange(of: pickerItem) { _, item in
            Task { await importPhoto(item) }
        }
    }

    private var hint: String {
        if isLoadingList { return L("Барам фотографии од \(trip.destination.name)…", "Finding photos of \(trip.destination.name)…") }
        if photoCount <= 1 { return L("Допри „+“ за своја слика", "Tap “+” to use your own photo") }
        return L("Допри ја сликата за следна · \(photoCount) фотографии", "Tap the image for the next one · \(photoCount) photos")
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
                        Button { select(option) } label: {
                            thumbFrame(isSelected: option == selected) { thumbContent(option) }
                        }
                        .buttonStyle(PressableStyle())
                        .id(option)
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
        case .remote(let url):
            if let image = images[url] {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Theme.stone
            }
        }
    }

    // MARK: Логика

    @MainActor
    /// Секоја фотографија прво се проверува (без луѓе) и дури потоа се појавува во лентата.
    private func loadOptions() async {
        render()
        let urls = await PhotoService.candidates(for: trip.destination)
        for url in urls {
            guard let image = await PhotoService.image(at: url) else { continue }
            images[url] = image
            let option = Option.remote(url)
            if let blankIndex = options.firstIndex(of: .blank) {
                options.insert(option, at: blankIndex)
            } else {
                options.append(option)
            }
            if selected == .blank && importedImage == nil {
                selected = option
                render()
            }
        }
        isLoadingList = false
    }

    @MainActor
    private func select(_ option: Option) {
        Task { await choose(option) }
    }

    @MainActor
    private func choose(_ option: Option) async {
        if case .remote(let url) = option, images[url] == nil {
            loadingURL = url
            let image = await PhotoService.image(at: url)
            if loadingURL == url { loadingURL = nil }
            guard let image else {
                options.removeAll { $0 == option }
                return
            }
            images[url] = image
        }
        selected = option
        render()
        prefetchNext()
    }

    @MainActor
    private func next() {
        guard options.count > 1, let index = options.firstIndex(of: selected) else { return }
        select(options[(index + 1) % options.count])
    }

    /// Ја вчитува следната слика однапред, за допирот да е моментален.
    @MainActor
    private func prefetchNext() {
        guard let index = options.firstIndex(of: selected) else { return }
        let nextOption = options[(index + 1) % options.count]
        if case .remote(let url) = nextOption, images[url] == nil {
            Task {
                if let image = await PhotoService.image(at: url) { images[url] = image }
            }
        }
    }

    @MainActor
    private func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let original = UIImage(data: data) else { return }
        importedImage = original.downscaled(maxSide: 1800)
        if !options.contains(.imported) { options.insert(.imported, at: 0) }
        selected = .imported
        render()
        pickerItem = nil
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: StoryCardView(trip: trip, photo: currentPhoto))
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
