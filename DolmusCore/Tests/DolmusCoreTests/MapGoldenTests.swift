import Foundation
import Testing
@testable import DolmusCore

/// Harita hesaplarının (yakın hatlar, görünür noktalar, kategoriler) Flutter'ın
/// gerçek koduyla aynı sonucu verdiği (`Golden/*.json`, `export-golden.sh`).
@Suite struct MapGoldenTests {
    @Test("Yakın hatlar: aynı hatlar, aynı uzaklıklar, aynı sıra")
    func nearbyHats() async throws {
        let data = try await Bundled.data.value
        let entries: [NearbyEntry] = try Golden.load("nearby_hats.json")
        try #require(entries.count > 100)
        var budget = FailureBudget()
        for entry in entries where !budget.isExhausted {
            let point = Coordinate(latitude: entry.p[0], longitude: entry.p[1])
            let actual = data.nearbyHats(to: point, maxMeters: entry.max, limit: entry.limit)
            let ok = expectSameIgnoringTies(
                actual.map { ($0.hat.id, $0.meters) },
                flutter: entry.results.map { ($0.id, $0.meters) },
                sameKey: { abs($0 - $1) < 1e-6 },
                "nearbyHats(\(entry.p), \(entry.max))"
            )
            budget.note(ok)
        }
    }

    @Test("Görünür alandaki noktalar: aynı noktalar, öncelik ve yakınlık sırası")
    func poisInView() async throws {
        let data = try await Bundled.data.value
        let entries: [PoiEntry] = try Golden.load("pois_in_view.json")
        try #require(entries.count == 20)
        var budget = FailureBudget()
        for entry in entries where !budget.isExhausted {
            let box = GeoBox(south: entry.box[0], north: entry.box[1], west: entry.box[2], east: entry.box[3])
            let center = box.center
            func key(_ type: String, _ c: Coordinate) -> (Int, Double) {
                let dy = c.latitude - center.latitude, dx = c.longitude - center.longitude
                return (PoiRules.priority(for: type), dy * dy + dx * dx)
            }
            let actual = data.poisInView(box, zoom: entry.zoom).map {
                ("\($0.label)|\($0.type)|\($0.coordinate.latitude)|\($0.coordinate.longitude)", key($0.type, $0.coordinate))
            }
            let expected = entry.results.map {
                ("\($0.label)|\($0.type)|\($0.latitude)|\($0.longitude)", key($0.type, Coordinate(latitude: $0.latitude, longitude: $0.longitude)))
            }
            let ok = expectSameIgnoringTies(actual, flutter: expected, sameKey: { $0.0 == $1.0 && abs($0.1 - $1.1) < 1e-15 }, "poisInView(\(entry.box), z\(entry.zoom))")
            budget.note(ok)
        }
    }

    @Test("Kategoriler: aynı yerler, aynı (yuvarlanmış) uzaklık sırası")
    func placesInCategory() async throws {
        let data = try await Bundled.data.value
        let entries: [CategoryEntry] = try Golden.load("places_in_category.json")
        try #require(entries.count == 24)
        var budget = FailureBudget()
        for entry in entries where !budget.isExhausted {
            let near = Coordinate(latitude: entry.near[0], longitude: entry.near[1])
            let actual = data.placesInCategory(Set(entry.types), near: near).map {
                ("\($0.label)|\($0.coordinate.latitude)", near.meters(to: $0.coordinate))
            }
            let expected = entry.results.map { ("\($0.label)|\($0.latitude)", $0.meters) }
            let ok = expectSameIgnoringTies(actual, flutter: expected, sameKey: { $0 == $1 }, "placesInCategory(\(entry.types))")
            budget.note(ok)
        }
    }

