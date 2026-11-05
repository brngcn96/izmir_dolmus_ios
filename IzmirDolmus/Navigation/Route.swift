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
    case licenses
}

/// Bir sekmenin gezinme yığını: `Route` değerlerini ekranlara çevirir. Ekranların
/// altında, tab bar'ın hemen üstünde banner reklam durabilir.
struct RouteStack<Root: View>: View {
    let tab: AppTab
    /// Banner reklamın yeri; `nil` ise bu sekmede banner yok.
    var banner: BannerPlacement?
    @ViewBuilder var root: Root

    @Environment(Router.self) private var router
    @Environment(AdsController.self) private var ads
    /// Zoom geçişlerinin kaynakları ve hedefleri bu ad alanında eşleşir.
    @Namespace private var transitions

    var body: some View {
        // Banner her ekranın kendisinde, yığının dışında değil: dışarıdaki boşluğu itilen
        // ekranlar hesaba katmıyor, hat detayındaki "Haritada göster" çubuğu banner'ın
        // arkasında kalıyordu.
        NavigationStack(path: path) {
            root
                .adBanner(banner != nil, isCollapsible: banner == .collapsible)
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
        .environment(\.routeTransitions, transitions)
    }

    /// Zoom yalnızca kaynağı belli hedeflerde: Anasayfa'daki etkinlik kartı → Etkinlikler,
    /// etkinlik kartı → detay. Banner geçişten önce eklenir; geçiş ekranın kökünde kalır.
    @ViewBuilder
    private func destination(for route: Route) -> some View {
        let showsBanner = banner != nil
        switch route {
        case .hat(let id):
            HatDestinationView(hatID: id)
                .adBanner(showsBanner)
        case .events:
            EventsView()
                .adBanner(showsBanner)
                .navigationTransition(.zoom(sourceID: route, in: transitions))
        case .event(let id):
            EventDestinationView(eventID: id)
                .adBanner(showsBanner)
                .navigationTransition(.zoom(sourceID: route, in: transitions))
        case .licenses:
            LicensesView()
                .adBanner(showsBanner)
        }
    }

    /// Yığının yolu. Kullanıcı geri gidince (geri düğmesi, kaydırma, sekmeye yeniden
    /// dokunma) yol bu bağlantıdan kısalır ve geçiş reklamı denenir; uygulamanın kendi
    /// gezinmesi (`Router`'ın metotları, dışarıdan gelen adresler) bu bağlantıdan geçmez.
    private var path: Binding<[Route]> {
        Binding {
            router[tab]
        } set: { newPath in
            let isBack = newPath.count < router[tab].count
            router[tab] = newPath
            if isBack {
                ads.didNavigateBack()
            }
        }
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
