/// AdMob reklam birimleri. Debug'da Google'ın test birimleri: gerçek reklam istenmez,
/// tıklamak güvenlidir. Release'te İzmir Dolmuş'un iOS birimleri; TestFlight'tan kurulan
/// sürümde de gerçek reklam gelir, kendi reklamına tıklama. Uygulama kimliği Info.plist'te
/// (`GADApplicationIdentifier`, yapı ayarı `ADMOB_APP_ID`).
enum AdUnit {
    #if DEBUG
    static let banner = "ca-app-pub-3940256099942544/2435281174"
    /// Google'ın collapsible örneğindeki test birimi; Release'te normal banner birimi
    /// `collapsible` parametresiyle istenir (Flutter'daki gibi, ayrı birim gerekmez).
    static let collapsibleBanner = "ca-app-pub-3940256099942544/8388050270"
    static let appOpen = "ca-app-pub-3940256099942544/5575463023"
    static let interstitial = "ca-app-pub-3940256099942544/4411468910"
    #else
    // AdMob'da iOS uygulaması ve birimleri henüz yok (2026-11-04). Kimlikler girilene kadar
    // Release bilerek derlenmez: test birimleri ya da yer tutucular yayına çıkmasın.
    #error("AdMob kimlikleri eksik: buraya banner, App Open ve geçiş birimlerini; proje ayarlarında Release'in ADMOB_APP_ID'sine uygulama kimliğini gir.")
    #endif
}
