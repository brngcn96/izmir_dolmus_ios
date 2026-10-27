import Foundation
import Synchronization
import Testing
@testable import DolmusCore

/// Ücret tazelemesi, İBB'yi taklit eden sahte bir sunucuyla (ağa çıkmadan).
@Suite struct FareRefresherTests {
    @Test("Her kod bir kez sorulur; aynı anda en çok 6 istek olur; ilerleme sırayla")
    @MainActor
    func limitsConcurrency() async {
        let server = FareServer(delay: .milliseconds(20))
        let codes = (1...40).map { "K\($0)" }
        var progress: [Int] = []
        let result = await FareRefresher(client: APIClient(transport: server)).refresh(codes: codes) { done, total in
            #expect(total == 40)
            progress.append(done)
        }
        #expect(Set(result.fares.keys) == Set(codes))
        #expect(result.fares["K7"] == [FareRow(name: "K7", fee: 40)])
        #expect(result.failedCodes.isEmpty)
        #expect(server.requestedCodes.sorted() == codes.sorted())
        #expect(server.maxInFlight == 6)
        #expect(progress == Array(1...40))
    }

    @Test("Hata veren kodlar ayrı sayılır, gelenler kaybolmaz")
    func collectsFailures() async {
        let server = FareServer(failures: ["K2": 500, "K5": 0])
        let codes = (1...8).map { "K\($0)" }
        let result = await FareRefresher(client: APIClient(transport: server)).refresh(codes: codes)
        #expect(Set(result.failedCodes) == ["K2", "K5"])
        #expect(Set(result.fares.keys) == Set(codes).subtracting(["K2", "K5"]))
    }

    @Test("İptal edilince yeni istek başlamaz; yarıda kalanlar başarısız sayılmaz")
    func stopsWhenCancelled() async {
        // İlk 12 istek hemen cevaplanır, sonrakiler iptale kadar askıda kalır.
        let server = FareServer(answeredFirst: 12)
        let codes = (1...40).map { "K\($0)" }
        let refresher = FareRefresher(client: APIClient(transport: server))
        let task = Task { await refresher.refresh(codes: codes) }

        // 12 cevap gelip yerlerine başlayan 6 istek askıda kalınca iptal et.
        // Süre sınırı: tazeleme hiç istek atmadan biterse test takılmasın.
        let deadline = ContinuousClock.now + .seconds(5)
        while server.hungCount < 6, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        let hung = server.hungCount
        task.cancel()
        let result = await task.value

        #expect(hung == 6)
        #expect(result.fares.count == 12)
        #expect(result.failedCodes.isEmpty)
        #expect(server.requestedCodes.count == 18)
    }

    @Test("İlerleme ana thread'de bildirilir, istekler ana thread dışında yapılır")
    @MainActor
    func reportsProgressOnMainThread() async {
        let server = FareServer()
        var progressOnMain: [Bool] = []
        _ = await FareRefresher(client: APIClient(transport: server)).refresh(codes: ["A", "B", "C"]) { _, _ in
            progressOnMain.append(Thread.isMainThread)
        }
        #expect(progressOnMain == [true, true, true])
        #expect(server.requestsOnMainThread == [false, false, false])
    }
}

/// İBB'yi taklit eden transport: istenen kodun adını taşıyan tek bir 40 TL'lik
/// satır döner. İstekleri, aynı anda kaç istek olduğunu ve thread'i kaydeder.
private final class FareServer: HTTPTransport {
    private struct State {
        var requestedCodes: [String] = []
        var requestsOnMainThread: [Bool] = []
        var inFlight = 0
        var maxInFlight = 0
        var hungCount = 0
    }

    private let state = Mutex(State())
    private let delay: Duration
    /// Kod → durum kodu; 0 bağlantı hatası demek.
    private let failures: [String: Int]
    /// Verilirse yalnızca ilk bu kadar istek cevaplanır, sonrakiler iptale kadar bekler.
    private let answeredFirst: Int?
    init(delay: Duration = .zero, failures: [String: Int] = [:], answeredFirst: Int? = nil) {
        self.delay = delay
        self.failures = failures
        self.answeredFirst = answeredFirst
    }

    var requestedCodes: [String] { state.withLock { $0.requestedCodes } }
    var requestsOnMainThread: [Bool] { state.withLock { $0.requestsOnMainThread } }
    var maxInFlight: Int { state.withLock { $0.maxInFlight } }
    /// Şu an askıda bekleyen istek sayısı.
    var hungCount: Int { state.withLock { $0.hungCount } }

    func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let code = request.url!.lastPathComponent
        let onMainThread = isMainThread()
        let index = state.withLock { state in
            state.requestedCodes.append(code)
            state.requestsOnMainThread.append(onMainThread)
            state.inFlight += 1
            state.maxInFlight = max(state.maxInFlight, state.inFlight)
            return state.requestedCodes.count
        }
        defer { state.withLock { $0.inFlight -= 1 } }

        if let answeredFirst, index > answeredFirst {
            state.withLock { $0.hungCount += 1 }
            defer { state.withLock { $0.hungCount -= 1 } }
            try await Task.sleep(for: .seconds(60))  // iptal edilince CancellationError
        } else if delay > .zero {
            try await Task.sleep(for: delay)
        }
        switch failures[code] {
        case 0?:
            throw URLError(.notConnectedToInternet)
        case let status?:
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        case nil:
            let body = #"[{"tanim":"-","ucret":40.00,"aciklama":"\#(code)"}]"#
            return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
    }
}

private func isMainThread() -> Bool {
    Thread.isMainThread
}