    @Test("Çizgiye dokunma: çizginin üstündeki nokta o hattı, uzaktaki hiçbir şeyi bulmaz")
    func linesAtPoint() async throws {
        let data = try await Bundled.data.value
        let line = try #require(data.geoms(for: "M41").first?.points)
        let onLine = line[line.count / 2]
        let others = data.nearbyHats(to: onLine).map(\.hat.id).filter { $0 != "M41" }.prefix(3)
        let ids = ["M41"] + others
        let hits = data.hats(onLinesOf: ids, near: onLine, toleranceMeters: 30).map(\.id)
        #expect(hits.first == "M41")
        // Hatların ilk güzergahına 30 m'den yakın olanlar; sıra verilen sıra.
        #expect(hits == ids.filter { id in
            (data.geoms(for: id).first.map { onLine.distance(toLine: $0.points) } ?? .infinity) <= 30
        })
        let far = Coordinate(latitude: onLine.latitude + 0.05, longitude: onLine.longitude)
        #expect(data.hats(onLinesOf: ids, near: far, toleranceMeters: 30).isEmpty)
    }

    @Test("Vincenty: bilinen bir uzaklık ve aynı nokta")
    func vincenty() {
        let konak = Coordinate(latitude: 38.4189, longitude: 27.1287)
        let bornova = Coordinate(latitude: 38.4697, longitude: 27.2211)
        #expect((9_000...10_000).contains(konak.meters(to: bornova)))
        #expect(konak.meters(to: konak) == 0)
        #expect(konak.meters(to: bornova) == bornova.meters(to: konak))
    }

    @Test("Binilebilir en yakın nokta otoyol parçasını atlar")
    func boardableSkipsMotorway() {
        // Düz bir doğu-batı çizgisi; ortadaki parça binilemez (otoyol).
        let line = [
            Coordinate(latitude: 38.40, longitude: 27.10),
            Coordinate(latitude: 38.40, longitude: 27.11),
            Coordinate(latitude: 38.40, longitude: 27.12),
            Coordinate(latitude: 38.40, longitude: 27.13),
        ]
        let geom = HatGeom(ad: "test", yon: "GİDİŞ", points: line, boardable: [true, true, false, true])
        let probe = Coordinate(latitude: 38.401, longitude: 27.115)   // binilemeyen parçanın yanı
        let hit = try? #require(geom.nearestBoardable(to: probe))
        #expect(hit?.point.longitude ?? 0 <= 27.11 + 1e-9)            // binilebilir ilk parçaya düştü
        let plain = HatGeom(ad: "test", yon: "GİDİŞ", points: line)
        #expect((plain.nearestBoardable(to: probe)?.meters ?? .infinity) < (hit?.meters ?? 0))
    }
}

// MARK: - Altın dosya kayıtları

private struct NearbyEntry: Decodable {
    let p: [Double]
    let max: Double
    let limit: Int
    let results: [Item]

    struct Item: Decodable {
        let id: String
        let meters: Double
        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            id = try c.decode(String.self)
            meters = try c.decode(Double.self)
        }
    }
}

private struct PoiEntry: Decodable {
    let box: [Double]
    let zoom: Double
    let results: [Item]

    struct Item: Decodable {
        let label: String
        let type: String
        let latitude: Double
        let longitude: Double
        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            label = try c.decode(String.self)
            type = try c.decode(String.self)
            latitude = try c.decode(Double.self)
            longitude = try c.decode(Double.self)
        }
    }
}

private struct CategoryEntry: Decodable {
    let types: [String]
    let near: [Double]
    let results: [Item]

    struct Item: Decodable {
        let label: String
        let latitude: Double
        let longitude: Double
        let meters: Double
        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            label = try c.decode(String.self)
            latitude = try c.decode(Double.self)
            longitude = try c.decode(Double.self)
            meters = try c.decode(Double.self)
        }
    }
}

/// Dart'ın `List.sort`'u 32'den uzun listelerde kararsız: sıralama anahtarı
/// eşit olan elemanlar Flutter'da herhangi bir sırada gelebilir. Bu yüzden
/// ardışık eşit anahtarlı gruplar küme olarak karşılaştırılır. Listenin sonunda
/// kırpılmış son grubun üyeleri farklı olabilir; yalnızca boyu karşılaştırılır.
private func expectSameIgnoringTies<Key>(
    _ actual: [(String, Key)],
    flutter expected: [(String, Key)],
    sameKey: (Key, Key) -> Bool,
    _ what: String,
    sourceLocation: SourceLocation = #_sourceLocation
) -> Bool {
    func groups(_ items: [(String, Key)]) -> [(key: Key, members: [String])] {
        var result: [(key: Key, members: [String])] = []
        for (member, key) in items {
            if let last = result.last, sameKey(last.key, key) {
                result[result.count - 1].members.append(member)
            } else {
                result.append((key, [member]))
            }
        }
        return result
    }
    guard actual.count == expected.count else {
        Issue.record("\(what): Swift \(actual.count) sonuç, Flutter \(expected.count)", sourceLocation: sourceLocation)
        return false
    }
    let a = groups(actual), e = groups(expected)
    guard a.count == e.count else {
        let firstDiff = actual.indices.first { actual[$0].0 != expected[$0].0 } ?? -1
        Issue.record("\(what): sıralama grupları farklı; ilk fark [\(firstDiff)]: Swift \(firstDiff >= 0 ? actual[firstDiff].0 : "-") ≠ Flutter \(firstDiff >= 0 ? expected[firstDiff].0 : "-")", sourceLocation: sourceLocation)
        return false
    }
    for (index, (ga, ge)) in zip(a, e).enumerated() {
        let isLast = index == a.count - 1
        guard sameKey(ga.key, ge.key), ga.members.count == ge.members.count,
              isLast || Set(ga.members) == Set(ge.members)
        else {
            Issue.record("\(what): grup \(index) farklı: Swift \(ga.members.prefix(3)) ≠ Flutter \(ge.members.prefix(3))", sourceLocation: sourceLocation)
            return false
        }
    }
    return true
}
