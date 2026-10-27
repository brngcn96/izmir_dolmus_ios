import Foundation

/// Bir noktanın yakınından geçen hat ve o noktaya uzaklığı.
public struct NearbyHat: Sendable, Equatable, Identifiable {
    public let hat: DolmusHat
    /// Hattın binilebilir en yakın noktasına düz uzaklık (m).
    public let meters: Double

    public var id: String { hat.id }
}

extension DolmusData {
    /// Noktaya `maxMeters` içinden geçen hatlar, yakından uzağa.
    ///
    /// Uzaklık resmi güzergah çizgisinin binilebilir parçalarına göredir
    /// (otoyol parçaları sayılmaz). Geometrisi olmayan hat atlanır.
    public func nearbyHats(to point: Coordinate, maxMeters: Double = 800, limit: Int = 25) -> [NearbyHat] {
        var result: [NearbyHat] = []
        for hat in hats {
            var best = Double.infinity
            for geom in geoms(for: hat.id) {
                if let hit = geom.nearestBoardable(to: point), hit.meters < best {
                    best = hit.meters
                }
            }
            if best <= maxMeters {
                result.append(NearbyHat(hat: hat, meters: best))
            }
        }
        result.sort { $0.meters < $1.meters }
        return Array(result.prefix(limit))
    }

    /// Hattın, noktaya en yakın güzergahının sırası (`geoms(for:)` içinde).
    /// Hat bir yerden açıldığında önce o noktaya yakın güzergah gösterilir.
    public func nearestGeomIndex(of hatID: String, to point: Coordinate) -> Int {
        var bestIndex = 0
        var best = Double.infinity
        for (index, geom) in geoms(for: hatID).enumerated() {
            if let hit = geom.nearestBoardable(to: point), hit.meters < best {
                best = hit.meters
                bestIndex = index
            }
        }
        return bestIndex
    }

    /// Haritaya çizilmiş hat çizgilerinden (her hattın ilk güzergahı) `point`'in
    /// `toleranceMeters` yakınından geçenler, verilen sırayla. Çizgiye dokunmayı
    /// tanımak için: üst üste binen hatların hepsi döner.
    public func hats(onLinesOf hatIDs: [String], near point: Coordinate, toleranceMeters: Double) -> [DolmusHat] {
        hatIDs.compactMap { id in
            guard let line = geoms(for: id).first?.points,
                  point.distance(toLine: line) <= toleranceMeters
            else { return nil }
            return hat(id: id)
        }
    }

    /// Görünür alanda çizilecek noktalar: zoom eşiğini geçenler; önce öncelik,
    /// sonra kutunun merkezine yakınlık; en çok `limit` tane.
    public func poisInView(_ box: GeoBox, zoom: Double, limit: Int = 160) -> [MapPoi] {
        let center = box.center
        var hits: [MapPoi] = []
        for la in PoiRules.cellIndex(box.south)...PoiRules.cellIndex(box.north) {
            for lo in PoiRules.cellIndex(box.west)...PoiRules.cellIndex(box.east) {
                guard let cell = poiGrid[la * 100_000 + lo] else { continue }
                for index in cell {
                    let poi = pois[index]
                    if zoom < poi.minZoom || !box.contains(poi.coordinate) { continue }
                    hits.append(poi)
                }
            }
        }
        func distanceSquared(_ poi: MapPoi) -> Double {
            let dy = poi.coordinate.latitude - center.latitude
            let dx = poi.coordinate.longitude - center.longitude
            return dy * dy + dx * dx
        }
        hits.sort { a, b in
            a.priority != b.priority ? a.priority > b.priority : distanceSquared(a) < distanceSquared(b)
        }
        return Array(hits.prefix(limit))
    }

    /// Verilen türlerdeki yerler; `near` verilirse ona uzaklığa göre, yoksa ada
    /// göre sıralı. Aynı ad ve aynı konum (4 ondalık) tekrarları elenir.
    public func placesInCategory(_ types: Set<String>, near: Coordinate?, limit: Int = 80) -> [PlacePoint] {
        var seen: Set<String> = []
        var hits: [(poi: MapPoi, meters: Double)] = []
        for poi in pois where types.contains(poi.type) {
            let key = "\(poi.label)|\(String(format: "%.4f", poi.coordinate.latitude))"
            guard seen.insert(key).inserted else { continue }
            hits.append((poi, near.map { $0.meters(to: poi.coordinate) } ?? 0))
        }
        if near != nil {
            hits.sort { $0.meters < $1.meters }
        } else {
            hits.sort { $0.poi.label.dartPrecedes($1.poi.label) }
        }
        return hits.prefix(limit).map { PlacePoint(label: $0.poi.label, coordinate: $0.poi.coordinate) }
    }

    /// Haritada çizilecek bütün noktaların dizini: önce önemli noktalar, sonra
    /// sözlük yerleri. Sokak adları alınmaz (altlık zaten yazıyor).
    static func buildPois(landmarks: [Landmark], duraklar: [PlacePoint], durakKinds: [String]) -> (pois: [MapPoi], grid: [Int: [Int]]) {
        var pois: [MapPoi] = []
        func add(_ label: String, _ coordinate: Coordinate, _ type: String) {
            pois.append(MapPoi(
                id: pois.count,
                label: label,
                coordinate: coordinate,
                type: type,
                minZoom: PoiRules.minZoom(for: type),
                priority: PoiRules.priority(for: type)
            ))
        }
        for landmark in landmarks {
            add(landmark.name, landmark.coordinate, landmark.kind)
        }
        for (place, kind) in zip(duraklar, durakKinds) where kind != "cadde" {
            add(place.label, place.coordinate, kind)
        }
        var grid: [Int: [Int]] = [:]
        for poi in pois {
            grid[PoiRules.cellKey(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude), default: []].append(poi.id)
        }
        return (pois, grid)
    }
}
