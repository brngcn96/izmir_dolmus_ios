import Foundation

/// Bir konum ölçümü. Paket CoreLocation'a bağlı değil; uygulama
/// `CLLocation`'dan bunu kurar.
public struct LocationFix: Sendable, Equatable {
    public var coordinate: Coordinate
    /// Yatay doğruluk (m): gerçek konum bu yarıçap içinde. Bilinmiyorsa negatif.
    public var accuracy: Double

    public init(coordinate: Coordinate, accuracy: Double) {
        self.coordinate = coordinate
        self.accuracy = accuracy
    }
}

/// Yolculuğun o anki hali: hangi bacaktayız, bacağın hedefine ne kaldı.
public struct JourneyProgress: Sendable, Equatable {
    /// `journey.legs` içindeki şu anki bacak.
    public var legIndex: Int
    /// Bacağın hedefine (biniş noktası, iniş noktası ya da varış) kalan mesafe
    /// (m). İlk geçerli ölçüme kadar bacağın planlanan uzunluğu.
    public var metersRemaining: Int
    /// Dolmuştayken inişe `JourneyTracker.approachMeters`'tan az kaldı.
    public var isApproaching = false
    /// Dolmuş bacağında güzergahtan uzaklaşıldı (birkaç ölçüm üst üste).
    public var isOffRoute = false
    public var hasArrived = false
}

/// Takipte olan biten; uygulama bunlara göre Live Activity'yi günceller ve uyarır.
public enum JourneyEvent: Sendable, Equatable {
    /// Yeni bacağa geçildi.
    case advanced(to: Int)
    /// İnişe yaklaşıldı (ilk uyarı, ~400 m).
    case approaching(legIndex: Int)
    /// İnmek üzere (ikinci uyarı, ~150 m).
    case getOff(legIndex: Int)
    /// Dolmuş bacağında güzergahtan uzaklaşıldı.
    case offRoute(legIndex: Int)
    /// Güzergaha geri dönüldü.
    case backOnRoute(legIndex: Int)
    case arrived
}

/// Seçilen tarifi konumla adım adım izler: yürüme bacağında hedefe kalan düz
/// mesafe, dolmuş bacağında güzergah boyunca inişe kalan mesafe.
///
/// Saf bir değer tipi: CoreLocation ya da zaman yok, yalnızca "şu ölçüm geldi".
/// Bu sayede testte gürültülü sentetik izlerle sürülebilir.
public struct JourneyTracker: Sendable {
    // MARK: Eşikler (m)

    /// Yürüme hedefine bu kadar yaklaşınca (artı ölçümün doğruluğu) varılmış sayılır.
    public static let arrivalRadius = 30.0
    /// Doğruluğun yarıçapa katkısı en çok bu kadar.
    static let accuracyAllowance = 40.0
    /// Bundan kötü doğruluklu ölçümler yok sayılır.
    public static let maxAccuracy = 100.0
    /// İnişe bu kadar kalınca ilk uyarı.
    public static let approachMeters = 400.0
    /// İnişe bu kadar kalınca "in" uyarısı.
    public static let getOffMeters = 150.0
    /// İnişe bu kadar kalınca dolmuş bacağı bitmiş sayılır.
    public static let alightMeters = 40.0
    /// Güzergaha bundan uzak ölçümler (artı doğruluk) güzergah dışı sayılır.
    public static let offRouteMeters = 200.0
    /// Güzergah dışı sayılmak için üst üste kaç ölçüm.
    static let offRouteFixes = 3
    /// Yürürken bir sonraki dolmuşun güzergahında, binişten bu kadar ilerideysen
    /// (zaten dolmuştasın) dolmuş bacağına atlanır.
    static let skipAheadMeters = 150.0

    public let journey: Journey
    public private(set) var progress: JourneyProgress

    /// Şu anki dolmuş bacağının güzergahı ve onun üzerindeki son konum.
    private var route: RouteLine?
    private var lastAlong: Double?
    private var hasWarnedApproach = false
    private var hasWarnedGetOff = false
    private var offRouteCount = 0

    public init(journey: Journey) {
        self.journey = journey
        progress = JourneyProgress(legIndex: 0, metersRemaining: journey.legs.first.map(Self.plannedMeters) ?? 0)
        prepareLeg()
    }

