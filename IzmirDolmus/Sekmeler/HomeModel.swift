import CoreLocation
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

    /// Konum bu kadar eskidiyse uygulama öne gelince yeniden alınır.
    static let maxAge: TimeInterval = 5 * 60

    private(set) var phase: Phase = .idle
    private(set) var weather: WeatherInfo?
    /// Hava durumunun künyesi; hava durumu yalnızca bununla birlikte gösterilir.
    private(set) var weatherCredit: WeatherCredit?
    private let location = LocationProvider()
    /// Son konumun alındığı an.
    private var locatedAt: Date?
    /// Konum zamanında gelmediyse ilk konumu süre sınırı olmadan bekleyen iş.
    private var waitingForFix: Task<Void, Never>?

    var surroundings: Surroundings? {
        if case .located(let surroundings) = phase { surroundings } else { nil }
    }

    /// Başlıkta gösterilen yer adı: ilçe, yoksa "İzmir".
    var district: String {
        surroundings?.district ?? "İzmir"
    }

    /// İlk açılışta bir kez başlatır. İş, ekranın görevine bağlı değil: sekme
    /// değişince yarıda kesilmez.
    func startIfNeeded(data: DolmusData, weatherProvider: any WeatherProvider) {
        guard case .idle = phase else { return }
        Task { await locate(data: data, weatherProvider: weatherProvider) }
    }

    /// Uygulama öne geldi: konum alınamadıysa ya da eskidiyse yeniden alır. İzin
    /// Ayarlar'dan verilip dönülmüş ya da kullanıcı başka bir yere gitmiş olabilir.
    func refreshIfNeeded(data: DolmusData, weatherProvider: any WeatherProvider) {
        switch phase {
        case .idle, .locating:
            return
        case .failed(.denied):
            // İzin hâlâ yoksa denemek boşuna.
            let status = CLLocationManager().authorizationStatus
            guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        case .failed:
            // Uygulama arka plana geçmediyse konum zaten bekleniyor.
            guard waitingForFix == nil else { return }
        case .located:
            guard let locatedAt, Date.now.timeIntervalSince(locatedAt) >= Self.maxAge else { return }
        }
        Task { await locate(data: data, weatherProvider: weatherProvider) }
    }

    /// Uygulama arka plana geçti: konumu beklemek durur, öne gelince yeniden denenir.
    func pause() {
        waitingForFix?.cancel()
        waitingForFix = nil
    }

    /// Konumu (yeniden) alır, çevreyi hazırlar; hava durumunu konuma göre tazeler.
    /// Önceki sonuç varsa yenilenirken o görünür; konum gelmezse de kalır (izin
    /// kalkmadıysa).
    func locate(data: DolmusData, weatherProvider: any WeatherProvider) async {
        pause()
        if surroundings == nil {
            phase = .locating
        }
        do {
            let here = try await location.currentLocation()
            await show(here, data: data, weatherProvider: weatherProvider)
        } catch {
            if surroundings != nil && error != .denied { return }
            phase = .failed(error)
            await loadWeather(at: .izmirCenter, weatherProvider: weatherProvider)
            if error != .denied {
                waitForFix(data: data, weatherProvider: weatherProvider)
            }
        }
    }

    /// Konum zamanında gelmediyse ilk konumu bekler; gelince Anasayfa kendiliğinden
    /// dolar (GPS geç tuttu, simülatöre sonradan konum verildi).
    private func waitForFix(data: DolmusData, weatherProvider: any WeatherProvider) {
        waitingForFix = Task {
            guard let here = try? await location.currentLocation(timeout: nil), !Task.isCancelled else { return }
            await show(here, data: data, weatherProvider: weatherProvider)
        }
    }

    private func show(_ here: Coordinate, data: DolmusData, weatherProvider: any WeatherProvider) async {
        let surroundings = await Self.surroundings(of: here, data: data)
        phase = .located(surroundings)
        locatedAt = .now
        // Hava durumu etiketle tutarlı olsun: ilçe çözüldüyse konumun, yoksa
        // (ör. İzmir dışı) İzmir'in havası.
        let isInIzmir = IzmirDistrict.isDistrict(surroundings.district)
        await loadWeather(at: isInIzmir ? here : .izmirCenter, weatherProvider: weatherProvider)
    }

    /// Hava durumu alınamazsa eskisi kalır (ilk seferde yalnızca yer adı yazar).
    /// Künye alınamazsa hava durumu da gösterilmez: WeatherKit verisi künyesiz
    /// gösterilemez.
    private func loadWeather(at coordinate: Coordinate, weatherProvider: any WeatherProvider) async {
        guard let weather = try? await weatherProvider.weather(at: coordinate) else { return }
        if weatherCredit == nil {
            weatherCredit = try? await weatherProvider.credit()
        }
        if weatherCredit != nil {
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
