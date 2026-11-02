import DolmusCore
import Foundation
import Observation

/// Kullanıcının cihazda saklanan tercihleri: favori hatlar, Ev/İş adresleri ve
/// son aranan yerler. Her değişiklik anında `UserDefaults`'a yazılır.
@Observable
final class UserStore {
    /// Favori hatların kimlikleri, en son eklenen başta.
    private(set) var favoriteHatIDs: [String] {
        didSet { defaults.set(favoriteHatIDs, forKey: Keys.favorites) }
    }

    var home: PlacePoint? {
        didSet { defaults.setCodable(home, forKey: Keys.home) }
    }

    var work: PlacePoint? {
        didSet { defaults.setCodable(work, forKey: Keys.work) }
    }

    /// Son aranan yerler, en yenisi başta.
    private(set) var recentPlaces: [PlacePoint] {
        didSet { defaults.setCodable(recentPlaces, forKey: Keys.recents) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppEnvironment.defaults) {
        self.defaults = defaults
        favoriteHatIDs = defaults.stringArray(forKey: Keys.favorites) ?? []
        home = defaults.codable(PlacePoint.self, forKey: Keys.home)
        work = defaults.codable(PlacePoint.self, forKey: Keys.work)
        recentPlaces = defaults.codable([PlacePoint].self, forKey: Keys.recents) ?? []
    }

    func isFavorite(_ hatID: String) -> Bool {
        favoriteHatIDs.contains(hatID)
    }

    /// Favori değilse başa ekler, favoriyse çıkarır.
    func toggleFavorite(_ hatID: String) {
        if let index = favoriteHatIDs.firstIndex(of: hatID) {
            favoriteHatIDs.remove(at: index)
        } else {
            favoriteHatIDs.insert(hatID, at: 0)
        }
    }

    /// Yeri listenin başına koyar; aynı adlı eski kaydı siler, en çok 8 tane tutar.
    func addRecent(_ place: PlacePoint) {
        var places = recentPlaces.filter { trNorm($0.label) != trNorm(place.label) }
        places.insert(place, at: 0)
        recentPlaces = Array(places.prefix(8))
    }

    func clearRecents() {
        recentPlaces = []
    }

    /// Flutter sürümündeki anahtarlarla aynı (veri iki uygulama arasında
    /// paylaşılmıyor; adlar yalnızca tutarlılık için).
    private enum Keys {
        static let favorites = "fav_hats_v1"
        static let home = "place_home_v1"
        static let work = "place_work_v1"
        static let recents = "recent_places_v1"
    }
}
