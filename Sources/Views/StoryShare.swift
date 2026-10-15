import SwiftUI
import UIKit

/// Слика 9:16 за Instagram Story (360×640 pt → 1080×1920 px).
struct StoryCardView: View {
    let trip: Trip
    let photo: UIImage?

    private var foreground: Color { photo == nil ? Theme.navy : .white }

    private var eyebrow: String {
        if trip.isOngoing { return L("Во моментов", "Right now") }
        if trip.progress >= 1 { return L("Спакувано. Следна станица", "Packed. Next stop") }
        return L("Следна станица", "Next stop")
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

                BoardingPassCard(trip: trip, compact: true)
                    .padding(.horizontal, 22)

                Text(L("СПАКУВАНО СО VALISE", "PACKED WITH VALISE"))
                    .font(.sans(8, .semibold))
                    .tracking(2.6)
                    .foregroundStyle(foreground.opacity(0.75))
                    .padding(.top, 18)
                    .padding(.bottom, 28)
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

                Group {
                    if let rendered {
                        Image(uiImage: rendered)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: Theme.navy.opacity(0.18), radius: 20, x: 0, y: 10)
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Theme.stone)
                            .aspectRatio(9.0 / 16.0, contentMode: .fit)
                            .overlay(
                                VStack(spacing: 10) {
                                    ProgressView().tint(Theme.navy)
                                    Text(L("Ја подготвувам сликата…", "Preparing your image…"))
                                        .font(.sans(12))
                                        .foregroundStyle(Theme.muted)
                                }
                            )
                    }
                }
                .frame(maxHeight: .infinity)

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
                }
            }
            .padding(24)
        }
        .task { await render() }
    }

    @MainActor
    private func render() async {
        let photo = await PhotoService.photo(for: trip.destination)
        let renderer = ImageRenderer(content: StoryCardView(trip: trip, photo: photo))
        renderer.scale = 3
        withAnimation(.easeInOut(duration: 0.3)) {
            rendered = renderer.uiImage
        }
    }
}
