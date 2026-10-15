// `ArrayDecoding.swift`'teki dizi biçiminin tersi: bir yer kaydedilirken de
// `["Konak · Konak", 38.41622, 27.12632]` olarak yazılır. Böylece veri
// dosyasından okunan ve cihazda saklanan yer aynı biçimi paylaşır.

extension PlacePoint: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(label)
        try container.encode(coordinate.latitude)
        try container.encode(coordinate.longitude)
    }
}
