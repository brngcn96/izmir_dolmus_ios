import CoreLocation
import DolmusCore
import Foundation
import WeatherKit

/// Hava durumunu gösterirken verilmesi gereken künye: "Apple Weather" logosu ve veri
/// kaynaklarının yasal sayfasına bağlantı (WeatherKit'in kullanım şartı).
nonisolated struct WeatherCredit: Sendable, Equatable {
    /// Logo, açık ve koyu zemin için; yoksa yerine `serviceName` yazılır.
    var markLightURL: URL?
    var markDarkURL: URL?
    var serviceName: String
    var legalPageURL: URL
}

/// Anlık hava durumu ve künyesi. Uygulamada WeatherKit; UI testlerinde sabit değerler
/// (WeatherKit imzalı ve yetkili bir uygulama ister, testler de ağa çıkmaz).
nonisolated protocol WeatherProvider: Sendable {
    func weather(at coordinate: Coordinate) async throws -> WeatherInfo
    func credit() async throws -> WeatherCredit
}

/// Apple'ın WeatherKit'i: Apple Developer üyeliğiyle ayda 500.000 isteğe kadar ücretsiz,
/// reklamlı uygulamada da kullanılabilir (Open-Meteo'nun ücretsiz API'si yalnızca ticari
/// olmayan kullanıma açık). App ID'de WeatherKit hizmeti açık olmalı; yetkisi
/// `IzmirDolmus.entitlements`'ta. Yetki ya da imza yoksa istek hata verir, Anasayfa
/// hava durumunu göstermez.
nonisolated struct AppleWeatherProvider: WeatherProvider {
    func weather(at coordinate: Coordinate) async throws -> WeatherInfo {
        // İki ondalık (~1 km) hava durumu için yeter; gereğinden kesin konum gönderilmez.
        let location = CLLocation(
            latitude: (coordinate.latitude * 100).rounded() / 100,
            longitude: (coordinate.longitude * 100).rounded() / 100
        )
        let current = try await WeatherService.shared.weather(for: location, including: .current)
        return WeatherInfo(
            temperature: current.temperature.converted(to: .celsius).value,
            condition: current.condition.rawValue,
            isDaylight: current.isDaylight
        )
    }

    func credit() async throws -> WeatherCredit {
        let attribution = try await WeatherService.shared.attribution
        return WeatherCredit(
            markLightURL: attribution.combinedMarkLightURL,
            markDarkURL: attribution.combinedMarkDarkURL,
            serviceName: attribution.serviceName,
            legalPageURL: attribution.legalPageURL
        )
    }
}

#if DEBUG
/// UI testlerinin hava durumu: WeatherKit'e gidilmez, logo yerine adı yazılır.
nonisolated struct UITestWeatherProvider: WeatherProvider {
    func weather(at coordinate: Coordinate) async throws -> WeatherInfo {
        WeatherInfo(temperature: 21.4, condition: "mostlyClear")
    }

    func credit() async throws -> WeatherCredit {
        WeatherCredit(serviceName: "Apple Weather", legalPageURL: URL(string: "https://developer.apple.com/weatherkit/data-source-attribution/")!)
    }
}
#endif
