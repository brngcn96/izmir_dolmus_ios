import DolmusCore
import Observation

/// Anasayfa'nın konum işi: konumu alır, en yakın yerin adını ve çevresinden
/// geçen hatları güzergahlarıyla hazırlar, ardından hava durumunu çeker
/// (Flutter'daki `_HomeScreenState._locate`).
@Observable
final class HomeModel {
    enum Phase {
        case idle
        case locating
        case located(Surroundings)
        case failed(LocationError)
    }

    /// Konumun çevresi.
    struct Surroundings: Sendable {
        let here: Coordinate
        /// En yakın yerin adı ("158. Sokak · Bornova"); bulunamazsa "Konumun".
        let label: String
        /// Etiketten çıkan ilçe; İzmir dışındaysa ya da çıkmazsa "İzmir".
        let district: String
        /// Yakından uzağa, en çok `lineLimit` hat.
        let nearby: [NearbyHat]
        /// Her yakın hattın ilk güzergahı, `nearby` sırasıyla.
        let lines: [[Coordinate]]

        /// Haritada gösterilecek yer.
        var place: PlacePoint {
            PlacePoint(label: label, coordinate: here)
        }
    }

    /// Mini haritada en çok bu kadar hat (renk sayısı kadar). Ana aktör
    /// dışındaki hesapta da okunur.
    nonisolated static let lineLimit = 5

    private(set) var phase: Phase = .idle
    private(set) var weather: WeatherInfo?
    private let location = LocationProvider()

    var surroundings: Surroundings? {
        if case .located(let surroundings) = phase { surroundings } else { nil }
    }

    /// Başlıkta gösterilen yer adı: ilçe, yoksa "İzmir".
    var district: String {
        surroundings?.district ?? "İzmir"
    }

    /// İlk açılışta bir kez başlatır. İş, ekranın görevine bağlı değil: sekme
    /// değişince yarıda kesilmez.
    func startIfNeeded(data: DolmusData, client: APIClient) {
        guard case .idle = phase else { return }
        Task { await locate(data: data, client: client) }
    }

    /// Konumu (yeniden) alır, çevreyi hazırlar; hava durumunu konuma göre tazeler.
    func locate(data: DolmusData, client: APIClient) async {
        phase = .locating
        do {
            let here = try await location.currentLocation()
            let surroundings = await Self.surroundings(of: here, data: data)
            phase = .located(surroundings)
            // Hava durumu etiketle tutarlı olsun: ilçe çözüldüyse konumun, yoksa
            // (ör. İzmir dışı) İzmir'in havası.
            let isInIzmir = IzmirDistrict.isDistrict(surroundings.district)
            await loadWeather(at: isInIzmir ? here : .izmirCenter, client: client)
        } catch {
            phase = .failed(error)
            await loadWeather(at: .izmirCenter, client: client)
        }
    }

    /// Hava durumu alınamazsa eskisi kalır (ilk seferde yalnızca yer adı yazar).
    private func loadWeather(at coordinate: Coordinate, client: APIClient) async {
        if let weather = try? await client.send(WeatherEndpoint(coordinate: coordinate)) {
            self.weather = weather
        }
    }

    /// 34 bin yer içinde en yakını aramak cihazda bir kareden uzun sürebilir:
    /// ana aktörün dışında.
    @concurrent
    private static func surroundings(of here: Coordinate, data: DolmusData) async -> Surroundings {
        let nearest = data.nearestPlace(to: here)
        let nearby = data.nearbyHats(to: here, limit: lineLimit)
        return Surroundings(
            here: here,
            label: nearest?.place.label ?? "Konumun",
            district: IzmirDistrict.name(fromLabel: nearest?.place.label),
            nearby: nearby,
            lines: nearby.map { data.geoms(for: $0.hat.id).first?.points ?? [] }
        )
    }
}

extension LocationError {
    /// Anasayfa'daki kısa açıklama.
    var homeMessage: String {
        self == .denied ? "Konum kapalı ya da izin verilmedi." : "Konumun alınamadı."
    }
}
