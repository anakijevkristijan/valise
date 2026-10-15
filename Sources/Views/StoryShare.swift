import SwiftUI
import UIKit

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

struct StorySheet: View {
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @State private var photo: UIImage?
    @State private var rendered: UIImage?

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 18) {
                HStack {
                    Eyebrow("Instagram Story", color: Theme.gold)
                    Spacer()
                    CircleIconButton(systemName: "xmark") { dismiss() }
                }

                // Жив преглед — се гледа веднаш, без чекање
                GeometryReader { geo in
                    let scale = min(geo.size.width / 360, geo.size.height / 640)
                    StoryCardView(trip: trip, photo: photo)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Theme.navy.opacity(0.16), radius: 24, x: 0, y: 12)
                        .scaleEffect(scale)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .animation(.easeInOut(duration: 0.35), value: photo != nil)
                }

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

                    Text(L("Избери Instagram → Story, или „Save Image“ за да ја зачуваш.",
                           "Choose Instagram → Story, or “Save Image” to keep it."))
                        .font(.sans(12))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
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
            .padding(24)
        }
        .task { await prepare() }
    }

    /// Фотографијата е обично веќе вчитана (се презема при отворање на патувањето).
    /// Ако не е, чекаме најмногу 3 секунди, па споделуваме без неа.
    @MainActor
    private func prepare() async {
        let found = await PhotoService.photo(for: trip.destination, timeout: 3)
        if let found { photo = found }
        render()
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: StoryCardView(trip: trip, photo: photo))
        renderer.scale = 3
        rendered = renderer.uiImage
    }
}
