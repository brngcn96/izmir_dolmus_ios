import DolmusCore
import SwiftUI

/// Favoriler: kullanıcının yıldızladığı hatlar, en son eklenen başta.
struct FavoritesView: View {
    @Environment(DataStore.self) private var store
    @Environment(UserStore.self) private var user
    @Environment(Router.self) private var router

    var body: some View {
        // Veride artık bulunmayan bir hat kimliği sessizce atlanır.
        let hats = user.favoriteHatIDs.compactMap { store.data.hat(id: $0) }

        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(hats) { hat in
                    NavigationLink(value: Route.hat(id: hat.id)) {
                        HatRow(hat: hat, showsFavoriteMark: false)
                            .card()
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Favorilerden çıkar", systemImage: "star.slash", role: .destructive) {
                            user.toggleFavorite(hat.id)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.canvas)
        .overlay {
            if hats.isEmpty {
                ContentUnavailableView {
                    Label("Henüz favori hattın yok", systemImage: "star")
                } description: {
                    Text("Bir hattı açıp yıldıza bas; sık kullandığın hatlar burada toplanır.")
                } actions: {
                    Button("Hatlara göz at") {
                        router.selectedTab = .hats
                    }
                    .buttonStyle(.primary)
                }
            }
        }
        .navigationTitle("Favoriler")
    }
}
