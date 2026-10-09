import Foundation

/// Binilebilirlik düzeltmeleri.
///
/// Güzergah noktalarının "binilebilir" bayrağı harita verisindeki (OSM) yol
/// sınıfından türetilir. Bazı ana caddeler orada yanlışlıkla otoyol/ana yol
/// diye etiketli; bayrak `0` gelir, planlayıcı orada bindiremeyip kullanıcıyı
/// uzağa yürütür. Tersine, bazı hızlı şeritlerde dolmuş durmadığı halde bayrak
/// `1` gelir. Buradaki bölgeler veri yüklenirken bayrağı düzeltir.
///
/// Flutter tarafındaki `board_overrides.dart`'ın karşılığıdır.
enum BoardOverrides {
    private struct Box {
        let minLat, minLng, maxLat, maxLng: Double

        func contains(_ p: Coordinate) -> Bool {
            p.latitude >= minLat && p.latitude <= maxLat
                && p.longitude >= minLng && p.longitude <= maxLng
        }
    }

    /// Zorla binilebilir bölgeler. Dar tutulur.
    private static let boardableBoxes: [Box] = [
        // Üniversite Caddesi (Yaşar / Ege Üniversitesi çevresi, Bornova).
        // OSM'de trunk olarak etiketli; dolmuş burada durur.
        Box(minLat: 38.4510, minLng: 27.2030, maxLat: 38.4575, maxLng: 27.2070),
    ]

    /// Zorla binilemez bölgeler; `boardableBoxes`'tan önceliklidir. Geniş
    /// olursa gereksiz uzağa yürütür. (Yeşildere için kaba kutu yerine
    /// aşağıdaki koridor kullanılıyor.)
    private static let nonBoardableBoxes: [Box] = []

    /// Koridorun yarı genişliği (metre).
    private static let corridorRadius = 25.0

    /// Zorla binilemez koridorlar: çizgiye `corridorRadius` metreden yakın her
    /// nokta, hangi hatta olursa olsun binilemez. Kutunun aksine yolu ince
    /// sarar; paralel ve kesen sokakları kapmaz.
    private static let nonBoardableCorridors: [[Coordinate]] = [
        // Yeşildere, iki üst geçit arası — gidiş (M19'un 100 m noktaları 164-174).
        [
            (38.421381, 27.153287), (38.422217, 27.152863), (38.423082, 27.152552),
            (38.423948, 27.152241), (38.424827, 27.152011), (38.425717, 27.151911),
            (38.426559, 27.152267), (38.427194, 27.153075), (38.427818, 27.153902),
            (38.428441, 27.154729), (38.429065, 27.155556),
        ].map(Coordinate.init(latitude:longitude:)),
        // Dönüş (M19'un 100 m noktaları 368-378).
        [
            (38.429191, 27.155382), (38.428559, 27.154565), (38.427928, 27.153748),
            (38.427296, 27.152931), (38.426596, 27.152213), (38.425794, 27.151733),
            (38.424899, 27.151844), (38.424021, 27.152073), (38.423155, 27.152383),
            (38.422289, 27.152694), (38.421457, 27.153126),
        ].map(Coordinate.init(latitude:longitude:)),
    ]

    /// Koridorları kapsayan ön eleme kutusu: noktaların çoğu mesafe hesabına
    /// girmeden burada elenir.
    private static let corridorBounds = Box(minLat: 38.4209, minLng: 27.1512, maxLat: 38.4296, maxLng: 27.1560)

    /// `p` zorla binilebilir bir bölgede mi?
    static func forcesBoardable(_ p: Coordinate) -> Bool {
        boardableBoxes.contains { $0.contains(p) }
    }

    /// `p` zorla binilemez mi: binilemez bir kutuda ya da bir koridorun
    /// `corridorRadius` metre yakınında.
    static func forcesNonBoardable(_ p: Coordinate) -> Bool {
        if nonBoardableBoxes.contains(where: { $0.contains(p) }) { return true }
        guard corridorBounds.contains(p) else { return false }

        // Küçük alan için düzlem yaklaşımı: derece → metre.
        let cosLat = cos(p.latitude * .pi / 180)
        func x(_ lng: Double) -> Double { lng * 111320 * cosLat }
        func y(_ lat: Double) -> Double { lat * 110540 }
        let px = x(p.longitude), py = y(p.latitude)
        let radiusSquared = corridorRadius * corridorRadius

        for line in nonBoardableCorridors {
            for (a, b) in zip(line, line.dropFirst()) {
                let ax = x(a.longitude), ay = y(a.latitude)
                let dx = x(b.longitude) - ax, dy = y(b.latitude) - ay
                let lengthSquared = dx * dx + dy * dy
                // p'nin [a, b] parçasındaki izdüşümü, parçanın içine kıstırılmış.
                var t = lengthSquared == 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / lengthSquared
                t = min(max(t, 0), 1)
                let ex = px - (ax + t * dx), ey = py - (ay + t * dy)
                if ex * ex + ey * ey <= radiusSquared { return true }
            }
        }
        return false
    }
}
