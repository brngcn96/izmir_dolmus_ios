import Foundation

/// İsteği karşı tarafa götürüp cevabı getiren katman.
///
/// Uygulamada `URLSession`; testlerde ağa hiç çıkmadan hazır cevap dönen sahte
/// bir tip. `APIClient` yalnızca bu protocol'ü tanır, hangisiyle konuştuğunu bilmez.
public protocol HTTPTransport: Sendable {
    func perform(_ request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPTransport {
    // Adı `data(for:)` değil: `URLSession`'ın kendi `data(for:delegate:)`'iyle
    // karışır, aşağıdaki çağrı kendini çağırırdı.
    public func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request)
    }
}
