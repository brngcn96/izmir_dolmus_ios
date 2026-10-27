import SwiftUI

/// Uygulamanın kök sekmeleri; her sekme kendi navigation stack'ini taşır.
/// Hatlar, tab bar'ın yanında ayrı bir search button olarak durur.
struct MainTabView: View {
    @Environment(Router.self) private var router

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
    }
}
