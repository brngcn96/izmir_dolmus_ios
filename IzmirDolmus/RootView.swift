import DolmusCore
import SwiftUI

/// Uygulamanın kökü: veriyi yükler, hazır olunca sekmeleri gösterir.
struct RootView: View {
    @Environment(DataStore.self) private var store
    @Environment(FareStore.self) private var fares

    var body: some View {
        // `.task` dallara değil, kimliği değişmeyen `ZStack`'e bağlı: durum
        // değişip dal değişse de görev yeniden başlamaz.
        ZStack {
            switch store.phase {
            case .idle, .loading:
                ProgressView("Hatlar yükleniyor…")
            case .failed(let message):
                ContentUnavailableView(
                    "Veri yüklenemedi",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .loaded:
                MainTabView()
            }
        }
        // Yazı tipini kendisi belirtmeyen bütün metinler Figtree olur.
        .font(.figtree(.body))
        // `App.init` içinde çağrılınca uygulamanın vurgu rengi (AccentColor)
        // sistem mavisine düşüyordu; scene kurulduktan sonra çağrılmalı.
        // Navigation bar'lar sekmelerle birlikte, yani bundan sonra oluşuyor.
        .onAppear {
            Theme.applyNavigationBarFonts()
        }
        .task {
            await fares.loadCache()
            await store.load()
            store.applyLiveFares(fares.table)
            // Ücretler 14 günden eskiyse arka planda sessizce tazelenir.
            if fares.isStale {
                fares.refresh(codes: store.data.fareCodes)
            }
        }
        // Tazeleme bitince (ya da iptal edilince) gelen ücretler hatlara yansır.
        .onChange(of: fares.table) {
            store.applyLiveFares(fares.table)
        }
    }
}
