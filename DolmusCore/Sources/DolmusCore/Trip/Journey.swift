import Foundation

/// Yol tarifi varsayımları (Flutter'daki `journey_planner.dart` ile aynı).
public enum TripConstants {
    /// 4 km/s: temkinli yaya ortalaması (m/dk).
    public static let walkMetersPerMinute = 4000.0 / 60
    /// 27 km/s: şehir içi dolmuş ortalaması, dur-kalk ve trafikle (m/dk).
    public static let rideMetersPerMinute = 27000.0 / 60
    /// Her binişte ortalama bekleme (dk).
    static let boardWaitMinutes = 4.0
    /// Aktarma zahmeti; gösterilen süreye girer (dk).
    static let transferPenaltyMinutes = 3.0
    /// Yalnızca sıralamada: aktarmaya ek ceza ve ücretin dakika karşılığı.
    static let transferSortPenaltyMinutes = 5.0
    static let feeSortWeight = 0.4
    /// Yürüme kuş uçuşu × bu katsayı (yaya her caddeden karşıya geçebiliyor).
    public static let walkDetourFactor = 1.2
    /// Başta/sonda ve aktarmada yürüme üst sınırları (m).
    static let maxAccessWalk = 1200.0
    static let maxTransferWalk = 500.0
}

/// Bir yürüme bacağı: başlangıçtan durağa, aktarmada, durağa varıştan hedefe.
public struct WalkLeg: Sendable, Equatable, Codable {
    public let from: Coordinate
    public let to: Coordinate
    /// Planlama sırasındaki kuş uçuşu tahmin (m).
    public let straightMeters: Double
    /// Bacağın sonunda ne var: binilecek hattın adı ya da "Varış".
    public let toLabel: String
    /// Çözülmüş yürüme uzunluğu (m); çözülmediyse `nil`.
    public internal(set) var pathMeters: Double?

    public var meters: Double {
        pathMeters ?? straightMeters * TripConstants.walkDetourFactor
    }

    public var minutes: Int {
        Int((meters / TripConstants.walkMetersPerMinute).rounded(.up))
    }
}

/// Bir dolmuş bacağı: hatta biniş, güzergah boyunca iniş.
public struct RideLeg: Sendable, Equatable, Codable {
    public let hatID: String
    public let hatName: String
    /// `geoms(for:)` içindeki güzergahın sırası.
    public let geomIndex: Int
    public let yon: String
    public let board: Coordinate
    public let alight: Coordinate
    /// Biniş ile iniş arasındaki güzergah (çizim için).
    public let ridePoints: [Coordinate]
    public let meters: Double
    public let feeMin: Int?
    public let feeMax: Int?

    public var minutes: Int {
        Int((meters / TripConstants.rideMetersPerMinute).rounded(.up))
    }
}

public enum JourneyLeg: Sendable, Equatable, Codable {
    case walk(WalkLeg)
    case ride(RideLeg)
}

/// Bir yol tarifi seçeneği: yürü → bin → (aktar → bin →) in → yürü.
/// `Codable`: süren yolculuk cihazda saklanır (yeniden açılışta sürdürmek için).
public struct Journey: Sendable, Equatable, Identifiable, Codable {
    public internal(set) var legs: [JourneyLeg]

    public init(legs: [JourneyLeg]) {
        self.legs = legs
    }

    /// Bindiği hatlar sırasıyla ("M19>M33"); aynı kombinasyondan tek seçenek kalır.
    public var id: String {
        rides.map(\.hatID).joined(separator: ">")
    }

    public var rides: [RideLeg] {
        legs.compactMap { if case .ride(let ride) = $0 { ride } else { nil } }
    }

    public var walks: [WalkLeg] {
        legs.compactMap { if case .walk(let walk) = $0 { walk } else { nil } }
    }

    public var transfers: Int {
        rides.count - 1
    }

    public var walkMeters: Double {
        walks.reduce(0) { $0 + $1.meters }
    }

    public var rideMeters: Double {
        rides.reduce(0) { $0 + $1.meters }
    }

    /// Tahmini toplam süre (dk): sürüşler + her binişte bekleme + yürüyüşler +
    /// aktarma zahmeti. Sefer saati verisi yok; mesafeden tahmin.
    public var estimatedMinutes: Int {
        var minutes = 0.0
        for ride in rides {
            minutes += Double(ride.minutes) + TripConstants.boardWaitMinutes
        }
        for walk in walks {
            minutes += Double(walk.minutes)
        }
        minutes += Double(transfers) * TripConstants.transferPenaltyMinutes
        return Int(minutes.rounded(.up))
    }

    /// Sıralama puanı (küçük daha iyi). Gösterilen süreye ek olarak yürüme,
    /// aktarma ve ücreti ağırlıklandırır; yalnızca "önerilen" seçimini etkiler.
    public var sortScore: Double {
        let walkMinutes = walkMeters / TripConstants.walkMetersPerMinute
        let fee = Double(feeMax ?? feeMin ?? 0)
        return Double(estimatedMinutes)
            + 1.5 * walkMinutes
            + TripConstants.transferSortPenaltyMinutes * Double(transfers)
            + TripConstants.feeSortWeight * fee
    }

    /// Ücret aralığı: bindiği hatların taban ve tavanlarının toplamı.
    public var feeMin: Int? {
        let values = rides.compactMap(\.feeMin)
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    public var feeMax: Int? {
        let values = rides.compactMap(\.feeMax)
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    /// "55 ₺", "55–90 ₺" ya da "Ücret ?".
    public var feeLabel: String {
        guard let feeMin else { return "Ücret ?" }
        let feeMax = feeMax ?? feeMin
        return feeMin == feeMax ? "\(feeMin) ₺" : "\(feeMin)–\(feeMax) ₺"
    }

    /// Yürüme bacaklarının uzunluğunu çözer: kuş uçuşu × yürüme katsayısı
    /// (Flutter'daki `RoutingService.footRoute`; ağ gerekmez).
    func resolvingWalks() -> Journey {
        var copy = self
        copy.legs = legs.map { leg in
            guard case .walk(var walk) = leg else { return leg }
            walk.pathMeters = walk.from.meters(to: walk.to) * TripConstants.walkDetourFactor
            return .walk(walk)
        }
        return copy
    }
}
