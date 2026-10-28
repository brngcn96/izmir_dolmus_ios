import Foundation
import Testing
@testable import DolmusCore

/// Konumun adı ve ilçesi (Anasayfa'nın başlığı ve hava durumu için).
@Suite struct LocationNameTests {
    @Test("Etiketten ilçe: yalnızca İzmir'in ilçeleri, yoksa İzmir", arguments: [
        ("Bornova Metro · Bornova", "Bornova"),
        ("Kordon · Konak", "Konak"),
        ("Fikri Altay · ÇİĞLİ", "ÇİĞLİ"),
        ("Evka 3 · Bornova ", "Bornova"),
        ("Atatürk Cd. · Alsancak", "İzmir"),
        ("Konak", "İzmir"),
        ("", "İzmir"),
    ] as [(String, String)])
    func district(label: String, expected: String) {
        #expect(IzmirDistrict.name(fromLabel: label) == expected)
    }

    @Test func districtOfNoLabel() {
        #expect(IzmirDistrict.name(fromLabel: nil) == "İzmir")
        #expect(IzmirDistrict.isDistrict("Karşıyaka"))
        #expect(!IzmirDistrict.isDistrict("İzmir"))
    }

    @Test("En yakın yer: bir yerin kendi konumunda uzaklık 0")
    func nearestPlaceAtItself() async throws {
        let data = try await Bundled.data.value
        try #require(data.duraklar.count > 1000)
        for index in stride(from: 0, to: data.duraklar.count, by: data.duraklar.count / 7) {
            let place = data.duraklar[index]
            let nearest = try #require(data.nearestPlace(to: place.coordinate))
            #expect(nearest.meters == 0)
            #expect(nearest.place.coordinate == place.coordinate)
        }
    }

    @Test("En yakın yer: listedeki bütün yerlerden yakın ya da eşit")
    func nearestPlaceIsMinimum() async throws {
        let data = try await Bundled.data.value
        let point = Coordinate(latitude: 38.4622, longitude: 27.2160)
        let nearest = try #require(data.nearestPlace(to: point))
        let minimum = data.duraklar.map { point.meters(to: $0.coordinate) }.min()
        #expect(nearest.meters == minimum)
        #expect(nearest.meters < 300)
    }
}
