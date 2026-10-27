import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

/// Bir isteğin tarifi: adresi, yöntemi, gövdesi ve cevabın neye çözüleceği.
///
/// Her servis çağrısı bu protocol'e uyan küçük bir değerdir (`FaresEndpoint`,
/// `EventsEndpoint`…). Endpoint ağ hakkında hiçbir şey bilmez, yalnızca tarif
/// eder; isteği gönderen tek yer `APIClient.send`'dir.
public protocol Endpoint: Sendable {
    /// Cevabın çözüldüğü tip.
    associatedtype Response: Sendable

    var url: URL { get }
    var method: HTTPMethod { get }
    /// İsteğe eklenecek başlıklar (ör. `Content-Type`).
    var headers: [String: String] { get }
    var body: Data? { get }
    /// Saniye; `URLRequest.timeoutInterval`'a gider. Toplam süre değil: veri
    /// gelmeden geçebilecek en uzun aradır.
    var timeout: TimeInterval { get }

    /// Cevap gövdesini `Response`'a çevirir; biçim bozuksa fırlatır.
    func decode(_ data: Data) throws -> Response
}

// Çoğu endpoint'in ortak değerleri; farklısı gereken endpoint kendisi verir.
extension Endpoint {
    public var method: HTTPMethod { .get }
    public var headers: [String: String] { [:] }
    public var body: Data? { nil }
    public var timeout: TimeInterval { 15 }
}

// JSON cevaplı endpoint'ler `decode` yazmak zorunda kalmaz.
extension Endpoint where Response: Decodable {
    public func decode(_ data: Data) throws -> Response {
        try JSONDecoder().decode(Response.self, from: data)
    }
}
