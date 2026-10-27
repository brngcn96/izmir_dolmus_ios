import Foundation

/// Küçük alanlarda düzlem yaklaşımıyla mesafe hesapları (Flutter'daki
/// `Repository._segProj`, `minDistanceToLine`, `nearestBoardable`).
enum PlanarGeometry {
    static let metersPerDegreeLatitude = 111_320.0

    /// `p`'nin `a`–`b` parçasına uzaklığı (m), en yakın noktanın parça üzerindeki
    /// oranı (0…1) ve parçanın uzunluğu (m).
    static func project(_ p: Coordinate, onto a: Coordinate, _ b: Coordinate) -> (distance: Double, t: Double, length: Double) {
        let mPerLat = metersPerDegreeLatitude
        let mPerLng = metersPerDegreeLatitude * cos(p.latitude * Double.pi / 180)
        let ax = (a.longitude - p.longitude) * mPerLng
        let ay = (a.latitude - p.latitude) * mPerLat
        let bx = (b.longitude - p.longitude) * mPerLng
        let by = (b.latitude - p.latitude) * mPerLat
        let dx = bx - ax, dy = by - ay
        let lengthSquared = dx * dx + dy * dy
        var t = lengthSquared == 0 ? 0 : -(ax * dx + ay * dy) / lengthSquared
        t = min(max(t, 0), 1)
        let cx = ax + t * dx, cy = ay + t * dy
        return ((cx * cx + cy * cy).squareRoot(), t, lengthSquared.squareRoot())
    }
}

extension Coordinate {
    /// Bir çizgiye (nokta zinciri) en kısa uzaklık (m). Boş çizgide sonsuz.
    public func distance(toLine line: [Coordinate]) -> Double {
        guard let first = line.first else { return .infinity }
        if line.count == 1 { return meters(to: first) }
        var best = Double.infinity
        for index in 0..<(line.count - 1) {
            best = min(best, PlanarGeometry.project(self, onto: line[index], line[index + 1]).distance)
        }
        return best
    }
}

extension HatGeom {
    /// `p`'ye bu güzergahta binilebilir en yakın nokta ve düz uzaklığı (m).
    ///
    /// Mesafe noktalara değil parçalara (dik izdüşüm) göre ölçülür: uzun düz
    /// yollarda yolun yanındaysan gerçek mesafe çıkar. Bir parça, iki ucu da
    /// binilebilirse binilebilir sayılır (otoyol parçaları atlanır). Binilebilir
    /// parça yoksa en yakın binilebilir noktaya düşer; o da yoksa `nil`.
    public func nearestBoardable(to p: Coordinate) -> (point: Coordinate, meters: Double)? {
        let mPerLat = PlanarGeometry.metersPerDegreeLatitude
        let mPerLng = PlanarGeometry.metersPerDegreeLatitude * cos(p.latitude * Double.pi / 180)
        var best = Double.infinity
        var bestPoint: Coordinate?
        if points.count >= 2 {
            for index in 0..<(points.count - 1) {
                guard isBoardable(at: index), isBoardable(at: index + 1) else { continue }
                let a = points[index], b = points[index + 1]
                let projection = PlanarGeometry.project(p, onto: a, b)
                if projection.distance < best {
                    best = projection.distance
                    bestPoint = Coordinate(
                        latitude: a.latitude + projection.t * (b.latitude - a.latitude),
                        longitude: a.longitude + projection.t * (b.longitude - a.longitude)
                    )
                }
            }
        }
        if bestPoint == nil {
            for (index, vertex) in points.enumerated() where isBoardable(at: index) {
                let dy = (vertex.latitude - p.latitude) * mPerLat
                let dx = (vertex.longitude - p.longitude) * mPerLng
                let distance = (dx * dx + dy * dy).squareRoot()
                if distance < best {
                    best = distance
                    bestPoint = vertex
                }
            }
        }
        return bestPoint.map { ($0, best) }
    }
}
