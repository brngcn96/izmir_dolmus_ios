import Foundation

/// Endpoint'leri gönderen tek yer: isteği kurar, transport'a verir, cevabı
/// doğrular ve çözer. Her hata `APIError`'a çevrilir.
public struct APIClient: Sendable {
    let transport: any HTTPTransport

    public init(transport: any HTTPTransport = URLSession.shared) {
        self.transport = transport
    }

    /// Endpoint'in isteğini gönderir ve cevabını çözer.
    ///
    /// `@concurrent`: ağ beklemesi zaten thread bloklamaz, ama gövdeyi çözmek
    /// CPU işidir; ana aktörden çağrılsa da ana thread'de yapılmaz.
    @concurrent
    public func send<E: Endpoint>(_ endpoint: E) async throws(APIError) -> E.Response {
        // 1. Tarif → URLRequest.
        var request = URLRequest(url: endpoint.url, timeoutInterval: endpoint.timeout)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        for (field, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        // 2. Gönder. Transport `any Error` fırlatır; burada `APIError`'a çevrilir.
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.perform(request)
        } catch let error as URLError {
            // URLSession, görevi iptal edilen isteği `.cancelled` koduyla bitirir.
            throw error.code == .cancelled ? .cancelled : .transport(error.code)
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .transport(.unknown)
        }

        // 3. Durum kodu: yalnızca 2xx başarıdır.
        guard let http = response as? HTTPURLResponse else {
            throw .transport(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw .status(http.statusCode)
        }

        // 4. Gövdeyi çöz.
        do {
            return try endpoint.decode(data)
        } catch {
            throw .decoding
        }
    }
}
