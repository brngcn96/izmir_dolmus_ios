extension Coordinate: Decodable {
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let latitude = try container.decode(Double.self)
        let longitude = try container.decode(Double.self)
        self.init(latitude: latitude, longitude: longitude)
    }
}

extension PlacePoint: Decodable {
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let label = try container.decode(String.self)
        let latitude = try container.decode(Double.self)
        let longitude = try container.decode(Double.self)
        self.init(label: label, coordinate: Coordinate(latitude: latitude, longitude: longitude))
    }
}

extension Landmark: Decodable {
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let name = try container.decode(String.self)
        let latitude = try container.decode(Double.self)
        let longitude = try container.decode(Double.self)
        let kind = try container.decode(String.self)
        self.init(
            name: name,
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            kind: kind
        )
    }
}
