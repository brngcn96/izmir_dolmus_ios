import DolmusCore
import SwiftUI

/// Anasayfa. Tam hali Faz 7'de; şimdilik hava durumu, etkinliklere giriş ve
/// `Router` ile başka bir sekmede ekran açma örneği.
struct HomeView: View {
    @Environment(DataStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(EventsStore.self) private var events
    @Environment(\.apiClient) private var client

    @State private var weather: WeatherInfo?

    var body: some View {
        List {
            Section {
                WeatherRow(weather: weather)
            }
            Section("Keşfet") {
                Button {
                    router.planTrip()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Yol tarifi")
                                .font(.figtree(.headline, weight: .bold))
                                .foregroundStyle(Color.primary)
                            Text("Nereden nereye? Dolmuşla nasıl gidilir")
                                .font(.figtree(.subheadline))
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                    }
                }
                NavigationLink(value: Route.events) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Etkinlikler")
                                .font(.figtree(.headline, weight: .bold))
                            Text(eventsSummary)
                                .font(.figtree(.subheadline))
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "ticket")
                    }
                }
            }
            if let hat = store.data.hat(id: "M41") ?? store.data.hats.first {
                Section("Kısayol") {
                    Button("\(hat.name) hattını aç") {
                        router.show(.hat(id: hat.id), in: .hats)
                    }
                }
            }
        }
        .navigationTitle("Anasayfa")
        .task {
            // İki bağımsız iş aynı anda başlar; biri ötekini beklemez. Hava durumu
            // alınamazsa (`try?` → nil) satır yalnızca "İzmir" yazar.
            async let latestWeather = try? client.send(WeatherEndpoint(coordinate: .izmirCenter))
            async let eventsLoaded: Void = events.load()
            weather = await latestWeather
            await eventsLoaded
        }
    }

    private var eventsSummary: String {
        let thisWeek = events.events.filter { event in
            guard let start = event.start else { return false }
            return start >= .now && start < Date.now.addingTimeInterval(7 * 24 * 3600)
        }
        return switch (events.phase, thisWeek.count) {
        case (.loaded, 0): "Konser, tiyatro, sergi"
        case (.loaded, let count): "Önümüzdeki 7 günde \(count) etkinlik"
        default: "Konser, tiyatro, sergi"
        }
    }
}

/// Anlık hava durumu; gelene kadar yalnızca şehir adı.
private struct WeatherRow: View {
    let weather: WeatherInfo?

    var body: some View {
        HStack(spacing: 10) {
            if let weather {
                Image(systemName: weather.look.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.title2)
                Text(weather.temperatureLabel)
                    .font(.figtree(.title2, weight: .extraBold))
                    .monospacedDigit()
                Text("İzmir · \(weather.look.title)")
                    .font(.figtree(.subheadline, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "location")
                    .foregroundStyle(.secondary)
                Text("İzmir")
                    .font(.figtree(.subheadline, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
