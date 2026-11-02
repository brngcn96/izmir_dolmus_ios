import StoreKit
import SwiftUI

/// Uygulamanın kök sekmeleri; her sekme kendi navigation stack'ini taşır.
/// Hatlar, tab bar'ın yanında ayrı bir search button olarak durur.
struct MainTabView: View {
    @Environment(Router.self) private var router
    @Environment(ReviewStore.self) private var review
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("Anasayfa", systemImage: "house", value: AppTab.home) {
                RouteStack(tab: .home) { HomeView() }
            }
            Tab("Harita", systemImage: "map", value: AppTab.map) {
                RouteStack(tab: .map) { MapScreen() }
            }
            Tab("Favoriler", systemImage: "star", value: AppTab.favorites) {
                RouteStack(tab: .favorites) { FavoritesView() }
            }
            Tab("Ayarlar", systemImage: "gearshape", value: AppTab.settings) {
                RouteStack(tab: .settings) { SettingsView() }
            }
            // Başlık görünmez ama VoiceOver "Arayın" yerine "Hatlar" okur.
            Tab("Hatlar", systemImage: "magnifyingglass", value: AppTab.hats, role: .search) {
                RouteStack(tab: .hats) { HatListView() }
            }
        }
        // Search tab seçilince arama açılır; kapatılınca önceki tab'a dönülür.
        .tabViewSearchActivation(.searchTabSelection)
        .tabBarMinimizeBehavior(.onScrollDown)
        // "Nereden → Nereye" her sekmeden açılabilir; sonuç Harita'da gösterilir.
        .sheet(item: $router.tripDraft) { draft in
            TripPlannerView(draft: draft)
        }
        // Yol tarifi görülüp haritadan çıkılırken değerlendirme istenebilir. İstek
        // burada: `requestReview` her environment güncellemesinde "değişmiş" sayılıyor,
        // haritada okununca bütün harita içeriği yeniden kuruluyordu.
        .onChange(of: router.selectedTab) { old, _ in
            if old == .map {
                review.mapExited()
            }
        }
        .onChange(of: review.isRequested) { _, isRequested in
            guard isRequested else { return }
            review.requestHandled()
            requestReview()
        }
    }
}
