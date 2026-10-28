import DolmusCore
import SwiftUI

/// Uygulamanın kökü: açılış animasyonu, ilk açılışta tanıtım, sonra sekmeler.
/// Veri en baştan arka planda yüklenir; animasyon ve tanıtım onu beklemez.
struct RootView: View {
    @Environment(DataStore.self) private var store
    @Environment(FareStore.self) private var fares

    /// Tanıtım görüldü mü (Flutter'daki `onboarding_done` bayrağıyla aynı ad).
    @AppStorage("onboarding_done") private var isOnboardingDone = false
    @State private var isSplashDone = false

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
        // Tazeleme bitince (ya da iptal edilince) gelen ücretler hatlara yansır.
        .onChange(of: fares.table) {
            store.applyLiveFares(fares.table)
        }
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
