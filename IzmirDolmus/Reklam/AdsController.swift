import AppTrackingTransparency
import CoreLocation
import DolmusCore
import Foundation
import GoogleMobileAds
import Observation
import UIKit
import UserMessagingPlatform

/// Reklamların yöneticisi (Flutter'daki `AdsService`): rıza, izleme izni, SDK'nın
/// başlatılması, App Open ve geçiş reklamları. Ne zaman gösterileceği `AdPolicy`'de.
///
/// Sıra: rıza bilgisi (oturumda bir kez; AB'de gerekirse Google'ın rıza formu, Türkiye'de
/// form çıkmaz) → izleme izni (bir kez sorulur) → SDK'nın başlatılması (banner'lar bundan
/// sonra yüklenir) → App Open. Tanıtımı geçmiş kullanıcıda rıza, SDK ve ön yükleme açılış
/// ekranında başlar; izleme izni ve App Open sekmeler görününce. UI testlerinde hiçbiri
/// çalışmaz, banner'lar görünmez.
@Observable
final class AdsController: NSObject {
    /// SDK başladı ve rıza reklama izin veriyor: banner'lar yalnızca bu açıkken istenir.
    private(set) var canRequestAds = false
    /// AB'de rızayı değiştirme seçeneği sunulmalı (Ayarlar › Hakkında).
    private(set) var isPrivacyOptionsRequired = false

    private let isEnabled: Bool
    private let defaults: UserDefaults
    private var policy: AdPolicy {
        didSet { save() }
    }

    private var consentUpdate: Task<Void, Never>?
    private var isRequestingTracking = false
    /// Son izin penceresinin (rıza formu, izleme izni) açıldığı an: o öne gelişte App Open yok.
    private var lastPromptAt: Date?
    /// Uygulamanın bir adresle açıldığı an (widget, Live Activity, Control Center).
    private var externalOpenAt: Date?

    private var appOpen: AppOpenAd?
    private var appOpenLoadedAt: Date?
    /// App Open'ın istendiği öne geliş; reklam `AdPolicy.appOpenWait` içinde gelirse gösterilir.
    private var appOpenRequestedAt: Date?
    private var isLoadingAppOpen = false

    private var interstitial: InterstitialAd?
    private var isLoadingInterstitial = false

    private var isShowingFullScreen = false

    init(isEnabled: Bool = !AppEnvironment.isUITesting && !AppEnvironment.isAdFree, defaults: UserDefaults = AppEnvironment.defaults) {
        self.isEnabled = isEnabled
        self.defaults = defaults
        policy = AdPolicy(
            isFirstLaunchDone: defaults.bool(forKey: Keys.firstLaunchDone),
            appOpenDay: defaults.string(forKey: Keys.appOpenDay),
            interstitialDay: defaults.string(forKey: Keys.interstitialDay)
        )
        super.init()
    }

    /// Açılış ekranı sırasında (tanıtım daha önce geçildiyse): rıza bilgisi, SDK ve bugün
    /// gösterilebilecek tam ekran reklamların yüklenmesi başlar; App Open sekmeler
    /// görününce hazır olsun (Flutter'da da açılışta yükleniyordu). İzleme izni burada
    /// sorulmaz, App Open burada gösterilmez.
    func prepareAtLaunch() {
        guard isEnabled else { return }
        Task {
            await updateConsent()
            startIfAllowed()
            guard canRequestAds else { return }
            loadIfNeeded()
        }
    }

    /// Sekmeler göründü ya da uygulama öne geldi.
    /// - Parameter allowsAppOpen: yolculuk sürerken `false`; kullanıcı adımlarına dönüyor.
    func appDidBecomeActive(allowsAppOpen: Bool) {
        guard isEnabled else { return }
        policy.noteAppActive()
        let activatedAt = Date.now
        Task {
            await updateConsent()
            await requestTrackingIfNeeded()
            startIfAllowed()
            guard canRequestAds else { return }
            loadIfNeeded()
            guard allowsAppOpen, !wasInterrupted(since: activatedAt) else { return }
            showAppOpenIfAllowed(requestedAt: activatedAt)
        }
    }

    /// Uygulama bir adresle açıldı: bu öne gelişte App Open yok, kullanıcı bir şey istiyor.
    func noteExternalOpen() {
        externalOpenAt = .now
    }

    /// Kullanıcı bir ekrandan geri döndü (geri düğmesi ya da kaydırma).
    func didNavigateBack() {
        guard canRequestAds, !isShowingFullScreen, policy.canShowInterstitial(now: .now) else { return }
        guard let ad = interstitial else {
            // Henüz yok: bu sefer atlanır, sonrakine hazırlanır.
            loadInterstitial()
            return
        }
        Task {
            // Geri animasyonu bitsin.
            try? await Task.sleep(for: .milliseconds(350))
            guard interstitial === ad, !isShowingFullScreen, policy.canShowInterstitial(now: .now),
                  UIApplication.shared.applicationState == .active
            else { return }
            interstitial = nil
            isShowingFullScreen = true
            ad.present(from: nil)
        }
    }

    /// AB'de rızayı değiştirme formu (Ayarlar).
    func presentPrivacyOptions() async {
        try? await ConsentForm.presentPrivacyOptionsForm(from: nil)
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        startIfAllowed()
    }

    // MARK: Rıza, izleme izni, başlatma

