import Foundation
import MapKit

/// Предлози за градови додека се пишува (Apple Maps), како во апликацијата Maps.
/// Предлогот добива координати дури кога ќе се избере (WeatherService.resolve).
final class PlaceCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published private(set) var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func update(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            completer.cancel()
            results = []
            return
        }
        completer.queryFragment = trimmed
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Само места (градови, региони, држави) — без улици со куќни броеви
        let places = completer.results.filter { !$0.title.contains(where: { $0.isNumber }) }
        results = Array(places.prefix(8))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}
