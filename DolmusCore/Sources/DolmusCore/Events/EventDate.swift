import Foundation

extension TimeZone {
    /// Etkinlik saatleri ve "bugün" hesabı İzmir saatiyle yapılır; cihazın saat
    /// dilimi başka olsa da etkinlik aynı saatte görünür.
    public static let istanbul = TimeZone(identifier: "Europe/Istanbul")!
}

extension Calendar {
    /// Miladi takvim, İstanbul saat dilimi.
    public static let istanbul: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .istanbul
        calendar.locale = Locale(identifier: "tr_TR")
        return calendar
    }()
}

/// Etkinlik listesindeki tarih metinlerini çözer.
///
/// Listede iki biçim birlikte geliyor: Ticketmaster'ınkiler UTC
/// (`2026-10-15T17:30:00Z`, yani 20:30), İBB'ninkiler saat dilimsiz
/// (`2025-12-11T18:00:00`, İzmir saati). Kesirli saniye ve `+03:00` gibi
/// farklar da kabul edilir; yalnızca tarih (`2026-10-15`) gün başı sayılır.
enum EventDate {
    static func parse(_ text: String) -> Date? {
        let pattern = /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:[.,](\d+))?)?)?(Z|[+-]\d{2}(?::?\d{2})?)?$/
        guard let match = text.dartTrimmed().wholeMatch(of: pattern) else { return nil }
        let (_, year, month, day, hour, minute, second, fraction, zone) = match.output

        var components = DateComponents()
        components.year = Int(year)
        components.month = Int(month)
        components.day = Int(day)
        components.hour = hour.flatMap { Int($0) } ?? 0
        components.minute = minute.flatMap { Int($0) } ?? 0
        components.second = second.flatMap { Int($0) } ?? 0
        if let fraction {
            // İlk dokuz hane nanosaniye: ".895330" → 895_330_000.
            let digits = String(fraction.prefix(9))
            components.nanosecond = (Int(digits) ?? 0) * Int(pow(10, Double(9 - digits.count)))
        }

        var calendar = Calendar(identifier: .gregorian)
        guard let timeZone = zone.map(timeZone(for:)) ?? .istanbul else { return nil }
        calendar.timeZone = timeZone
        guard
            let date = calendar.date(from: components),
            // 2026-02-31 gibi geçersiz tarihler takvimde ileri kayar; kabul edilmez.
            calendar.component(.day, from: date) == components.day
        else { return nil }
        return date
    }

    /// Önbelleğe yazılan biçim: UTC, `2026-10-15T17:30:00Z`. `parse` geri okur.
    static func format(_ date: Date) -> String {
        date.formatted(.iso8601)
    }

    private static func timeZone(for zone: Substring) -> TimeZone? {
        if zone == "Z" { return TimeZone(identifier: "UTC") }
        let sign = zone.hasPrefix("-") ? -1 : 1
        let digits = zone.dropFirst().filter(\.isNumber)
        guard let hours = Int(digits.prefix(2)) else { return nil }
        let minutes = Int(digits.dropFirst(2)) ?? 0
        return TimeZone(secondsFromGMT: sign * (hours * 3600 + minutes * 60))
    }
}
