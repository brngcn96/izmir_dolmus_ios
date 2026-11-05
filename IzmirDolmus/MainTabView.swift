import StoreKit
import SwiftUI

/// Uygulamanın kök sekmeleri; her sekme kendi navigation stack'ini taşır. Sıra ve adlar
/// Flutter'daki gibi. Hatlar ayrı bir arama düğmesi değil, adı yazılı bir sekme: arama
/// düğmesi açılınca doğrudan klavye çıkıyor, bütün liste görülemiyordu.
///
/// Banner Harita'da yok: haritanın altını sheet'ler ve yolculuk kartı kullanıyor, sheet'in
/// altında kalan reklam görünmez.
struct MainTabView: View {
    @Environment(Router.self) private var router
    @Environment(ReviewStore.self) private var review
    @Environment(AdsController.self) private var ads
    @Environment(JourneySession.self) private var journeySession
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("Anasayfa", systemImage: "house", value: AppTab.home) {
                RouteStack(tab: .home, banner: .always) { HomeView() }
            }
            Tab("Harita", systemImage: "map", value: AppTab.map) {
                RouteStack(tab: .map) { MapScreen() }
            }
            Tab("Hatlar", systemImage: "bus", value: AppTab.hats) {
                RouteStack(tab: .hats, banner: .always) { HatListView() }
            }
            Tab("Favoriler", systemImage: "star", value: AppTab.favorites) {
                RouteStack(tab: .favorites, banner: .collapsible) { FavoritesView() }
            }
            Tab("Ayarlar", systemImage: "gearshape", value: AppTab.settings) {
                RouteStack(tab: .settings, banner: .always) { SettingsView() }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        // "Nereden → Nereye" her sekmeden açılabilir; sonuç Harita'da gösterilir. Zemin
        // opak: yarı saydam sheet'in arkasında bulanık harita yazıları okunaksız yapıyordu.
        .sheet(item: $router.tripDraft) { draft in
            TripPlannerView(draft: draft)
                .presentationBackground(Color.canvas)
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
        // Sekmeler göründüğünde ve uygulama her öne geldiğinde: rıza, izleme izni, App Open.
        // Yolculuk sürerken App Open yok: kullanıcı adımlarına dönüyor.
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            ads.appDidBecomeActive(allowsAppOpen: journeySession.current == nil)
        }
    }
}
