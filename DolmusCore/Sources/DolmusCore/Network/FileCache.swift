import Foundation

/// Diskte JSON olarak duran, kaydedildiği zamanı da taşıyan tek bir değer.
///
/// Ücret tablosu ve etkinlik listesi bununla saklanır: ağ yokken son başarılı
/// cevap gösterilir, zaman damgasıyla da ne kadar eski olduğu bilinir.
public struct FileCache<Value: Codable & Sendable>: Sendable {
    public struct Entry: Codable, Sendable {
        public var savedAt: Date
        public var value: Value
    }

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// Kayıtlı değer; dosya yoksa ya da okunamıyorsa `nil`.
    @concurrent
    public func load() async -> Entry? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder.decode(Entry.self, from: data)
    }

    /// Değeri bütün olarak yazar: yazma yarıda kalırsa eski dosya bozulmaz.
    @concurrent
    public func save(_ value: Value, at date: Date = .now) async throws {
        let data = try Self.encoder.encode(Entry(savedAt: date, value: value))
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    public func remove() {
        try? FileManager.default.removeItem(at: url)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
