import DolmusCore
import SwiftUI

/// Uygulamanın kökü: açılış animasyonu, ilk açılışta tanıtım, sonra sekmeler.
/// Veri en baştan arka planda yüklenir; animasyon ve tanıtım onu beklemez.
struct RootView: View {
    @Environment(DataStore.self) private var store
    @Environment(FareStore.self) private var fares
    @Environment(UserStore.self) private var user
    @Environment(Router.self) private var router
    @Environment(JourneySession.self) private var journeySession
    @Environment(AdsController.self) private var ads

    /// Tanıtım görüldü mü (Flutter'daki `onboarding_done` bayrağıyla aynı ad).
    @AppStorage("onboarding_done", store: AppEnvironment.defaults) private var isOnboardingDone = false
    @State private var isSplashDone = false
    @State private var widgetSync = WidgetSync()

    var body: some View {
        // `.task` dallara değil, kimliği değişmeyen `ZStack`'e bağlı: durum
        // değişip dal değişse de görev yeniden başlamaz.
        ZStack {
            if !isSplashDone {
                SplashView()
                    .transition(.opacity)
            } else if !isOnboardingDone {
                OnboardingView {
                    isOnboardingDone = true
                }
                .transition(.opacity)
            } else {
                switch store.phase {
                case .idle, .loading:
                    ProgressView("Harita hazırlanıyor…")
                case .failed(let message):
                    ContentUnavailableView(
                        "Veri yüklenemedi",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                case .loaded:
                    MainTabView()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.45), value: isSplashDone)
        .animation(.easeInOut(duration: 0.45), value: isOnboardingDone)
        // Yazı tipini kendisi belirtmeyen bütün metinler Figtree olur.
        .font(.figtree(.body))
        // `App.init` içinde çağrılınca uygulamanın vurgu rengi (AccentColor)
        // sistem mavisine düşüyordu; scene kurulduktan sonra çağrılmalı.
        // Navigation bar'lar sekmelerle birlikte, yani bundan sonra oluşuyor.
        .onAppear {
            Theme.applyNavigationBarFonts()
        }
        .task {
            if isOnboardingDone {
                ads.prepareAtLaunch()
            }
            async let loading: Void = loadData()
            try? await Task.sleep(for: SplashView.duration)
            // İlk açılışta tanıtım hemen gelir (veri arkada yüklenmeye devam
            // eder); sonraki açılışlarda açılış ekranı veri hazır olana kadar kalır.
            if !isOnboardingDone {
                isSplashDone = true
            }
            await loading
            isSplashDone = true
        }
        // Widget'ların girdileri değişince özet yeniden yazılır. Girdi yeniden
        // değişirse önceki görev iptal edilir; 300 ms bekleme arka arkaya gelen
        // değişiklikleri (ör. birkaç favori) tek yazıma indirir.
        .task(id: widgetInputs) {
            guard case .loaded(let data) = store.phase, let widgetInputs else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await widgetSync.update(data: data, inputs: widgetInputs)
        }
        // Widget'a dokununca uygulama `izmirdolmus://…` adresiyle açılır.
        .onOpenURL { url in
            if let link = DeepLink(url: url) {
                ads.noteExternalOpen()
                router.open(link, home: user.home, work: user.work, journey: journeySession.current)
            }
        }
        // Control Center kontrolünün intent'i uygulamada çalışınca bıraktığı istek.
        // `initial: true`: uygulama kontrolle soğuk açıldıysa istek ilk çizimden önce gelmiş olabilir.
        .onChange(of: PendingDeepLink.shared.link, initial: true) { _, link in
            guard let link else { return }
            PendingDeepLink.shared.link = nil
            ads.noteExternalOpen()
            router.open(link, home: user.home, work: user.work, journey: journeySession.current)
        }
        // Tazeleme bitince (ya da iptal edilince) gelen ücretler hatlara yansır.
        .onChange(of: fares.table) {
            store.applyLiveFares(fares.table)
        }
    }

    /// Veri yüklenmeden widget özeti kurulmaz.
    private var widgetInputs: WidgetSync.Inputs? {
        guard case .loaded = store.phase else { return nil }
        return WidgetSync.Inputs(home: user.home, work: user.work, favoriteHatIDs: user.favoriteHatIDs, fares: fares.table)
    }

    private func loadData() async {
        await fares.loadCache()
        await store.load()
        store.applyLiveFares(fares.table)
        // Ücretler 14 günden eskiyse arka planda sessizce tazelenir.
        if fares.isStale {
            fares.refresh(codes: store.data.fareCodes)
        }
    }
}
