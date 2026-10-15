import DolmusCore

extension Coordinate {
    /// İzmir'in merkezi; harita açılmadan yapılan yer aramalarında yakınlık
    /// sıralaması buna göre yapılır (Flutter'daki `_izmirCenter`).
    static let izmirCenter = Coordinate(latitude: 38.4237, longitude: 27.1428)
}
