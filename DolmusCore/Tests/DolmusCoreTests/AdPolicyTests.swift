import Foundation
import Testing
@testable import DolmusCore

@Suite struct AdPolicyTests {
    /// Saat dilimi sabit: test nerede koşarsa koşsun aynı günler.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }()

    static func date(_ day: Int, hour: Int = 12, second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, second: second))!
    }

    /// İkinci ya da sonraki bir oturum, bugün henüz reklam yok.
    static func laterSession() -> AdPolicy {
        AdPolicy(isFirstLaunchDone: true)
    }

    @Test("İlk oturumda tam ekran reklam yok, istenmez de")
    func firstSession() {
        var policy = AdPolicy()
        policy.noteAppActive()
        #expect(policy.isFirstLaunchDone)
        #expect(policy.isFirstSession)
        #expect(!policy.canShowAppOpen(now: Self.date(3), calendar: Self.calendar))
        #expect(!policy.canShowInterstitial(now: Self.date(3), calendar: Self.calendar))
        #expect(!policy.shouldLoadAppOpen(now: Self.date(3), calendar: Self.calendar))
        #expect(!policy.shouldLoadInterstitial(now: Self.date(3), calendar: Self.calendar))
    }

    @Test("İlk açılış kaydedildiyse sonraki oturum ilk oturum değil")
    func nextSession() {
        var first = AdPolicy()
        first.noteAppActive()
        let next = AdPolicy(isFirstLaunchDone: first.isFirstLaunchDone)
        #expect(!next.isFirstSession)
        #expect(next.canShowAppOpen(now: Self.date(3), calendar: Self.calendar))
        #expect(next.shouldLoadAppOpen(now: Self.date(3), calendar: Self.calendar))
    }

    @Test("App Open günde bir kez; ertesi gün yeniden")
    func appOpenDaily() {
        var policy = Self.laterSession()
        policy.noteAppOpenShown(now: Self.date(3, hour: 9), calendar: Self.calendar)
        #expect(policy.appOpenDay == "2026-11-3")

        // Aynı gün yeni oturum açılsa da gösterilmez, istenmez.
        let sameDay = AdPolicy(isFirstLaunchDone: true, appOpenDay: policy.appOpenDay)
        #expect(!sameDay.canShowAppOpen(now: Self.date(3, hour: 23), calendar: Self.calendar))
        #expect(!sameDay.shouldLoadAppOpen(now: Self.date(3, hour: 23), calendar: Self.calendar))
        #expect(sameDay.canShowAppOpen(now: Self.date(4, hour: 0), calendar: Self.calendar))
    }

    @Test("App Open oturumda bir kez: gece yarısı geçse de")
    func appOpenOncePerSession() {
        var policy = Self.laterSession()
        policy.noteAppOpenShown(now: Self.date(3, hour: 23), calendar: Self.calendar)
        policy.noteFullScreenDismissed(now: Self.date(3, hour: 23))
        #expect(!policy.canShowAppOpen(now: Self.date(4, hour: 1), calendar: Self.calendar))
    }

    @Test("Geçiş reklamı günde bir kez; App Open'dan bağımsız")
    func interstitialDaily() {
        var policy = Self.laterSession()
        #expect(policy.canShowInterstitial(now: Self.date(3), calendar: Self.calendar))
        policy.noteInterstitialShown(now: Self.date(3), calendar: Self.calendar)
        policy.noteFullScreenDismissed(now: Self.date(3))
        #expect(policy.interstitialDay == "2026-11-3")
        #expect(!policy.canShowInterstitial(now: Self.date(3, hour: 20), calendar: Self.calendar))
        #expect(!policy.shouldLoadInterstitial(now: Self.date(3, hour: 20), calendar: Self.calendar))
        #expect(policy.canShowInterstitial(now: Self.date(4), calendar: Self.calendar))
        // Geçiş reklamı App Open'ın gününü kilitlemez.
        #expect(policy.canShowAppOpen(now: Self.date(3, hour: 20), calendar: Self.calendar))
    }

    @Test("İki tam ekran reklam arasında 90 saniye; süre kapanıştan sayılır")
    func gapBetweenFullScreenAds() {
        var policy = Self.laterSession()
        policy.noteAppOpenShown(now: Self.date(3, hour: 12, second: 0), calendar: Self.calendar)
        policy.noteFullScreenDismissed(now: Self.date(3, hour: 12, second: 20))
        let tooSoon = Self.date(3, hour: 12, second: 20).addingTimeInterval(AdPolicy.gap - 1)
        let afterGap = Self.date(3, hour: 12, second: 20).addingTimeInterval(AdPolicy.gap)
        #expect(!policy.canShowInterstitial(now: tooSoon, calendar: Self.calendar))
        #expect(policy.canShowInterstitial(now: afterGap, calendar: Self.calendar))
    }

    @Test("Gösterilemeyen reklam günü kilitlemez")
    func failedShowKeepsDay() {
        let policy = Self.laterSession()
        // Gösterim olmadı: `note…Shown` çağrılmadı.
        #expect(policy.canShowAppOpen(now: Self.date(3), calendar: Self.calendar))
        #expect(policy.canShowInterstitial(now: Self.date(3), calendar: Self.calendar))
    }

    @Test("App Open dört saat taze, dört saniye içinde zamanında")
    func appOpenTiming() {
        let loaded = Self.date(3, hour: 8)
        #expect(AdPolicy.isFresh(loadedAt: loaded, now: loaded.addingTimeInterval(AdPolicy.appOpenLifetime)))
        #expect(!AdPolicy.isFresh(loadedAt: loaded, now: loaded.addingTimeInterval(AdPolicy.appOpenLifetime + 1)))
        #expect(AdPolicy.isInTime(requestedAt: loaded, now: loaded.addingTimeInterval(AdPolicy.appOpenWait)))
        #expect(!AdPolicy.isInTime(requestedAt: loaded, now: loaded.addingTimeInterval(AdPolicy.appOpenWait + 0.5)))
    }

    @Test("Gün, takvimin saat diliminde değişir")
    func dayInTimeZone() {
        // İstanbul'da 4 Kasım 01:00, UTC'de hâlâ 3 Kasım 22:00.
        let night = Self.date(4, hour: 1)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        #expect(Self.calendar.dayKey(for: night) == "2026-11-4")
        #expect(utc.dayKey(for: night) == "2026-11-3")
    }
}
