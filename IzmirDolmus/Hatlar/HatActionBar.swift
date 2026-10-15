import DolmusCore
import SwiftUI

/// Hat detail'inin altında yüzen Liquid Glass kontroller: favori ve
/// "Haritada göster".
struct HatActionBar: View {
    let hat: DolmusHat

    @Environment(UserStore.self) private var user
    @Environment(Router.self) private var router

    var body: some View {
        let isFavorite = user.isFavorite(hat.id)

        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 12) {
                Button {
                    user.toggleFavorite(hat.id)
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(isFavorite ? Color.yellow : Color.primary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 52, height: 52)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel(isFavorite ? "Favorilerden çıkar" : "Favorilere ekle")

                Button {
                    router.selectedTab = .map
                } label: {
                    Label("Haritada göster", systemImage: "map")
                        .font(.figtree(.headline, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 52)
                }
                .glassEffect(.regular.tint(.accent).interactive(), in: .capsule)
            }
        }
    }
}
