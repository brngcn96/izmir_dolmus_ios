import DolmusCore
import Foundation
import Observation

/// Canlı ücretlerin sahibi: önbelleği okur, İBB'den tazeler, ilerlemeyi ve
/// sonucu arayüze bildirir. Ücretleri hatlara `DataStore` uygular (`RootView`).
@Observable
final class FareStore {
    enum Status: Equatable {
        case idle
        case refreshing(done: Int, total: Int)
        /// Tazeleme bitti: kaç hattın cevabı geldi, kaçı alınamadı.
        case finished(updated: Int, failed: Int)
        /// Kullanıcı iptal etti; gelenler bu oturumda kullanılır, kaydedilmez.
        case cancelled(updated: Int)
    }

    /// Hat kodu → canlı ücret satırları (önbellekten ya da son tazelemeden).
    private(set) var table: FareTable = [:]
    /// Son tamamlanan tazelemenin zamanı; hiç yapılmadıysa `nil`.
    private(set) var updatedAt: Date?
    private(set) var status: Status = .idle

    /// Kendiliğinden tazeleme aralığı (Flutter'daki gibi 14 gün).
    static let maxAge: TimeInterval = 14 * 24 * 3600

    private let refresher: FareRefresher
    private let cache: FileCache<FareTable>
    /// Süren tazeleme. Sahibi store: ekran kapansa da sürer, `cancel()` ile durur.
    private var refreshTask: Task<Void, Never>?

    init(
        client: APIClient = APIClient(),
        cache: FileCache<FareTable> = FileCache(url: .applicationSupportDirectory.appending(path: "fares_v1.json"))
    ) {
        self.refresher = FareRefresher(client: client)
        self.cache = cache
    }

    /// Hiç tazelenmedi ya da son tazeleme 14 günden eski.
    var isStale: Bool {
        guard let updatedAt else { return true }
        return Date.now.timeIntervalSince(updatedAt) >= Self.maxAge
    }

    var isRefreshing: Bool {
        refreshTask != nil
    }

    /// Diskteki son ücretleri yükler (uygulama açılışında, ağdan önce).
    func loadCache() async {
        guard let entry = await cache.load() else { return }
        table = entry.value
        updatedAt = entry.savedAt
    }

    /// Tazelemeyi başlatır ve hemen döner; sürüyorsa bir şey yapmaz. İlerleme
    /// `status`'tan izlenir.
    func refresh(codes: [String]) {
        guard refreshTask == nil else { return }
        status = .refreshing(done: 0, total: codes.count)
        refreshTask = Task {
            let result = await refresher.refresh(codes: codes) { done, total in
                self.status = .refreshing(done: done, total: total)
            }
            await finish(result, cancelled: Task.isCancelled)
            refreshTask = nil
        }
    }

    func cancel() {
        refreshTask?.cancel()
    }

    private func finish(_ result: FareRefreshResult, cancelled: Bool) async {
        // Cevabı gelmeyen hatlar önceki ücretini korur.
        table.merge(result.fares) { _, new in new }
        if cancelled {
            // Yarım tazeleme "güncel" sayılmaz: tarih ve dosya değişmez, bir
            // sonraki açılışta yeniden denenir.
            status = .cancelled(updated: result.fares.count)
            return
        }
        // Hiçbir cevap gelmediyse (ağ yok) tarih ilerlemez; sonra yeniden denenir.
        if !result.fares.isEmpty {
            let now = Date.now
            updatedAt = now
            try? await cache.save(table, at: now)
        }
        status = .finished(updated: result.fares.count, failed: result.failedCodes.count)
    }
}
