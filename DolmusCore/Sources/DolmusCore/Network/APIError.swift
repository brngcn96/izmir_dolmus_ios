import Foundation

/// `APIClient.send`'in fırlatabildiği bütün hatalar.
///
/// `send` `throws(APIError)` ile işaretli (typed throws): çağıranın `catch`
/// bloğundaki `error` `any Error` değil doğrudan `APIError`'dır, `switch` ile
/// bütün durumlar ele alınabilir.
public enum APIError: Error, Equatable, Sendable {
    /// İstek sunucuya ulaşamadı ya da yarıda kaldı: internet yok, zaman aşımı,
    /// sunucu bulunamadı… `URLError`'ın kodu taşınır.
    case transport(URLError.Code)
    /// Sunucu cevap verdi ama 2xx dışında bir durum koduyla.
    case status(Int)
    /// Gövde beklenen biçimde değil (ör. JSON çözülemedi).
    case decoding
    /// İstek iptal edildi: isteği bekleyen görev iptal oldu (ekran kapandı,
    /// kullanıcı vazgeçti). Kullanıcıya hata olarak gösterilmez.
    case cancelled

    /// Kullanıcıya gösterilecek kısa açıklama.
    public var message: String {
        switch self {
        case .transport(let code):
            switch code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
                "İnternet bağlantısı yok."
            case .timedOut:
                "Sunucu zamanında cevap vermedi."
            default:
                "Sunucuya bağlanılamadı."
            }
        case .status(let code):
            "Sunucu bir hata döndürdü (\(code))."
        case .decoding:
            "Sunucudan beklenmeyen bir cevap geldi."
        case .cancelled:
            "İstek iptal edildi."
        }
    }
}
