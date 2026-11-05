import DolmusCore
import Foundation
import Observation

/// Canlı ücretlerin sahibi: önbelleği okur, 14 günde bir İBB'den kendiliğinden tazeler.
/// Ücretleri hatlara `DataStore` uygular (`RootView`). Elle tazeleme yok (Flutter'da da
/// kaldırılmıştı).
@Observable
final class FareStore {
    /// Hat kodu → canlı ücret satırları (önbellekten ya da son tazelemeden).
    private(set) var table: FareTable = [:]
    /// Son tamamlanan tazelemenin zamanı; hiç yapılmadıysa `nil`.
    private var updatedAt: Date?

    /// Kendiliğinden tazeleme aralığı (Flutter'daki gibi 14 gün).
    static let maxAge: TimeInterval = 14 * 24 * 3600

    private let refresher: FareRefresher
    private let cache: FileCache<FareTable>
    /// Süren tazeleme. Sahibi store: ekran kapansa da sürer.
    private var refreshTask: Task<Void, Never>?

    init(
        client: APIClient = AppEnvironment.client,
        cache: FileCache<FareTable> = FileCache(url: AppEnvironment.cacheFile("fares_v1.json", in: .applicationSupportDirectory))
    ) {
        self.refresher = FareRefresher(client: client)
        self.cache = cache
    }

    /// Hiç tazelenmedi ya da son tazeleme 14 günden eski.
    var isStale: Bool {
        guard let updatedAt else { return true }
        return Date.now.timeIntervalSince(updatedAt) >= Self.maxAge
    }

    /// Diskteki son ücretleri yükler (uygulama açılışında, ağdan önce).
    func loadCache() async {
        guard let entry = await cache.load() else { return }
        table = entry.value
        updatedAt = entry.savedAt
    }

    /// Tazelemeyi başlatır ve hemen döner; sürüyorsa bir şey yapmaz.
    func refresh(codes: [String]) {
        guard refreshTask == nil else { return }
        refreshTask = Task {
            let result = await refresher.refresh(codes: codes)
            await finish(result)
            refreshTask = nil
        }
    }

    private func finish(_ result: FareRefreshResult) async {
        // Cevabı gelmeyen hatlar önceki ücretini korur.
        table.merge(result.fares) { _, new in new }
        // Hiçbir cevap gelmediyse (ağ yok) tarih ilerlemez; sonra yeniden denenir.
        guard !result.fares.isEmpty else { return }
        let now = Date.now
        updatedAt = now
        try? await cache.save(table, at: now)
    }
}
