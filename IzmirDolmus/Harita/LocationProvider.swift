import CoreLocation
import DolmusCore
import Observation

enum LocationError: Error {
    case denied
    case unavailable
    case timeout

    var message: String {
        switch self {
        case .denied: "Konum izni yok. Ayarlar > İzmir Dolmuş > Konum'dan izin verebilirsin."
        case .unavailable: "Konum alınamadı."
        case .timeout: "Konum zamanında alınamadı; açık bir alanda yeniden dene."
        }
    }
}

/// Tek seferlik konum: gerektiğinde izin ister, ilk geçerli konumu verir.
@Observable
final class LocationProvider {
    private(set) var isLocating = false
    /// Konum izni verildiğinde `true`; haritadaki mavi nokta için.
    private(set) var isAuthorized = false

    /// İlk geçerli konum; en çok `timeout` beklenir (`nil` ise konum gelene ya da
    /// görev iptal edilene kadar).
    func currentLocation(timeout: Duration? = .seconds(12)) async throws(LocationError) -> Coordinate {
        isLocating = true
        defer { isLocating = false }
        // Oturum açık kaldıkça "kullanırken" izni geçerli; gerekiyorsa sorulur.
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        do {
            let coordinate = try await withThrowingTaskGroup(of: Coordinate.self) { group in
                group.addTask { try await Self.firstFix() }
                if let timeout {
                    group.addTask {
                        try await Task.sleep(for: timeout)
                        throw LocationError.timeout
                    }
                }
                defer { group.cancelAll() }
                return try await group.next()!
            }
            isAuthorized = true
            return coordinate
        } catch let error as LocationError {
            throw error
        } catch {
            throw .unavailable
        }
    }

    @concurrent
    private static func firstFix() async throws -> Coordinate {
        for try await update in CLLocationUpdate.liveUpdates() {
            if update.authorizationDenied || update.authorizationDeniedGlobally {
                throw LocationError.denied
            }
            if let location = update.location {
                return Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            }
        }
        throw LocationError.unavailable
    }
}
