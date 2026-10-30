import SwiftUI
import WeatherKit

/// Задолжителен потпис на изворот на прогнозата:
/// • Apple Weather: знакот „ Weather“ и линк до правната страница со другите извори (услов на WeatherKit)
/// • Open-Meteo: име и лиценца CC BY 4.0 (услов на лиценцата)
struct WeatherCreditView: View {
    @State private var markURL: URL?
    @State private var legalURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if AppConfig.weatherKitEnabled {
                HStack(spacing: 10) {
                    if let markURL {
                        AsyncImage(url: markURL) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Color.clear
                        }
                        .frame(width: 64, height: 13, alignment: .leading)
                        .accessibilityLabel("Apple Weather")
                    }
                    if let legalURL {
                        Link(L("Извори на податоците", "Other data sources"), destination: legalURL)
                            .font(.sans(11, .medium))
                            .foregroundStyle(Theme.navy)
                    }
                }
            } else if let url = URL(string: "https://open-meteo.com") {
                Link(destination: url) {
                    Text(L("Прогноза: Open-Meteo · CC BY 4.0", "Forecast: Open-Meteo · CC BY 4.0"))
                        .font(.sans(11))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard AppConfig.weatherKitEnabled, markURL == nil else { return }
        guard let attribution = try? await WeatherKit.WeatherService.shared.attribution else { return }
        // Апликацијата е секогаш во светол режим
        markURL = attribution.combinedMarkLightURL
        legalURL = attribution.legalPageURL
    }
}