    /// Rıza bilgisi oturumda bir kez tazelenir; AB'de gerekiyorsa form gösterilir. Ağ yoksa
    /// ya da AdMob'da form kurulmamışsa önceki rıza geçerli kalır, sonraki öne gelişte
    /// yeniden denenir.
    private func updateConsent() async {
        if consentUpdate == nil {
            consentUpdate = Task {
                do {
                    try await ConsentInformation.shared.requestConsentInfoUpdate(with: nil)
                    if ConsentInformation.shared.consentStatus == .required {
                        lastPromptAt = .now
                    }
                    try await ConsentForm.loadAndPresentIfRequired(from: nil)
                } catch {
                    consentUpdate = nil
                }
                isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
            }
        }
        await consentUpdate?.value
    }

    /// İzleme izni bir kez sorulur. Konum izni henüz sorulmadıysa (ilk açılış) beklenir:
    /// başka bir izin penceresi açıkken sistem bu pencereyi göstermez; sonraki öne gelişte
    /// yeniden denenir.
    private func requestTrackingIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined,
              CLLocationManager().authorizationStatus != .notDetermined,
              UIApplication.shared.applicationState == .active,
              !isRequestingTracking
        else { return }
        isRequestingTracking = true
        let status = await ATTrackingManager.requestTrackingAuthorization()
        isRequestingTracking = false
        if status != .notDetermined {
            lastPromptAt = .now
        }
    }

    private func startIfAllowed() {
        guard !canRequestAds, ConsentInformation.shared.canRequestAds else { return }
        // Uygulamanın yaş sınırı 4+: reklamlar da genel izleyiciye uygun olanlarla sınırlı.
        MobileAds.shared.requestConfiguration.maxAdContentRating = .general
        MobileAds.shared.start(completionHandler: nil)
        canRequestAds = true
    }

    /// Bu öne gelişte bir izin penceresi açıldı ya da uygulama bir adresle açıldı mı?
    private func wasInterrupted(since activatedAt: Date) -> Bool {
        if let lastPromptAt, lastPromptAt >= activatedAt {
            return true
        }
        // Soğuk açılışta adres, sekmeler görünmeden (açılış ekranında) gelir.
        if let externalOpenAt, Date.now.timeIntervalSince(externalOpenAt) < 30 {
            self.externalOpenAt = nil
            return true
        }
        return false
    }

    // MARK: Tam ekran reklamlar

    /// Bugün gösterilebilecek tam ekran reklamlar önceden yüklenir.
    private func loadIfNeeded() {
        if policy.shouldLoadAppOpen(now: .now) {
            loadAppOpen()
        }
        if policy.shouldLoadInterstitial(now: .now) {
            loadInterstitial()
        }
    }

    private func showAppOpenIfAllowed(requestedAt: Date) {
        guard !isShowingFullScreen, policy.canShowAppOpen(now: .now) else { return }
        if let loadedAt = appOpenLoadedAt, !AdPolicy.isFresh(loadedAt: loadedAt, now: .now) {
            appOpen = nil
            appOpenLoadedAt = nil
        }
        appOpenRequestedAt = requestedAt
        if appOpen != nil {
            presentAppOpen()
        } else {
            loadAppOpen()
        }
    }

    private func loadAppOpen() {
        guard canRequestAds, appOpen == nil, !isLoadingAppOpen else { return }
        isLoadingAppOpen = true
        Task {
            let ad = try? await AppOpenAd.load(with: AdUnit.appOpen, request: Request())
            isLoadingAppOpen = false
            guard let ad else { return }
            ad.fullScreenContentDelegate = self
            appOpen = ad
            appOpenLoadedAt = .now
            // Gösterim beklenirken zamanında geldiyse hemen; geç kaldıysa sonraki öne gelişe kalır.
            if let appOpenRequestedAt, AdPolicy.isInTime(requestedAt: appOpenRequestedAt, now: .now) {
                presentAppOpen()
            }
        }
    }

    private func presentAppOpen() {
        guard let ad = appOpen, !isShowingFullScreen, policy.canShowAppOpen(now: .now),
              UIApplication.shared.applicationState == .active
        else { return }
        appOpen = nil
        appOpenLoadedAt = nil
        appOpenRequestedAt = nil
        isShowingFullScreen = true
        ad.present(from: nil)
    }

    private func loadInterstitial() {
        guard canRequestAds, interstitial == nil, !isLoadingInterstitial else { return }
        isLoadingInterstitial = true
        Task {
            let ad = try? await InterstitialAd.load(with: AdUnit.interstitial, request: Request())
            isLoadingInterstitial = false
            guard let ad else { return }
            ad.fullScreenContentDelegate = self
            interstitial = ad
        }
    }

    private func save() {
        defaults.set(policy.isFirstLaunchDone, forKey: Keys.firstLaunchDone)
        defaults.set(policy.appOpenDay, forKey: Keys.appOpenDay)
        defaults.set(policy.interstitialDay, forKey: Keys.interstitialDay)
    }

    /// Flutter sürümündeki adlar (veri paylaşılmıyor; adlar tutarlılık için).
    private enum Keys {
        static let firstLaunchDone = "ad_first_launch_done"
        static let appOpenDay = "ad_appopen_day"
        static let interstitialDay = "ad_back_day"
    }
}

extension AdsController: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: any FullScreenPresentingAd) {
        if ad is AppOpenAd {
            policy.noteAppOpenShown(now: .now)
        } else {
            policy.noteInterstitialShown(now: .now)
        }
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        isShowingFullScreen = false
        policy.noteFullScreenDismissed(now: .now)
    }

    /// Gösterilemedi: gün kilitlenmez, yenisi hazırlanır.
    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        isShowingFullScreen = false
        if ad is AppOpenAd {
            loadAppOpen()
        } else {
            loadInterstitial()
        }
    }
}
