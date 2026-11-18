import SwiftUI
import MapKit

// MARK: - Избери место на мапа (наместо адреса пишувана рачно)

/// Изборот: име (ако е познато место), адреса и координати.
struct PickedSpot: Equatable {
    var name: String?
    var address: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

/// Предлози за места и адреси во близина на градот додека се пишува.
final class SpotCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published private(set) var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func update(_ query: String, near center: CLLocationCoordinate2D) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            completer.cancel()
            results = []
            return
        }
        completer.region = MKCoordinateRegion(center: center, latitudinalMeters: 40_000, longitudinalMeters: 40_000)
        completer.queryFragment = trimmed
    }

    func clear() {
        completer.cancel()
        results = []
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = Array(completer.results.prefix(6))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}

enum SpotText {
    /// „Kirchengasse 41, Neubau“
    static func address(_ placemark: CLPlacemark) -> String {
        var parts: [String] = []
        let street = [placemark.thoroughfare, placemark.subThoroughfare].compactMap { $0 }.joined(separator: " ")
        if !street.isEmpty { parts.append(street) }
        if let area = placemark.subLocality ?? placemark.locality { parts.append(area) }
        if parts.isEmpty, let name = placemark.name { parts.append(name) }
        return parts.joined(separator: ", ")
    }
}

/// Мапа на градот: се пребарува место или адреса, или се допира на мапата.
/// Не бара дозвола за локација - не ја користи твојата локација.
struct PlaceMapPicker: View {
    let center: CLLocationCoordinate2D
    let onPick: (PickedSpot) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var completer = SpotCompleter()
    @State private var query = ""
    @State private var spot: PickedSpot?
    @State private var camera: MapCameraPosition
    @State private var busy = false
    @FocusState private var searching: Bool

    init(center: CLLocationCoordinate2D, initial: PickedSpot?, onPick: @escaping (PickedSpot) -> Void) {
        self.center = center
        self.onPick = onPick
        _spot = State(initialValue: initial)
        let focus = initial?.coordinate ?? center
        let span: CLLocationDistance = initial == nil ? 9000 : 1200
        _camera = State(initialValue: .region(MKCoordinateRegion(center: focus, latitudinalMeters: span, longitudinalMeters: span)))
    }

    var body: some View {
        ZStack(alignment: .top) {
            MapReader { proxy in
                Map(position: $camera) {
                    if let spot {
                        Marker(spot.name ?? "", systemImage: "mappin", coordinate: spot.coordinate)
                            .tint(Theme.navy)
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .all))
                .onTapGesture(coordinateSpace: .local) { point in
                    guard let coordinate = proxy.convert(point, from: .local) else { return }
                    searching = false
                    completer.clear()
                    drop(at: coordinate)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 10) {
                searchBar
                if searching && !completer.results.isEmpty {
                    resultsList
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .safeAreaInset(edge: .bottom) { bottomCard }
        .onChange(of: query) { _, value in completer.update(value, near: center) }
    }

    // MARK: Делови

    private var searchBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.surface))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.muted)
                TextField("", text: $query,
                          prompt: Text(L("Пребарај место или адреса", "Search a place or address")).foregroundColor(Theme.muted))
                    .font(.sans(16))
                    .foregroundStyle(Theme.ink)
                    .focused($searching)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Capsule().fill(Theme.surface))
        }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(completer.results.enumerated()), id: \.offset) { index, item in
                Button { choose(item) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.sans(15, .medium))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            if !item.subtitle.isEmpty {
                                Text(item.subtitle)
                                    .font(.sans(12))
                                    .foregroundStyle(Theme.muted)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < completer.results.count - 1 {
                    Hairline().padding(.leading, 50)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let spot {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.navy)
                    VStack(alignment: .leading, spacing: 3) {
                        if let name = spot.name, !name.isEmpty {
                            Text(name)
                                .font(.serif(20))
                                .foregroundStyle(Theme.ink)
                        }
                        Text(spot.address.isEmpty ? L("Избрано место на мапата", "Pinned on the map") : spot.address)
                            .font(.sans(13))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer(minLength: 0)
                    if busy { ProgressView() }
                }
                Button {
                    onPick(spot)
                    dismiss()
                } label: {
                    Text(L("Избери го ова место", "Use this place"))
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                HStack(spacing: 10) {
                    if busy {
                        ProgressView()
                    } else {
                        Image(systemName: "hand.tap")
                            .foregroundStyle(Theme.gold)
                    }
                    Text(L("Пребарај горе или допри на мапата.", "Search above or tap on the map."))
                        .font(.sans(14))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.paper))
        .shadow(color: .black.opacity(0.12), radius: 14, y: -2)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: Избор

    private func choose(_ completion: MKLocalSearchCompletion) {
        searching = false
        query = completion.title
        completer.clear()
        busy = true
        Task {
            let response = try? await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start()
            await MainActor.run {
                busy = false
                guard let item = response?.mapItems.first else { return }
                let coordinate = item.placemark.coordinate
                let address = SpotText.address(item.placemark)
                let isAddress = completion.subtitle.isEmpty || item.name == address
                spot = PickedSpot(name: isAddress ? nil : item.name, address: address.isEmpty ? completion.subtitle : address,
                                  latitude: coordinate.latitude, longitude: coordinate.longitude)
                withAnimation(.easeInOut(duration: 0.4)) {
                    camera = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 900, longitudinalMeters: 900))
                }
            }
        }
    }

    private func drop(at coordinate: CLLocationCoordinate2D) {
        spot = PickedSpot(name: nil, address: "", latitude: coordinate.latitude, longitude: coordinate.longitude)
        busy = true
        Task {
            let marks = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            await MainActor.run {
                busy = false
                guard let mark = marks?.first, spot?.latitude == coordinate.latitude else { return }
                spot?.address = SpotText.address(mark)
                if let poi = mark.areasOfInterest?.first { spot?.name = poi }
            }
        }
    }
}
