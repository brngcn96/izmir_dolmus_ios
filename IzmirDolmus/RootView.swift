import SwiftUI

/// Uygulamanın kökü: veriyi yükler, hazır olunca sekmeleri gösterir.
struct RootView: View {
    @Environment(DataStore.self) private var store

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
        .task {
            await store.load()
        }
    }
}
