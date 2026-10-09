/// Adı ve konumu olan bir yer: ESHOT durağı, cadde, okul… (`duraklar.json`).
///
/// Etiketin sonunda ilçe eki olabilir: "Konak · Konak".
public struct PlacePoint: Sendable, Hashable {
    public let label: String
    public let coordinate: Coordinate

    public init(label: String, coordinate: Coordinate) {
        self.label = label
        self.coordinate = coordinate
    }
}

/// Önemli/çok aranan nokta: metro, İZBAN, hastane, AVM… (`landmarks.json`).
public struct Landmark: Sendable, Hashable {
    public let name: String
    public let coordinate: Coordinate
    /// Veri dosyasındaki tür: `metro`, `izban`, `hastane`, `avm`…
    public let kind: String

    public init(name: String, coordinate: Coordinate, kind: String) {
        self.name = name
        self.coordinate = coordinate
        self.kind = kind
    }
}
