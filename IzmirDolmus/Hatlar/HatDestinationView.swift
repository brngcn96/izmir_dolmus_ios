import DolmusCore
import SwiftUI

/// `Route.hat` hedefinin ekranı: kimlikten hattı bulup detayını gösterir.
struct HatDestinationView: View {
    let hatID: String

    @Environment(DataStore.self) private var store

    var body: some View {
        if let hat = store.data.hat(id: hatID) {
            HatDetailView(hat: hat)
                .safeAreaInset(edge: .bottom) {
                    // Yüzen kontrol içeriğin üstünde durur; yazısı sınırsız
                    // büyürse ekranı kaplar, bu yüzden bir yerde durdurulur.
                    HatActionBar(hat: hat)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .padding(.bottom, 8)
                }
        } else {
            ContentUnavailableView("Hat bulunamadı", systemImage: "bus", description: Text(hatID))
        }
    }
}
