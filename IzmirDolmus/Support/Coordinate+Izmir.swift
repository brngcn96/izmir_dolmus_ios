import CoreLocation
import DolmusCore

extension Coordinate {
    /// İzmir'in merkezi; harita açılmadan yapılan yer aramalarında yakınlık
    /// sıralaması buna göre yapılır (Flutter'daki `_izmirCenter`).
    static let izmirCenter = Coordinate(latitude: 38.4237, longitude: 27.1428)
}

extension Coordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
