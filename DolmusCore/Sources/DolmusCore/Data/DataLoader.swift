import Foundation

/// Paketle gelen dört veri dosyasını okuyup `DolmusData`'yı kurar.
public struct DataLoader: Sendable {
    /// Bir veri dosyasının baytlarını verir. Varsayılanı paket kaynaklarından
    /// okur; testler sahte veri vermek için değiştirir.
    let read: @Sendable (DataFile) throws -> Data

    public init(read: @escaping @Sendable (DataFile) throws -> Data = { try $0.bundledData() }) {
        self.read = read
    }

    /// Dosyaları çözer ve veriyi kurar.
    @concurrent
    public func load() async throws -> DolmusData {
        let decoder = JSONDecoder()
        let routes = try decoder.decode(RoutesFile.self, from: read(.routes)).routes
        let geoms = try decoder.decode([String: [RawHatGeom]].self, from: read(.hatGeoms))
        let duraklar = try decoder.decode([PlacePoint].self, from: read(.duraklar))
        let landmarks = try decoder.decode([Landmark].self, from: read(.landmarks))
        return DolmusData(routes: routes, geoms: geoms, duraklar: duraklar, landmarks: landmarks)
    }

}

public enum DataLoadError: Error, LocalizedError {
    /// Veri dosyası paket kaynaklarına girmemiş.
    case missingResource(DataFile)

    public var errorDescription: String? {
        switch self {
        case .missingResource(let file):
            "\(file.fileName) uygulama paketinde bulunamadı."
        }
    }
}
