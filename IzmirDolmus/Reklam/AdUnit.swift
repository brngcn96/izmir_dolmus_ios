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
    static let banner = "ca-app-pub-1446443793128054/6289600733"
    static let collapsibleBanner = banner
    static let appOpen = "ca-app-pub-1446443793128054/4007052329"
    static let interstitial = "ca-app-pub-1446443793128054/6577375343"
    #endif
}
