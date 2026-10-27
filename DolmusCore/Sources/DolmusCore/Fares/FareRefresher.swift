import Foundation

/// Hat kodlarının güncel ücretlerini İBB'den, aynı anda en çok `maxConcurrent`
/// istekle çeker.
public struct FareRefresher: Sendable {
    let client: APIClient
    let maxConcurrent: Int

    public init(client: APIClient, maxConcurrent: Int = 6) {
        precondition(maxConcurrent > 0)
        self.client = client
        self.maxConcurrent = maxConcurrent
    }

    /// Her kod için bir istek atar; biri bitince sıradakini başlatır.
    ///
    /// Görev iptal edilirse yeni istek başlatmaz; uçuştaki istekler `.cancelled`
    /// ile biter ve o ana kadar gelenler döner.
    ///
    /// - Parameter onProgress: her istek bitince (biten, toplam) ile ana aktörde
    ///   çağrılır; arayüzü doğrudan güncelleyebilir. `withTaskGroup`'un gövdesi
    ///   çağıranın aktöründe kalmayabilir, bu yüzden aktör tipte yazılı.
    public func refresh(
        codes: [String],
        onProgress: @MainActor (_ done: Int, _ total: Int) -> Void = { _, _ in }
    ) async -> FareRefreshResult {
        var result = FareRefreshResult()
        await withTaskGroup(of: (code: String, outcome: Result<[FareRow], APIError>).self) { group in
            var pending = codes[...]
            // İlk dalga: en çok maxConcurrent istek.
            for _ in 0..<maxConcurrent {
                guard let code = pending.popFirst() else { break }
                group.addTask { await fetch(code) }
            }
            // Biri bitince yerine sıradakini koy: aynı anda hep en çok maxConcurrent istek.
            var done = 0
            while let (code, outcome) = await group.next() {
                switch outcome {
                case .success(let rows):
                    result.fares[code] = rows
                case .failure(.cancelled):
                    break
                case .failure:
                    result.failedCodes.append(code)
                }
                done += 1
                await onProgress(done, codes.count)
                if !Task.isCancelled, let code = pending.popFirst() {
                    group.addTask { await fetch(code) }
                }
            }
        }
        return result
    }

    private func fetch(_ code: String) async -> (code: String, outcome: Result<[FareRow], APIError>) {
        do {
            return (code, .success(try await client.send(FaresEndpoint(code: code))))
        } catch {
            return (code, .failure(error))
        }
    }
}
