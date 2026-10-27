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

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router[tab]) {
            root
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .hat(let id):
                        HatDestinationView(hatID: id)
                    case .events:
                        EventsView()
                    case .event(let id):
                        EventDestinationView(eventID: id)
                    }
                }
        }
    }
}