    /// Kayıttan sürdürürken: doğrudan `legIndex`. bacaktan başlar (olay üretmez).
    public init(journey: Journey, legIndex: Int) {
        self.init(journey: journey)
        for _ in 0..<min(max(legIndex, 0), journey.legs.count - 1) {
            _ = advanceManually()
        }
    }

    /// Yeni bir ölçümü işler; olan bitenleri sırasıyla döndürür.
    public mutating func update(with fix: LocationFix) -> [JourneyEvent] {
        guard !progress.hasArrived, fix.accuracy >= 0, fix.accuracy <= Self.maxAccuracy else { return [] }
        var events: [JourneyEvent] = []
        // Aynı ölçümle birden çok bacak bitebilir (ör. dolmuştan inince aktarma
        // yürüyüşü birkaç metre): bacak bittikçe yenisi aynı ölçümle denenir.
        for _ in journey.legs.indices {
            guard !progress.hasArrived, evaluateCurrentLeg(with: fix, events: &events) else { break }
        }
        return events
    }

    /// Konum yetmediğinde elle ilerletme ("Sonraki adım").
    public mutating func advanceManually() -> [JourneyEvent] {
        guard !progress.hasArrived else { return [] }
        var events: [JourneyEvent] = []
        completeLeg(events: &events)
        return events
    }

    // MARK: Bacaklar

    /// Şu anki bacağı ölçümle değerlendirir. Bacak bittiyse `true` (sıradaki denenir).
    private mutating func evaluateCurrentLeg(with fix: LocationFix, events: inout [JourneyEvent]) -> Bool {
        let allowance = min(fix.accuracy, Self.accuracyAllowance)
        switch journey.legs[progress.legIndex] {
        case .walk(let walk):
            let distance = fix.coordinate.meters(to: walk.to)
            progress.metersRemaining = Int(distance)
            if distance <= Self.arrivalRadius + allowance {
                completeLeg(events: &events)
                return true
            }
            // Yürüme bacağındayken zaten sonraki dolmuşun güzergahında ilerideysen.
            if case .ride(let ride) = nextLeg {
                let line = RouteLine(ride.ridePoints)
                let located = line.locate(fix.coordinate)
                if located.distance <= Self.arrivalRadius + allowance, located.along >= Self.skipAheadMeters {
                    completeLeg(events: &events)
                    lastAlong = located.along
                    return true
                }
            }
            return false

        case .ride:
            guard let route else { return false }
            let limit = Self.offRouteMeters + allowance
            var located = route.locate(fix.coordinate, near: lastAlong)
            // Pencerede uzak görünüyorsa (GPS boşluğu, elle ilerletme) bütün
            // güzergahta ara: güzergahın başka bir yerindeysek oraya yerleş.
            if located.distance > limit, lastAlong != nil {
                let anywhere = route.locate(fix.coordinate)
                if anywhere.distance <= limit {
                    located = anywhere
                }
            }
            if located.distance > limit {
                offRouteCount += 1
                if offRouteCount >= Self.offRouteFixes, !progress.isOffRoute {
                    progress.isOffRoute = true
                    events.append(.offRoute(legIndex: progress.legIndex))
                }
                return false
            }
            offRouteCount = 0
            if progress.isOffRoute {
                progress.isOffRoute = false
                events.append(.backOnRoute(legIndex: progress.legIndex))
            }
            lastAlong = located.along
            let remaining = max(route.length - located.along, 0)
            progress.metersRemaining = Int(remaining.rounded())
            if remaining <= Self.approachMeters, !hasWarnedApproach {
                hasWarnedApproach = true
                progress.isApproaching = true
                events.append(.approaching(legIndex: progress.legIndex))
            }
            if remaining <= Self.getOffMeters, !hasWarnedGetOff {
                hasWarnedGetOff = true
                events.append(.getOff(legIndex: progress.legIndex))
            }
            if remaining <= Self.alightMeters {
                completeLeg(events: &events)
                return true
            }
            return false
        }
    }

    private var nextLeg: JourneyLeg? {
        let next = progress.legIndex + 1
        return journey.legs.indices.contains(next) ? journey.legs[next] : nil
    }

