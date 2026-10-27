import DolmusCore
import Observation

/// Haritada gösterilecek şey: başka sekmelerden "Haritada göster".
enum MapRequest: Equatable {
    case hat(id: String)
    case place(PlacePoint)
}

/// Uygulamanın gezinme durumu: hangi sekme seçili ve her sekmenin yığınında
/// hangi hedefler var. Ekranlar gezinmeyi bu durumu değiştirerek yapar.
@Observable
final class Router {
    var selectedTab: AppTab = .home

    private var paths: [AppTab: [Route]] = [:]

    /// Harita sekmesinin henüz işlemediği istek; harita görünce tüketir.
    var mapRequest: MapRequest?
    /// Harita başka bir sekmeden açıldıysa, harita boşaltılınca dönülecek sekme.
    var mapReturnTab: AppTab?

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

    /// Harita sekmesine geçip `request`'i gösterir; haritanın yığınını köke indirir.
    func showOnMap(_ request: MapRequest) {
        mapReturnTab = selectedTab == .map ? nil : selectedTab
        mapRequest = request
        self[.map] = []
        selectedTab = .map
    }
}
