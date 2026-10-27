import Foundation
import Testing
@testable import DolmusCore

/// Yol tarifi motorunun Flutter'ın gerçek koduyla aynı rotaları aynı sırada
/// verdiği (`Golden/trips.json`, `export-golden.sh`).
@Suite struct TripGoldenTests {
    /// Kurulumu ağır; bütün testler paylaşır.
    static let planner = Task { JourneyPlanner(data: try await Bundled.data.value) }

    @Test("Rotalar: aynı hatlar, aynı sıra, aynı süre, yürüme, ücret ve bacaklar")
    func trips() async throws {
        let data = try await Bundled.data.value
        let planner = try await Self.planner.value
        let entries: [TripEntry] = try Golden.load("trips.json")
        try #require(entries.count >= 30)
        try #require(entries.filter { !$0.journeys.isEmpty }.count >= 15)
        var budget = FailureBudget()
        for entry in entries where !budget.isExhausted {
            let from = Coordinate(latitude: entry.from[0], longitude: entry.from[1])
            let to = Coordinate(latitude: entry.to[0], longitude: entry.to[1])
            let actual = planner.planTrip(from: from, to: to) { id in
                let hat = data.hat(id: id)
                return (hat?.feeMin, hat?.feeMax)
            }
            budget.note(compare(actual, entry.journeys, entry.name))
        }
    }

    @Test("Havalimanı: çit yüzünden rota yok, bilgi notu var")
    func airportBarrier() async throws {
        let airport = Coordinate(latitude: 38.2913, longitude: 27.14787)
        #expect(WalkBarriers.note(for: airport) != nil)
        #expect(WalkBarriers.note(for: .init(latitude: 38.4189, longitude: 27.1287)) == nil)
        #expect(WalkBarriers.crosses(airport, Coordinate(latitude: 38.30, longitude: 27.16)))
        #expect(!WalkBarriers.crosses(airport, Coordinate(latitude: 38.2914, longitude: 27.1479)))
    }

    private func compare(_ actual: [Journey], _ expected: [TripEntry.JourneyEntry], _ name: String) -> Bool {
        guard actual.count == expected.count else {
            Issue.record("\(name): Swift \(actual.count) rota \(actual.map(\.id)), Flutter \(expected.count) \(expected.map(\.key))")
            return false
        }
        for (index, (j, e)) in zip(actual, expected).enumerated() {
            let same = j.id == e.key
                && j.estimatedMinutes == e.estMinutes
                && j.transfers == e.transfers
                && abs(j.walkMeters - e.walkMeters) < 1e-6
                && abs(j.rideMeters - e.rideMeters) < 1e-6
                && j.feeMin == e.feeMin && j.feeMax == e.feeMax
                && abs(j.sortScore - e.score) < 1e-9
            guard same else {
                Issue.record("\(name) [\(index)]: Swift \(j.id) \(j.estimatedMinutes) dk \(j.walkMeters) m ≠ Flutter \(e.key) \(e.estMinutes) dk \(e.walkMeters) m")
                return false
            }
            guard j.legs.count == e.legs.count else {
                Issue.record("\(name) [\(index)]: bacak sayısı \(j.legs.count) ≠ \(e.legs.count)")
                return false
            }
            for (leg, expectedLeg) in zip(j.legs, e.legs) {
                switch (leg, expectedLeg) {
                case let (.walk(w), .walk(from, to, straight, label)):
                    guard close(w.from, from), close(w.to, to), abs(w.straightMeters - straight) < 1e-6, w.toLabel == label else {
                        Issue.record("\(name) [\(index)]: yürüme bacağı farklı: \(w.toLabel) \(w.straightMeters) ≠ \(label) \(straight)")
                        return false
                    }
                case let (.ride(r), .ride(hatID, geomIndex, board, alight, meters, pointCount)):
                    // Bazı hatların iki varyantı bu kısımda aynı yoldan geçiyor (ör.
                    // M19#manavkuyu'nun gündüz ve akşam RİNG'leri): iki seçenek her ölçüde
                    // eşit ve Dart'ın kararsız sıralaması hangisini öne koyacağını
                    // rastgele seçer. Biniş, iniş ve uzunluk aynıysa varyant farkı
                    // sayılmaz; nokta sayısı yalnızca aynı varyantta karşılaştırılır.
                    guard r.hatID == hatID, close(r.board, board), close(r.alight, alight),
                          abs(r.meters - meters) < 1e-6,
                          r.geomIndex != geomIndex || r.ridePoints.count == pointCount
                    else {
                        Issue.record("\(name) [\(index)]: dolmuş bacağı farklı: \(r.hatID)/\(r.geomIndex) \(r.meters) m ≠ \(hatID)/\(geomIndex) \(meters) m")
                        return false
                    }
                default:
                    Issue.record("\(name) [\(index)]: bacak türü farklı")
                    return false
                }
            }
        }
        return true
    }

    private func close(_ a: Coordinate, _ b: Coordinate) -> Bool {
        abs(a.latitude - b.latitude) < 1e-9 && abs(a.longitude - b.longitude) < 1e-9
    }
}

// MARK: - Altın dosya kayıtları

private struct TripEntry: Decodable {
    let name: String
    let from: [Double]
    let to: [Double]
    let journeys: [JourneyEntry]

    struct JourneyEntry: Decodable {
        let key: String
        let estMinutes: Int
        let transfers: Int
        let walkMeters: Double
        let rideMeters: Double
        let feeMin: Int?
        let feeMax: Int?
        let score: Double
        let legs: [Leg]
    }

    enum Leg: Decodable {
        case walk(from: Coordinate, to: Coordinate, straight: Double, label: String)
        case ride(hatID: String, geomIndex: Int, board: Coordinate, alight: Coordinate, meters: Double, pointCount: Int)

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            switch try c.decode(String.self) {
            case "walk":
                let from = Coordinate(latitude: try c.decode(Double.self), longitude: try c.decode(Double.self))
                let to = Coordinate(latitude: try c.decode(Double.self), longitude: try c.decode(Double.self))
                self = .walk(from: from, to: to, straight: try c.decode(Double.self), label: try c.decode(String.self))
            default:
                let hatID = try c.decode(String.self)
                let geomIndex = try c.decode(Int.self)
                let board = Coordinate(latitude: try c.decode(Double.self), longitude: try c.decode(Double.self))
                let alight = Coordinate(latitude: try c.decode(Double.self), longitude: try c.decode(Double.self))
                self = .ride(hatID: hatID, geomIndex: geomIndex, board: board, alight: alight,
                             meters: try c.decode(Double.self), pointCount: try c.decode(Int.self))
            }
        }
    }
}
