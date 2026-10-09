import Foundation
import Testing
@testable import DolmusCore

@Suite("Dizi biçimli JSON")
struct ArrayDecodingTests {
    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    @Test("Nokta: [enlem, boylam]")
    func coordinate() throws {
        let decoded = try decode(Coordinate.self, from: "[38.41622, 27.12632]")
        #expect(decoded == Coordinate(latitude: 38.41622, longitude: 27.12632))
    }

    @Test("Yer: [ad, enlem, boylam]")
    func placePoint() throws {
        let decoded = try decode(PlacePoint.self, from: #"["Konak · Konak", 38.41622, 27.12632]"#)
        #expect(decoded == PlacePoint(
            label: "Konak · Konak",
            coordinate: Coordinate(latitude: 38.41622, longitude: 27.12632)
        ))
    }

    @Test("Önemli nokta: [ad, enlem, boylam, tür]")
    func landmark() throws {
        let decoded = try decode(Landmark.self, from: #"["Konak", 38.41881, 27.12855, "metro"]"#)
        #expect(decoded == Landmark(
            name: "Konak",
            coordinate: Coordinate(latitude: 38.41881, longitude: 27.12855),
            kind: "metro"
        ))
    }

    @Test("Dizi içinde dizi: bir dosyanın tamamı")
    func arrayOfPlaces() throws {
        let decoded = try decode([PlacePoint].self, from: #"[["A", 1, 2], ["B", 3.5, 4.5]]"#)
        #expect(decoded.map(\.label) == ["A", "B"])
        #expect(decoded.map(\.coordinate.longitude) == [2, 4.5])
    }

    @Test("Eksik eleman hata verir")
    func rejectsShortArrays() {
        #expect(throws: DecodingError.self) { try decode(Coordinate.self, from: "[38.4]") }
        #expect(throws: DecodingError.self) { try decode(PlacePoint.self, from: #"["Konak", 38.4]"#) }
        #expect(throws: DecodingError.self) { try decode(Landmark.self, from: #"["Konak", 38.4, 27.1]"#) }
    }

    @Test("Yanlış sıradaki eleman hata verir")
    func rejectsWrongTypes() {
        #expect(throws: DecodingError.self) { try decode(PlacePoint.self, from: #"[38.4, 27.1, "Konak"]"#) }
    }
}
