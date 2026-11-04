import Foundation

/// Tam ekran reklamların kuralları (Flutter'daki `AdsService`): App Open uygulama öne
/// gelince, geçiş reklamı kullanıcı bir ekrandan geri dönünce gösterilir; ikisi de
/// günde en çok bir kez. Kurulumdan sonraki ilk oturumda tam ekran reklam yoktur ve iki
/// tam ekran reklam arasında en az `gap` bırakılır.
///
/// App Open, Google'ın açılış için tasarladığı biçimdir; geçiş reklamı açılışta
/// "beklenmedik reklam" sayılabileceği için yalnızca doğal bir geçiş anında, geri
/// dönüşte gösterilir.
///
/// İlk açılış bayrağı ve gün anahtarları kalıcıdır; gerisi oturumluktur (uygulama
/// süreci boyunca).
public struct AdPolicy: Sendable, Equatable {
    /// İki tam ekran reklam arası en az bu kadar: App Open ile geçiş reklamı üst üste
    /// binmez, reklam kapanınca gelen öne geliş yeni reklam açmaz.
    public static let gap: TimeInterval = 90
    /// App Open, istendikten sonra bu süre içinde hazır olursa gösterilir; daha geç
    /// gelirse kullanıcı uygulamayı kullanmaya başlamıştır, reklam sonraki öne gelişe kalır.
    public static let appOpenWait: TimeInterval = 4
    /// Yüklenmiş App Open reklamı bu süreden sonra kullanılmaz (Google'ın sınırı).
    public static let appOpenLifetime: TimeInterval = 4 * 3600

    /// Uygulama en az bir kez sekmelere kadar açıldı (kalıcı).
    public private(set) var isFirstLaunchDone: Bool
    /// App Open'ın ve geçiş reklamının son gösterildiği gün (kalıcı).
    public private(set) var appOpenDay: String?
    public private(set) var interstitialDay: String?

    /// Kurulumdan sonraki ilk oturum: tam ekran reklam yok.
    public let isFirstSession: Bool
    public private(set) var isAppOpenShownThisSession = false
    /// Son tam ekran reklamın gösterildiği ya da kapandığı an.
    public private(set) var lastFullScreen: Date?

    public init(isFirstLaunchDone: Bool = false, appOpenDay: String? = nil, interstitialDay: String? = nil) {
        self.isFirstLaunchDone = isFirstLaunchDone
        self.appOpenDay = appOpenDay
        self.interstitialDay = interstitialDay
        isFirstSession = !isFirstLaunchDone
    }

    /// Sekmeler göründü ya da uygulama öne geldi: ilk açılış kaydedilir.
    public mutating func noteAppActive() {
        isFirstLaunchDone = true
    }

    /// App Open şimdi gösterilebilir mi? Oturumda en çok bir kez.
    public func canShowAppOpen(now: Date, calendar: Calendar = .current) -> Bool {
        guard !isFirstSession, !isAppOpenShownThisSession,
              appOpenDay != calendar.dayKey(for: now)
        else { return false }
        return isGapOver(now: now)
    }

    /// Geri dönüşte geçiş reklamı şimdi gösterilebilir mi?
    public func canShowInterstitial(now: Date, calendar: Calendar = .current) -> Bool {
        guard !isFirstSession, interstitialDay != calendar.dayKey(for: now) else { return false }
        return isGapOver(now: now)
    }

    /// Bugün gösterilmeyecek reklam hiç istenmez: istek sayısı gösterime yakın kalır.
    public func shouldLoadAppOpen(now: Date, calendar: Calendar = .current) -> Bool {
        !isFirstSession && appOpenDay != calendar.dayKey(for: now)
    }

    public func shouldLoadInterstitial(now: Date, calendar: Calendar = .current) -> Bool {
        !isFirstSession && interstitialDay != calendar.dayKey(for: now)
    }

    /// Gün yalnızca reklam gerçekten gösterilince kilitlenir; gösterilemezse sonraki
    /// fırsat kaçmaz.
    public mutating func noteAppOpenShown(now: Date, calendar: Calendar = .current) {
        isAppOpenShownThisSession = true
        appOpenDay = calendar.dayKey(for: now)
        lastFullScreen = now
    }

    public mutating func noteInterstitialShown(now: Date, calendar: Calendar = .current) {
        interstitialDay = calendar.dayKey(for: now)
        lastFullScreen = now
    }

    /// Bekleme süresi reklam kapandığında yeniden başlar.
    public mutating func noteFullScreenDismissed(now: Date) {
        lastFullScreen = now
    }

    /// Yüklenmiş App Open hâlâ kullanılabilir mi?
    public static func isFresh(loadedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(loadedAt) <= appOpenLifetime
    }

    /// Yüklenen App Open, istendiği andan sonra zamanında mı geldi?
    public static func isInTime(requestedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(requestedAt) <= appOpenWait
    }

    private func isGapOver(now: Date) -> Bool {
        guard let lastFullScreen else { return true }
        return now.timeIntervalSince(lastFullScreen) >= Self.gap
    }
}
