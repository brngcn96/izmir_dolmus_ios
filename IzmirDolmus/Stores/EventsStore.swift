import DolmusCore
import Foundation
import Observation

/// Etkinlik listesinin sahibi: önce önbellekten anında açar, liste 6 saatten
/// eskiyse ağdan tazeler. Ağ yoksa önbellekteki liste gösterilmeye devam eder.
@Observable
final class EventsStore {
    enum Phase: Equatable {
        case idle
        /// Gösterilecek liste yok, ilk istek sürüyor.
        case loading
        case loaded
        /// Liste yok ve alınamadı.
        case failed(APIError)
    }

    private(set) var phase: Phase = .idle
    private(set) var events: [EventItem] = []
    /// Listenin ağdan alındığı zaman (önbellekten geldiyse önbelleğin zamanı).
    private(set) var updatedAt: Date?
    /// Son tazeleme başarısızsa nedeni: liste gösteriliyorsa önbellekten geliyordur.
    private(set) var refreshError: APIError?
    var filter = EventFilter()

    static let maxAge: TimeInterval = 6 * 3600

    private let client: APIClient
    private let cache: FileCache<EventFeed>
    /// Süren istek. Aynı anda gelen çağrılar (Anasayfa ve Etkinlikler ekranı
    /// birlikte açılınca) yeni istek atmaz, bunu bekler. İstek store'a ait:
    /// bekleyen ekran kapansa da tamamlanıp önbelleğe yazılır.
    private var refreshTask: Task<Void, Never>?

    init(
        client: APIClient = AppEnvironment.client,
        cache: FileCache<EventFeed> = FileCache(url: AppEnvironment.cacheFile("events_v1.json", in: .cachesDirectory))
    ) {
        self.client = client
        self.cache = cache
    }

    /// Filtrelenmiş, başlangıca göre sıralı liste.
    var visibleEvents: [EventItem] {
        filter.apply(to: events)
    }

    /// Mekan filtresinin seçenekleri, en çok etkinliği olan önce.
    var venues: [String] {
        EventFilter.venues(in: events)
    }

    func event(id: String) -> EventItem? {
        events.first { $0.id == id }
    }

    /// Ekran açılınca çağrılır: ilk seferde önbelleği okur; liste bayatsa
    /// (ya da hiç yoksa) ağdan tazeler. Tazeyse istek atmaz.
    func load() async {
        if phase == .idle, let entry = await cache.load() {
            events = entry.value.events
            updatedAt = entry.savedAt
            phase = .loaded
        }
        if let updatedAt, Date.now.timeIntervalSince(updatedAt) < Self.maxAge {
            return
        }
        await refresh()
    }

    /// Ağdan tazeler (aşağı çekince ya da "Tekrar dene"de). Süren bir istek
    /// varsa ikincisini atmaz, onun bitmesini bekler.
    func refresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }
        let task = Task { await fetch() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func fetch() async {
        if events.isEmpty {
            phase = .loading
        }
        do {
            let feed = try await client.send(EventsEndpoint())
            events = feed.events
            updatedAt = .now
            refreshError = nil
            phase = .loaded
            try? await cache.save(feed)
        } catch .cancelled {
            // İptal hata değil; liste yoksa bir dahaki açılışta yeniden denenir.
            if events.isEmpty {
                phase = .idle
            }
        } catch {
            refreshError = error
            phase = events.isEmpty ? .failed(error) : .loaded
        }
    }
}
