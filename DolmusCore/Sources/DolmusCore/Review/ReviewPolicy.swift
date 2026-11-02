import Foundation

/// Değerlendirme isteğinin kuralları (Flutter'daki `ReviewPrompt`). Değer anında
/// sorulur: kullanıcı başarılı bir yol tarifini görüp haritadan çıkarken.
///
/// Koşullar: en az `minTrips` başarılı yol tarifi, ilk kullanım gününden sonraki
/// bir gün (tek günlük deneyenlere sorma), en çok `maxAttempts` deneme, denemeler
/// arasında en az `retryGap`.
///
/// Neden birden çok deneme: sistem kartı gösterip göstermediğini bildirmez
/// (`requestReview` "may or may not show any UI"); tek denemeden sonra kilitlemek
/// kullanıcıyı sonsuza dek kaybettirirdi.
public struct ReviewPolicy: Sendable, Equatable {
    public static let minTrips = 2
    public static let maxAttempts = 3
    public static let retryGap: TimeInterval = 7 * 24 * 3600

    /// İlk kullanım günü ("2026-10-31"); henüz işaretlenmediyse `nil`.
    public var firstDay: String?
    public var trips = 0
    public var attempts = 0
    public var lastAttempt: Date?

    public init(firstDay: String? = nil, trips: Int = 0, attempts: Int = 0, lastAttempt: Date? = nil) {
        self.firstDay = firstDay
        self.trips = trips
        self.attempts = attempts
        self.lastAttempt = lastAttempt
    }

    /// Uygulama açılışında: ilk kullanım gününü bir kez kaydeder.
    public mutating func markFirstDay(now: Date, calendar: Calendar = .current) {
        if firstDay == nil {
            firstDay = Self.dayKey(now, calendar: calendar)
        }
    }

    /// Şu an sorulabilir mi?
    public func canAsk(now: Date, calendar: Calendar = .current) -> Bool {
        guard trips >= Self.minTrips,
              let firstDay, firstDay != Self.dayKey(now, calendar: calendar),
              attempts < Self.maxAttempts
        else { return false }
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < Self.retryGap {
            return false
        }
        return true
    }

    /// Sistemden kart istendi.
    public mutating func noteAttempt(now: Date) {
        attempts += 1
        lastAttempt = now
    }

    /// Gün anahtarı, cihazın saat diliminde.
    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
