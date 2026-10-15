import Foundation
import Testing
@testable import DolmusCore

@Suite("Dizi biçiminde yazma")
struct ArrayEncodingTests {
    @Test("Yer, okunduğu biçimde yazılır")
    func encodesPlacePoint() throws {
        let place = PlacePoint(label: "Konak · Konak", coordinate: Coordinate(latitude: 38.41622, longitude: 27.12632))
        let json = String(decoding: try JSONEncoder().encode(place), as: UTF8.self)
        #expect(json == #"["Konak · Konak",38.41622,27.12632]"#)
    }

    @Test("Yaz, geri oku: aynı değer")
    func roundTrips() throws {
        let places = [
            PlacePoint(label: "Ev", coordinate: Coordinate(latitude: 38.4, longitude: 27.1)),
            PlacePoint(label: "İş · Bornova", coordinate: Coordinate(latitude: 38.46, longitude: 27.21)),
        ]
        let decoded = try JSONDecoder().decode([PlacePoint].self, from: JSONEncoder().encode(places))
        #expect(decoded == places)
    }
}
