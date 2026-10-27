import Foundation
import Testing
@testable import DolmusCore

/// Ağa çıkmayan transport: her isteğe verilen kapanışla cevap verir ve gelen
/// istekleri saklar. `actor` olduğu için `requests` eşzamanlı isteklerde de güvenle büyür.
actor FakeTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    private let respond: @Sendable (URLRequest) throws -> (Data, URLResponse)

    init(respond: @escaping @Sendable (URLRequest) throws -> (Data, URLResponse)) {
        self.respond = respond
    }

    /// Her isteğe aynı durum kodu ve gövdeyle cevap verir.
    init(status: Int = 200, body: String) {
        self.init { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        }
    }

    func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return try respond(request)
    }
}

@Suite struct APIClientTests {
    @Test("200 cevabı endpoint'in tipine çözülür; istek doğru adrese GET")
    func decodesSuccess() async throws {
        let transport = FakeTransport(body: #"[{"tanim":"-","ucret":40.00,"aciklama":"GEDİZ-ÜLKÜ SİNEMASI"}]"#)
        let rows = try await APIClient(transport: transport).send(FaresEndpoint(code: "M41"))
        #expect(rows == [FareRow(name: "GEDİZ-ÜLKÜ SİNEMASI", fee: 40)])

        let request = try #require(await transport.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url == FaresEndpoint(code: "M41").url)
        #expect(request.timeoutInterval == 15)
    }

    @Test("2xx dışı durum kodu .status olur")
    func mapsStatusCode() async {
        let client = APIClient(transport: FakeTransport(status: 503, body: "Bakımdayız"))
        await #expect(throws: APIError.status(503)) {
            try await client.send(FaresEndpoint(code: "M41"))
        }
    }

    @Test("Çözülemeyen gövde .decoding olur")
    func mapsDecodingFailure() async {
        let client = APIClient(transport: FakeTransport(body: "<html>"))
        await #expect(throws: APIError.decoding) {
            try await client.send(EventsEndpoint())
        }
    }

    @Test("Bağlantı hatası .transport, iptal .cancelled olur")
    func mapsTransportErrors() async {
        let offline = APIClient(transport: FakeTransport { _ in throw URLError(.notConnectedToInternet) })
        await #expect(throws: APIError.transport(.notConnectedToInternet)) {
            try await offline.send(EventsEndpoint())
        }
        let cancelled = APIClient(transport: FakeTransport { _ in throw CancellationError() })
        await #expect(throws: APIError.cancelled) {
            try await cancelled.send(EventsEndpoint())
        }
    }

    @Test("POST: yöntem, başlık, gövde ve zaman aşımı endpoint'ten gelir")
    func buildsPostRequest() async throws {
        let transport = FakeTransport(body: "<html>Yanıtınız kaydedildi</html>")
        try await APIClient(transport: transport).send(FeedbackEndpoint(text: "Merhaba dünya"))

        let request = try #require(await transport.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        #expect(request.httpBody == Data("entry.66917862=Merhaba%20d%C3%BCnya".utf8))
        #expect(request.timeoutInterval == 15)
    }
}
