import Foundation

/// Paketle birlikte gelen veri dosyaları (`Resources/`).
///
/// Tek kaynak Android (Flutter) repo'sundaki `assets/data/` klasörüdür; buradaki
/// kopya `Scripts/sync-data.sh` ile güncellenir, elle düzenlenmez.
public enum DataFile: String, CaseIterable, Sendable {
    /// Hatlar ve ücret satırları (meclis kararındaki alt güzergahlar).
    case routes
    /// Resmi İBB güzergah geometrileri: hat kodu → çizgiler.
    case hatGeoms = "hat_geoms"
    /// ESHOT durak adları — yer sözlüğü.
    case duraklar
    /// Önemli noktalar (metro, hastane, AVM…).
    case landmarks

    public var fileName: String { "\(rawValue).json" }

    /// Dosyanın paket kaynaklarındaki yeri; kaynaklara girmemişse `nil`.
    public var bundledURL: URL? {
        Bundle.module.url(forResource: rawValue, withExtension: "json")
    }

    /// Dosyanın paket kaynaklarındaki içeriği.
    public func bundledData() throws -> Data {
        guard let bundledURL else { throw DataLoadError.missingResource(self) }
        return try Data(contentsOf: bundledURL)
    }
}
