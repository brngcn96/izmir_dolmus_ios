import Foundation
import Synchronization
import Testing
@testable import DolmusCore

@Suite("Yükleyici")
struct DataLoaderTests {
    /// Dört dosyanın elle yazılmış küçük birer örneği; gerçek dosyalarla aynı biçimde.
    static let fixtures: [DataFile: String] = [
        .routes: #"""
            {"schema": "test", "routes": [
              {"id": "A_r1", "group_id": "A", "group_name": "Alfa - Beta", "name": "ALFA-BETA",
               "stops": ["ALFA", "BETA"], "stops_norm": ["alfa", "beta"], "endpoints": ["ALFA", "BETA"],
               "distance_km": null, "fee": 40, "first_time": false, "source": "ibb", "ilce": "Konak"},
              {"id": "A_r2", "group_id": "A", "group_name": "Alfa - Beta", "name": "ALFA-GAMA",
               "stops": ["ALFA", "GAMA"], "stops_norm": ["alfa", "gama"], "endpoints": ["ALFA", "GAMA"],
               "distance_km": 3.5, "fee": null, "first_time": true, "source": "ibb", "ilce": "Konak"}
            ]}
            """#,
        .hatGeoms: #"""
            {"A": [
              {"ad": "kod_Alfa - Beta dönüş", "yon": "GİDİŞ", "pts": [[38.40, 27.10], [38.41, 27.11]], "board": "10"},
              {"ad": "Alfa - Beta gidiş", "yon": "GİDİŞ", "pts": [[38.41, 27.11], [38.40, 27.10]], "board": "11"},
              {"ad": "tek nokta", "yon": "GİDİŞ", "pts": [[38.40, 27.10]], "board": "1"}
            ]}
            """#,
        .duraklar: #"[["Alfa Durağı · Konak", 38.40, 27.10]]"#,
        .landmarks: #"[["Alfa Metro", 38.401, 27.101, "metro"]]"#,
    ]

    static func fixtureData(_ file: DataFile) -> Data {
        Data(fixtures[file, default: ""].utf8)
    }

    @Test("Dört dosyayı çözer ve veriyi kurar")
    func loadsFixtures() async throws {
        let data = try await DataLoader(read: Self.fixtureData).load()

        let hat = try #require(data.hats.first)
        #expect(data.hats.count == 1)
        #expect(hat.id == "A")
        #expect(hat.name == "Alfa - Beta")
        #expect(hat.segments.map(\.id) == ["A_r1", "A_r2"])
        #expect(hat.segments.map(\.fee) == [40, nil])
        #expect(hat.segments.map(\.distanceKm) == [nil, 3.5])
        #expect(hat.segments.map(\.firstTime) == [false, true])
        #expect(hat.feeLabel == "40 ₺")
        #expect(hat.keyStopNames == ["ALFA", "BETA", "GAMA"])
        #expect(data.districts.map(\.name) == ["Konak"])

        // Tek noktalı güzergah atılır; GİDİŞ öne geçer; ad ve yön temizlenir.
        let geoms = data.geoms(for: "A")
        #expect(geoms.map(\.ad) == ["Alfa - Beta", "Alfa - Beta"])
        #expect(geoms.map(\.yon) == ["GİDİŞ", "DÖNÜŞ"])
        #expect(geoms.map(\.boardable) == [[true, true], [true, false]])

        #expect(data.duraklar == [
            PlacePoint(label: "Alfa Durağı · Konak", coordinate: Coordinate(latitude: 38.40, longitude: 27.10)),
        ])
        #expect(data.landmarks == [
            Landmark(name: "Alfa Metro", coordinate: Coordinate(latitude: 38.401, longitude: 27.101), kind: "metro"),
        ])
    }

    @Test("Ana aktörden çağrılsa da dosyaları ana thread'de okumaz")
    @MainActor
    func runsOffMainThread() async throws {
        let log = ThreadLog()
        let loader = DataLoader { file in
            log.record()
            return Self.fixtureData(file)
        }
        _ = try await loader.load()
        #expect(log.wasOnMainThread == [false, false, false, false])
    }

    @Test("Okuma hatası çağırana ulaşır")
    func propagatesReadErrors() async {
        let loader = DataLoader { file in throw DataLoadError.missingResource(file) }
        await #expect(throws: DataLoadError.self) {
            try await loader.load()
        }
    }

    @Test("Bozuk dosya çözme hatası verir")
    func propagatesDecodingErrors() async {
        let loader = DataLoader { file in
            file == .duraklar ? Data(#"[["eksik", 38.4]]"#.utf8) : Self.fixtureData(file)
        }
        await #expect(throws: DecodingError.self) {
            try await loader.load()
        }
    }
}

/// Okuyucunun her çağrıda ana thread'de olup olmadığını kaydeder.
private final class ThreadLog: Sendable {
    private let entries = Mutex<[Bool]>([])

    func record() {
        entries.withLock { $0.append(Thread.isMainThread) }
    }

    var wasOnMainThread: [Bool] {
        entries.withLock { $0 }
    }
}
