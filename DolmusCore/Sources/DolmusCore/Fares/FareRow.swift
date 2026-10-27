import Foundation

/// İBB ücret servisindeki bir satır: hattın bir alt güzergahı ve ücreti.
///
/// Servisin cevabı: `[{"tanim": "-", "ucret": 40.00, "aciklama": "GEDİZ-ÜLKÜ SİNEMASI"}]`.
/// Önbellek de aynı anahtarlarla yazılır, aynı çözücüyle okunur.
public struct FareRow: Sendable, Hashable, Codable {
    /// Alt güzergahın adı; hat detayındaki ücret satırıyla `trNorm`'lu adından eşleşir.
    public let name: String
    /// TL, tam sayıya yuvarlanmış. Servis 0 ya da sayı olmayan bir değer verdiyse
    /// `nil`: o satırda veri dosyasındaki ücret kalır.
    public let fee: Int?

    public init(name: String, fee: Int?) {
        self.name = name
        self.fee = fee
    }

    enum CodingKeys: String, CodingKey {
        case name = "aciklama"
        case fee = "ucret"
    }

    // Servise güvenilmez: alan eksik ya da beklenmeyen tipte olsa da satır
    // atılmaz, yalnızca o alan boş sayılır (Flutter'daki gibi).
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = ((try? container.decodeIfPresent(String.self, forKey: .name)) ?? nil)?.dartTrimmed() ?? ""
        let raw = (try? container.decodeIfPresent(Double.self, forKey: .fee)) ?? nil
        fee = raw.flatMap { $0 > 0 && $0 < 100_000 ? Int($0.rounded()) : nil }
    }
}

/// Hat kodu (`DolmusHat.apiCode`) → o kodun ücret satırları.
public typealias FareTable = [String: [FareRow]]

/// Bir ücret tazelemesinin sonucu.
public struct FareRefreshResult: Sendable, Equatable {
    /// Cevabı gelen hatlar: hat kodu → ücret satırları.
    public var fares: FareTable = [:]
    /// İsteği başarısız olan hat kodları. İptal yüzünden yarıda kalanlar burada değil.
    public var failedCodes: [String] = []

    public init() {}
}
