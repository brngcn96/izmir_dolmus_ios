/// Enlem/boylam çifti (derece).
///
/// Paket CoreLocation'a bağlı kalmasın diye kendi tipimiz; uygulama tarafında
/// `CLLocationCoordinate2D`'ye çevrilir.
public struct Coordinate: Sendable, Hashable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
