/// Haritada çizilebilecek bir nokta: önemli nokta ya da adından türü çıkarılan
/// sözlük yeri (durak, okul, eczane…).
public struct MapPoi: Sendable, Hashable, Identifiable {
    /// Veri içindeki sırası; aynı veri için kalıcı.
    public let id: Int
    public let label: String
    public let coordinate: Coordinate
    /// `metro`, `hastane`, `durak`, `mahalle`…
    public let type: String
    /// Bu zoom'un altında çizilmez.
    public let minZoom: Double
    /// Kalabalıkta kalma önceliği; büyük olan önce.
    public let priority: Int
}

/// Bir enlem/boylam kutusu (haritanın görünür alanı).
public struct GeoBox: Sendable, Equatable {
    public var south: Double
    public var north: Double
    public var west: Double
    public var east: Double

    public init(south: Double, north: Double, west: Double, east: Double) {
        self.south = south
        self.north = north
        self.west = west
        self.east = east
    }

    public var center: Coordinate {
        Coordinate(latitude: (south + north) / 2, longitude: (west + east) / 2)
    }

    public func contains(_ c: Coordinate) -> Bool {
        c.latitude >= south && c.latitude <= north && c.longitude >= west && c.longitude <= east
    }
}

/// Türlere göre görünürlük ve öncelik (Flutter'daki `_minZoomFor`, `_priorityFor`).
enum PoiRules {
    static func minZoom(for type: String) -> Double {
        switch type {
        case "metro", "izban", "istasyon", "tramvay", "otogar", "iskele": 12.0
        case "mahalle": 12.5
        case "universite", "stadyum", "hastane": 13.5
        case "belediye", "adliye", "avm", "pazar", "magaza": 13.5
        case "muze", "turistik", "park": 13.5
        case "kultur", "nikah": 14.0
        case "okul", "poi": 14.0
        case "spor", "dugun": 15.0
        case "eczane": 16.5
        case "otel": 15.5
        case "kafe", "restoran", "pastane": 15.5
        case "bar": 15.0
        case "durak": 16.5
        default: 14.0
        }
    }

    static func priority(for type: String) -> Int {
        switch type {
        case "metro", "izban", "istasyon", "tramvay", "otogar", "iskele", "universite", "hastane", "stadyum": 5
        case "avm", "belediye", "adliye", "pazar", "mahalle", "magaza": 4
        case "muze", "turistik", "park": 4
        case "kultur", "spor", "nikah": 3
        case "eczane", "okul", "poi": 3
        case "dugun", "otel", "kafe", "restoran", "pastane": 2
        case "bar": 3
        case "durak": 2
        case "cadde": 1
        default: 2
        }
    }

    /// Izgara hücresi: ~400 m.
    static let cell = 0.004

    static func cellKey(latitude: Double, longitude: Double) -> Int {
        cellIndex(latitude) * 100_000 + cellIndex(longitude)
    }

    static func cellIndex(_ degrees: Double) -> Int {
        Int((degrees / cell).rounded(.down))
    }
}
