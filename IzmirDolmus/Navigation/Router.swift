import DolmusCore
import Foundation
import Observation

/// Haritada gösterilecek şey: başka sekmelerden "Haritada göster" ya da yol tarifi.
enum MapRequest: Equatable {
    case hat(id: String)
    case place(PlacePoint)
    case trip(from: PlacePoint, to: PlacePoint)
}

/// "Nereden → Nereye" sayfasının başlangıç değerleri.
struct TripDraft: Identifiable {
    let id = UUID()
    var from: PlacePoint?
    var to: PlacePoint?
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
    /// Açık "Nereden → Nereye" sayfası; `nil` ise kapalı.
    var tripDraft: TripDraft?

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

    /// "Nereden → Nereye" sayfasını açar; verilen uçlar dolu gelir.
    func planTrip(from: PlacePoint? = nil, to: PlacePoint? = nil) {
        tripDraft = TripDraft(from: from, to: to)
    }

    /// Harita sekmesine geçip `request`'i gösterir; haritanın yığınını köke indirir.
    /// Haritanın içinden gelen istek (ör. yol tarifini düzenleme) dönülecek sekmeyi
    /// değiştirmez: Anasayfa'dan açılan tarif düzenlense de "geri" Anasayfa'ya döner.
    func showOnMap(_ request: MapRequest) {
        if selectedTab != .map {
            mapReturnTab = selectedTab
        }
        mapRequest = request
        self[.map] = []
        selectedTab = .map
    }
}
