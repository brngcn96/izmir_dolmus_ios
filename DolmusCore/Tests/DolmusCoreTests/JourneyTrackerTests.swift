import Foundation
import Testing
@testable import DolmusCore

/// Yolculuk takibi: gerçek tariflerin bacakları boyunca üretilmiş, gürültülü
/// sentetik GPS izleriyle.
@Suite struct JourneyTrackerTests {
    // MARK: Sentetik iz

    /// Izin bir noktası: ölçüm, hangi bacakta üretildiği ve o bacağın hedefine
    /// gerçekte kalan mesafe (gürültüsüz).
    struct TracePoint {
        var fix: LocationFix
        var leg: Int
        var trueRemaining: Double
    }

    /// Her koşuda aynı "rastgele" sayılar (doğrusal eşlik üreteci).
    struct Noise {
        var state: UInt64

        /// -1…1 arası.
        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(1 << 53) * 2 - 1
        }

        /// Noktayı en çok `meters` kadar rastgele kaydırır.
        mutating func jitter(_ p: Coordinate, meters: Double) -> Coordinate {
            let north = next() * meters, east = next() * meters
            return Coordinate(
                latitude: p.latitude + north / PlanarGeometry.metersPerDegreeLatitude,
                longitude: p.longitude + east / (PlanarGeometry.metersPerDegreeLatitude * cos(p.latitude * .pi / 180))
            )
        }
    }

    /// Çizgi üzerinde, baştan `along` metredeki nokta.
    static func point(on line: RouteLine, at along: Double) -> Coordinate {
        guard let last = line.points.last else { return Coordinate(latitude: 0, longitude: 0) }
        guard along < line.length else { return last }
        let index = max((line.cumulative.firstIndex { $0 > along } ?? line.cumulative.count) - 1, 0)
        let a = line.points[index], b = line.points[index + 1]
        let segment = line.cumulative[index + 1] - line.cumulative[index]
        let t = segment > 0 ? (along - line.cumulative[index]) / segment : 0
        return Coordinate(latitude: a.latitude + t * (b.latitude - a.latitude), longitude: a.longitude + t * (b.longitude - a.longitude))
    }

    /// Tarifin tamamı boyunca iz: yürüme 1,3 m/sn, dolmuş 8 m/sn, 5 sn'de bir
    /// ölçüm, `noise` metreye kadar sapma. `startFraction`: ilk dolmuş bacağının
    /// ortasından başlatmak için (o zamana kadarki bacaklar atlanır).
    static func trace(for journey: Journey, noiseMeters: Double = 10, seed: UInt64 = 7, startRideFraction: Double? = nil) -> [TracePoint] {
        var noise = Noise(state: seed)
        var points: [TracePoint] = []
        let interval = 5.0
        var skipping = startRideFraction != nil
        for (index, leg) in journey.legs.enumerated() {
            let line: RouteLine
            let speed: Double
            switch leg {
            case .walk(let walk):
                line = RouteLine([walk.from, walk.to])
                speed = 1.3
            case .ride(let ride):
                line = RouteLine(ride.ridePoints)
                speed = 8
            }
            var along = 0.0
            if skipping {
                guard case .ride = leg, let fraction = startRideFraction else { continue }
                along = line.length * fraction
                skipping = false
            }
            while true {
                let exact = point(on: line, at: along)
                let fix = LocationFix(coordinate: noise.jitter(exact, meters: noiseMeters), accuracy: 10)
                points.append(TracePoint(fix: fix, leg: index, trueRemaining: max(line.length - along, 0)))
                if along >= line.length { break }
                along = min(along + speed * interval, line.length)
            }
        }
        return points
    }

    /// İzi baştan sona sürer; her olayı, onu doğuran noktayla birlikte döndürür.
    static func run(_ tracker: inout JourneyTracker, _ trace: [TracePoint]) -> [(event: JourneyEvent, at: TracePoint)] {
        var result: [(JourneyEvent, TracePoint)] = []
        for point in trace {
            for event in tracker.update(with: point.fix) {
                result.append((event, point))
            }
        }
        return result
    }

    /// Bir tarif için beklenen olay sırası: her bacağa geçiş, dolmuş bacaklarında
    /// iki uyarı, sonunda varış.
    static func expectedEvents(for journey: Journey) -> [JourneyEvent] {
        var expected: [JourneyEvent] = []
        for (index, leg) in journey.legs.enumerated() where index > 0 {
            expected.append(.advanced(to: index))
            if case .ride = leg {
                expected += [.approaching(legIndex: index), .getOff(legIndex: index)]
            }
        }
        return expected + [.arrived]
    }

    // MARK: Tarifler

    static let center = Coordinate(latitude: 38.4237, longitude: 27.1428)

    static func journeys(from: String, to: String) async throws -> [Journey] {
        let data = try await Bundled.data.value
        let a = try #require(data.placeMatches(from, limit: 1, near: center).first)
        let b = try #require(data.placeMatches(to, limit: 1, near: center).first)
        let planner = await JourneyPlanner.build(from: data)
        return await planner.planTrip(from: a.coordinate, to: b.coordinate, data: data)
    }

    // MARK: Testler

    @Test("Aktarmasız tarif: binişe yürü → dolmuş (iki uyarı) → varışa yürü")
    func followsSingleRide() async throws {
        let journey = try #require(try await Self.journeys(from: "bornova metro", to: "şirinyer").first { $0.rides.count == 1 })
        var tracker = JourneyTracker(journey: journey)
        let events = Self.run(&tracker, Self.trace(for: journey))
        #expect(events.map(\.event) == Self.expectedEvents(for: journey))
        #expect(tracker.progress.hasArrived)
        // Uyarılar doğru anda: 5 sn'de 40 m ilerleyen dolmuşta eşiğin hemen altında.
        let approach = try #require(events.first { if case .approaching = $0.event { true } else { false } })
        let getOff = try #require(events.first { if case .getOff = $0.event { true } else { false } })
        #expect((330...430).contains(approach.at.trueRemaining), "ilk uyarı \(approach.at.trueRemaining) m kala")
        #expect((90...180).contains(getOff.at.trueRemaining), "in uyarısı \(getOff.at.trueRemaining) m kala")
    }

    @Test("Aktarmalı tarif: iki dolmuş, her birinde iki uyarı, sırası bozulmadan")
    func followsTransfer() async throws {
        var found: Journey?
        for (from, to) in [("konak", "bornova metro"), ("karşıyaka", "buca"), ("çiğli", "gaziemir"), ("narlıdere", "bornova metro")] {
            if let journey = try await Self.journeys(from: from, to: to).first(where: { $0.rides.count == 2 }) {
                found = journey
                break
            }
        }
        let journey = try #require(found)
        var tracker = JourneyTracker(journey: journey)
        let events = Self.run(&tracker, Self.trace(for: journey, seed: 11))
        #expect(events.map(\.event) == Self.expectedEvents(for: journey))
        // Bacak hep ileri gider.
        var leg = 0
        for case .advanced(let next) in events.map(\.event) {
            #expect(next == leg + 1)
            leg = next
        }
    }

    @Test("Dolmuşun ortasında başlayınca: yürüme bacağı atlanır")
    func startsMidRide() async throws {
        let journey = try #require(try await Self.journeys(from: "bornova metro", to: "şirinyer").first { $0.rides.count == 1 })
        var tracker = JourneyTracker(journey: journey)
        let trace = Self.trace(for: journey, startRideFraction: 0.4)
        let first = tracker.update(with: trace[0].fix)
        #expect(first == [.advanced(to: 1)])
        #expect(tracker.progress.legIndex == 1)
        _ = Self.run(&tracker, Array(trace.dropFirst()))
        #expect(tracker.progress.hasArrived)
    }

    @Test("Kötü doğruluklu ölçüm yok sayılır")
    func ignoresInaccurateFixes() async throws {
        let journey = try #require(try await Self.journeys(from: "bornova metro", to: "şirinyer").first)
        var tracker = JourneyTracker(journey: journey)
        let before = tracker.progress
        guard case .walk(let walk) = journey.legs[0] else { Issue.record("ilk bacak yürüme değil"); return }
        // Hedefin tam üstünde ama doğruluğu 500 m: güvenilmez.
        #expect(tracker.update(with: LocationFix(coordinate: walk.to, accuracy: 500)).isEmpty)
        #expect(tracker.update(with: LocationFix(coordinate: walk.to, accuracy: -1)).isEmpty)
        #expect(tracker.progress == before)
    }

    @Test("Güzergahtan çıkınca üç ölçümde uyarı, dönünce kalkar")
    func detectsOffRoute() async throws {
        let journey = try #require(try await Self.journeys(from: "bornova metro", to: "şirinyer").first { $0.rides.count == 1 })
        var tracker = JourneyTracker(journey: journey)
        let trace = Self.trace(for: journey, noiseMeters: 0)
        let rideStart = try #require(trace.firstIndex { $0.leg == 1 })
        _ = Self.run(&tracker, Array(trace[...(rideStart + 10)]))
        #expect(tracker.progress.legIndex == 1)
        // Güzergahın ~600 m kuzeyi.
        let here = trace[rideStart + 10].fix.coordinate
        let away = Coordinate(latitude: here.latitude + 600 / PlanarGeometry.metersPerDegreeLatitude, longitude: here.longitude)
        #expect(tracker.update(with: LocationFix(coordinate: away, accuracy: 10)).isEmpty)
        #expect(tracker.update(with: LocationFix(coordinate: away, accuracy: 10)).isEmpty)
        #expect(tracker.update(with: LocationFix(coordinate: away, accuracy: 10)) == [.offRoute(legIndex: 1)])
        #expect(tracker.progress.isOffRoute)
        #expect(tracker.update(with: trace[rideStart + 11].fix) == [.backOnRoute(legIndex: 1)])
        #expect(!tracker.progress.isOffRoute)
    }

    @Test("Elle ilerletme: her bacak, sonunda varış")
    func manualAdvance() async throws {
        let journey = try #require(try await Self.journeys(from: "bornova metro", to: "şirinyer").first)
        var tracker = JourneyTracker(journey: journey)
        var events: [JourneyEvent] = []
        for _ in journey.legs.indices {
            events += tracker.advanceManually()
        }
        #expect(events == journey.legs.indices.dropFirst().map { JourneyEvent.advanced(to: $0) } + [.arrived])
        #expect(tracker.advanceManually().isEmpty)
    }

    @Test("Elle dolmuşa geçip güzergahın ilerisinden ölçüm gelince oraya yerleşir")
    func reanchorsAfterManualAdvance() async throws {
        let journey = try #require(try await Self.journeys(from: "bornova metro", to: "şirinyer").first { $0.rides.count == 1 })
        var tracker = JourneyTracker(journey: journey)
        #expect(tracker.advanceManually() == [.advanced(to: 1)])
        guard case .ride(let ride) = journey.legs[1] else { Issue.record("ikinci bacak dolmuş değil"); return }
        let line = RouteLine(ride.ridePoints)
        try #require(line.length * 0.7 > 3_000, "pencerenin dışına düşmeli")
        let events = tracker.update(with: LocationFix(coordinate: Self.point(on: line, at: line.length * 0.7), accuracy: 10))
        #expect(events.isEmpty)
        #expect(!tracker.progress.isOffRoute)
        #expect(abs(Double(tracker.progress.metersRemaining) - line.length * 0.3) < 5, "\(tracker.progress.metersRemaining) / \(line.length)")
    }

    @Test("Gidip dönen güzergah: konum öbür uca sıçramaz")
    func loopingRouteStaysLocal() {
        // 2 km kuzeye, 100 m doğuya, 2 km güneye: başlangıcın yanından geri geçen bir güzergah.
        let start = Coordinate(latitude: 38.40, longitude: 27.10)
        let mPerLng = PlanarGeometry.metersPerDegreeLatitude * cos(start.latitude * .pi / 180)
        func offset(north: Double, east: Double) -> Coordinate {
            Coordinate(latitude: start.latitude + north / PlanarGeometry.metersPerDegreeLatitude, longitude: start.longitude + east / mPerLng)
        }
        let line = RouteLine([start, offset(north: 2_000, east: 0), offset(north: 2_000, east: 100), offset(north: 0, east: 100)])
        // Başlangıca yakın bir nokta: gidiş koluna 55 m, dönüş koluna 45 m.
        let p = offset(north: 100, east: 55)
        // Pencere olmadan en yakın parça dönüş kolu: güzergahın neredeyse sonu.
        #expect(line.locate(p).along > 3_500)
        // Son konum başlangıçtaysa (80 m) pencere gidiş kolunda tutar.
        let local = line.locate(p, near: 80)
        #expect(abs(local.along - 100) < 1, "\(local.along)")
        #expect(abs(local.distance - 55) < 1)
    }
}
