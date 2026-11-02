import Foundation
import Testing
@testable import DolmusCore

@Suite struct ReviewPolicyTests {
    /// Saat dilimi sabit: test nerede koşarsa koşsun aynı günler.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }()

    static func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    /// Koşulları sağlayan durum: dün başladı, iki yol tarifi, hiç sorulmadı.
    static func ready() -> ReviewPolicy {
        var policy = ReviewPolicy(trips: ReviewPolicy.minTrips)
        policy.markFirstDay(now: date(10), calendar: calendar)
        return policy
    }

    func canAsk(_ policy: ReviewPolicy, at date: Date) -> Bool {
        policy.canAsk(now: date, calendar: Self.calendar)
    }

    @Test("İlk gün işaretlenir ve bir daha değişmez")
    func firstDayIsSticky() {
        var policy = ReviewPolicy()
        policy.markFirstDay(now: Self.date(10), calendar: Self.calendar)
        policy.markFirstDay(now: Self.date(12), calendar: Self.calendar)
        #expect(policy.firstDay == "2026-10-10")
    }

    @Test("Koşullar sağlanınca sorulur")
    func asksWhenReady() {
        #expect(canAsk(Self.ready(), at: Self.date(11)))
    }

    @Test("Yeterli yol tarifi yoksa sorulmaz")
    func needsTrips() {
        var policy = Self.ready()
        policy.trips = ReviewPolicy.minTrips - 1
        #expect(!canAsk(policy, at: Self.date(11)))
    }

    @Test("İlk kullanım gününde sorulmaz, gün değişince sorulur")
    func notOnFirstDay() {
        let policy = Self.ready()
        #expect(!canAsk(policy, at: Self.date(10, hour: 23)))
        #expect(canAsk(policy, at: Self.date(11, hour: 0)))
    }

    @Test("İlk gün kaydı yoksa sorulmaz")
    func needsFirstDay() {
        #expect(!canAsk(ReviewPolicy(trips: 5), at: Self.date(11)))
    }

    @Test("Denemeler arasında yedi gün beklenir")
    func retryGap() {
        var policy = Self.ready()
        policy.noteAttempt(now: Self.date(11))
        #expect(!canAsk(policy, at: Self.date(17)))
        #expect(!canAsk(policy, at: Self.date(18).addingTimeInterval(-1)))
        #expect(canAsk(policy, at: Self.date(18)))
    }

    @Test("Üç denemeden sonra bir daha sorulmaz")
    func maxAttempts() {
        var policy = Self.ready()
        for day in [11, 18, 25] {
            #expect(canAsk(policy, at: Self.date(day)))
            policy.noteAttempt(now: Self.date(day))
        }
        #expect(policy.attempts == ReviewPolicy.maxAttempts)
        #expect(!canAsk(policy, at: Self.date(31)))
    }
}
