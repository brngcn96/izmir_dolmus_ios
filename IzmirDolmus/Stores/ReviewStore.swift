import DolmusCore
import Foundation
import Observation

/// Değerlendirme isteğinin durumu: kurallar `ReviewPolicy`'de, burada kalıcılık ve
/// "son başarılı yol tarifinden sonra henüz haritadan çıkılmadı" bayrağı.
@Observable
final class ReviewStore {
    private var policy: ReviewPolicy {
        didSet { save() }
    }
    /// Son başarılı yol tarifinden sonra henüz haritadan çıkılmadı.
    private var isPending = false
    /// Kart istenmeli; isteği `MainTabView` yapar (`requestReview` bir environment
    /// değeri) ve bayrağı indirir.
    private(set) var isRequested = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppEnvironment.defaults) {
        self.defaults = defaults
        policy = ReviewPolicy(
            firstDay: defaults.string(forKey: Keys.firstDay),
            trips: defaults.integer(forKey: Keys.trips),
            attempts: defaults.integer(forKey: Keys.attempts),
            lastAttempt: defaults.object(forKey: Keys.lastAttempt) as? Date
        )
        policy.markFirstDay(now: .now)
        // `didSet` init içinde çalışmaz: ilk gün burada yazılır.
        save()
    }

    /// Yol tarifi en az bir rota buldu.
    func noteSuccessfulTrip() {
        isPending = true
        policy.trips += 1
    }

    /// Haritadan çıkılırken çağrılır: kurallar izin veriyorsa kartı ister ve
    /// denemeyi sayar. Bayrak bir kez tüketilir: aynı yol tarifi için ikinci kez sorulmaz.
    func mapExited() {
        guard isPending else { return }
        isPending = false
        guard policy.canAsk(now: .now) else { return }
        policy.noteAttempt(now: .now)
        isRequested = true
    }

    func requestHandled() {
        isRequested = false
    }

    private func save() {
        defaults.set(policy.firstDay, forKey: Keys.firstDay)
        defaults.set(policy.trips, forKey: Keys.trips)
        defaults.set(policy.attempts, forKey: Keys.attempts)
        defaults.set(policy.lastAttempt, forKey: Keys.lastAttempt)
    }

    /// Flutter sürümündeki adlara yakın (veri paylaşılmıyor; adlar tutarlılık için).
    private enum Keys {
        static let firstDay = "review_first_day"
        static let trips = "review_trip_ok"
        static let attempts = "review_attempts"
        static let lastAttempt = "review_last"
    }
}
