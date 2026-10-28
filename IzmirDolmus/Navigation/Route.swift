import SwiftUI

/// Bir gezinme yığınına itilebilen hedefler.
///
/// Hedef bir ekran değil, o ekranı tarif eden küçük bir değerdir: yığının
/// durumu `[Route]` dizisinden ibarettir. Hattın kendisi yerine kimliği
/// taşınır; ekran açılırken güncel veriden bulunur.
enum Route: Hashable {
    case hat(id: String)
    case events
    case event(id: String)
}

/// Bir sekmenin gezinme yığını: `Route` değerlerini ekranlara çevirir.
struct RouteStack<Root: View>: View {
    let tab: AppTab
    @ViewBuilder var root: Root

    @Environment(Router.self) private var router
    /// Zoom geçişlerinin kaynakları ve hedefleri bu ad alanında eşleşir.
    @Namespace private var transitions

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router[tab]) {
            root
                .navigationDestination(for: Route.self) { route in
                    // Zoom yalnızca kaynağı belli hedeflerde: Anasayfa'daki
                    // etkinlik kartı → Etkinlikler, etkinlik kartı → detay.
                    switch route {
                    case .hat(let id):
                        HatDestinationView(hatID: id)
                    case .events:
                        EventsView()
                            .navigationTransition(.zoom(sourceID: route, in: transitions))
                    case .event(let id):
                        EventDestinationView(eventID: id)
                            .navigationTransition(.zoom(sourceID: route, in: transitions))
                    }
                }
        }
        .environment(\.routeTransitions, transitions)
    }
}

extension EnvironmentValues {
    /// İçinde bulunulan `RouteStack`'in zoom geçişi ad alanı.
    @Entry var routeTransitions: Namespace.ID?
}

extension View {
    /// Bu view'ı `route`'a giden zoom geçişinin kaynağı yapar (bkz. `RouteStack`).
    @ViewBuilder
    func routeTransitionSource(_ route: Route, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedTransitionSource(id: route, in: namespace)
        } else {
            self
        }
    }
}
