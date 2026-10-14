import DolmusCore
import SwiftUI

/// Anasayfa. İçeriği Faz 7'de gelecek; şimdilik `Router` ile başka bir sekmede
/// ekran açmayı gösteren bir örnek taşıyor.
struct HomeView: View {
    @Environment(DataStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        ContentUnavailableView {
            Label("Anasayfa", systemImage: "house")
        } description: {
            Text("Faz 7'de gelecek.")
        } actions: {
            if let hat = store.data.hat(id: "M41") ?? store.data.hats.first {
                Button("\(hat.name) hattını aç") {
                    router.show(.hat(id: hat.id), in: .hats)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Anasayfa")
    }
}