    /// Bacağı bitirir: sıradakine geçer ya da varılır.
    private mutating func completeLeg(events: inout [JourneyEvent]) {
        guard progress.legIndex + 1 < journey.legs.count else {
            progress.hasArrived = true
            progress.metersRemaining = 0
            progress.isApproaching = false
            progress.isOffRoute = false
            events.append(.arrived)
            return
        }
        progress.legIndex += 1
        progress.metersRemaining = Self.plannedMeters(journey.legs[progress.legIndex])
        progress.isApproaching = false
        progress.isOffRoute = false
        prepareLeg()
        events.append(.advanced(to: progress.legIndex))
    }

    /// Yeni bacağın durumunu sıfırlar; dolmuş bacağıysa güzergahını hazırlar.
    private mutating func prepareLeg() {
        // Dolmuş bacağı binişte başlar: ilk ölçüm de binişin çevresinde aranır.
        lastAlong = 0
        hasWarnedApproach = false
        hasWarnedGetOff = false
        offRouteCount = 0
        if journey.legs.indices.contains(progress.legIndex), case .ride(let ride) = journey.legs[progress.legIndex] {
            route = RouteLine(ride.ridePoints)
        } else {
            route = nil
        }
    }

    private static func plannedMeters(_ leg: JourneyLeg) -> Int {
        switch leg {
        case .walk(let walk): Int(walk.meters.rounded())
        case .ride(let ride): Int(ride.meters.rounded())
        }
    }
}

/// Bir dolmuş bacağının güzergahı: bir konumun güzergah boyunca nerede olduğu.
struct RouteLine: Sendable {
    let points: [Coordinate]
    /// `points[i]`'ye kadar güzergah boyu mesafe (m); ilki 0.
    let cumulative: [Double]

    init(_ points: [Coordinate]) {
        self.points = points
        var cumulative = [0.0]
        for index in points.indices.dropFirst() {
            let segment = PlanarGeometry.project(points[index - 1], onto: points[index - 1], points[index]).length
            cumulative.append(cumulative[index - 1] + segment)
        }
        self.cumulative = cumulative
    }

    var length: Double {
        cumulative.last ?? 0
    }

    /// Konumun güzergaha izdüşümü: baştan güzergah boyu mesafe (`along`) ve
    /// güzergaha uzaklık. `near` verilirse yalnızca o konumun biraz gerisi ile
    /// epey ilerisi arasındaki kısma bakılır (parçalar bu pencereye kırpılır):
    /// kendine yakın geçen (gidip dönen) güzergahlarda konum öbür uca sıçramasın.
    func locate(_ p: Coordinate, near: Double? = nil, behind: Double = 300, ahead: Double = 3_000) -> (along: Double, distance: Double) {
        guard points.count >= 2 else {
            return (0, points.first.map { p.meters(to: $0) } ?? .infinity)
        }
        let window = near.map { ($0 - behind)...($0 + ahead) }
        var best = (along: 0.0, distance: Double.infinity)
        for index in 0..<(points.count - 1) {
            let start = cumulative[index], length = cumulative[index + 1] - start
            var allowed = 0.0...1.0
            if let window {
                guard start + length >= window.lowerBound, start <= window.upperBound else { continue }
                if length > 0 {
                    allowed = max(0, (window.lowerBound - start) / length)...min(1, (window.upperBound - start) / length)
                }
            }
            let a = points[index], b = points[index + 1]
            let projection = PlanarGeometry.project(p, onto: a, b)
            let t = min(max(projection.t, allowed.lowerBound), allowed.upperBound)
            let distance = t == projection.t
                ? projection.distance
                : Self.planarDistance(p, Coordinate(latitude: a.latitude + t * (b.latitude - a.latitude), longitude: a.longitude + t * (b.longitude - a.longitude)))
            if distance < best.distance {
                best = (start + t * length, distance)
            }
        }
        // Pencere güzergahın dışında kaldıysa (beklenmez) bütün güzergaha bak.
        if best.distance == .infinity, near != nil {
            return locate(p)
        }
        return best
    }

    /// Kısa mesafelerde düzlem yaklaşımıyla iki nokta arası (m).
    static func planarDistance(_ p: Coordinate, _ q: Coordinate) -> Double {
        let dy = (q.latitude - p.latitude) * PlanarGeometry.metersPerDegreeLatitude
        let dx = (q.longitude - p.longitude) * PlanarGeometry.metersPerDegreeLatitude * cos(p.latitude * .pi / 180)
        return (dx * dx + dy * dy).squareRoot()
    }
}
