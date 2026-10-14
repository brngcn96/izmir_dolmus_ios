import Observation

/// Uygulamanın gezinme durumu: hangi sekme seçili ve her sekmenin yığınında
/// hangi hedefler var. Ekranlar gezinmeyi bu durumu değiştirerek yapar.
@Observable
final class Router {
    var selectedTab: AppTab = .home

    private var paths: [AppTab: [Route]] = [:]

    /// Bir sekmenin gezinme yolu; boş dizi sekmenin kök ekranıdır.
    subscript(tab: AppTab) -> [Route] {
        get { paths[tab, default: []] }
        set { paths[tab] = newValue }
    }

    /// `tab` sekmesine geçer ve kökünün üstünde yalnızca `route`'u gösterir.
    func show(_ route: Route, in tab: AppTab) {
        selectedTab = tab
        self[tab] = [route]
    }
}
