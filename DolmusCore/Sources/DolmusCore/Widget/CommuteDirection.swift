import Foundation

/// "Eve / İşe" widget'ının yönü.
public enum CommuteDirection: String, Codable, Sendable, CaseIterable {
    case toWork
    case toHome

    /// Saate göre: 04:00–13:59 arası İşe, diğer saatler Eve.
    public static func automatic(at date: Date, calendar: Calendar = .current) -> CommuteDirection {
        (4..<14).contains(calendar.component(.hour, from: date)) ? .toWork : .toHome
    }

    /// `date`'ten sonraki ilk yön değişimi: 04:00 ya da 14:00.
    public static func nextSwitch(after date: Date, calendar: Calendar = .current) -> Date {
        let switches = [4, 14].compactMap { hour in
            calendar.nextDate(after: date, matching: DateComponents(hour: hour, minute: 0, second: 0), matchingPolicy: .nextTime)
        }
        return switches.min() ?? date.addingTimeInterval(12 * 3600)
    }

    public var opposite: CommuteDirection {
        self == .toWork ? .toHome : .toWork
    }
}

/// Widget'taki ⇄ ile elle seçilen yön. Sıradaki otomatik değişime (04:00 ya da
/// 14:00) kadar geçerli; sonra yön yine saate göre belirlenir.
public struct CommuteOverride: Codable, Sendable, Equatable {
    public var direction: CommuteDirection
    /// Bu andan itibaren elle seçim geçersiz.
    public var until: Date

    public init(direction: CommuteDirection, until: Date) {
        self.direction = direction
        self.until = until
    }

    /// `date` anındaki yön: geçerli bir elle seçim varsa o, yoksa saate göre.
    public static func direction(at date: Date, override: CommuteOverride?, calendar: Calendar = .current) -> CommuteDirection {
        if let override, date < override.until {
            return override.direction
        }
        return .automatic(at: date, calendar: calendar)
    }

    /// O an gösterilen yönün tersini sıradaki otomatik değişime kadar seçer.
    public static func toggled(from current: CommuteOverride?, at date: Date, calendar: Calendar = .current) -> CommuteOverride {
        let shown = direction(at: date, override: current, calendar: calendar)
        return CommuteOverride(direction: shown.opposite, until: CommuteDirection.nextSwitch(after: date, calendar: calendar))
    }
}
