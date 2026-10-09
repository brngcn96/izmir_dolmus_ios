/// Bir hattın ücret satırı: meclis kararındaki alt güzergahlardan biri
/// ("şuradan şuraya şu kadar").
public struct DolmusRoute: Sendable, Hashable, Identifiable, Decodable {
    public let id: String
    /// Bağlı olduğu hattın kimliği. Hat bölme kuralı satırı başka bir hatta
    /// taşıyabilir (bkz. `HatOverrides`).
    public private(set) var groupID: String
    public private(set) var groupName: String
    public let name: String
    /// Güzergah üzerindeki kilit noktalar, sırayla.
    public let stops: [String]
    /// `stops`'un `trNorm`'dan geçmiş hali; veri dosyasında hazır gelir.
    public let stopsNorm: [String]
    public let distanceKm: Double?
    /// Veri dosyasındaki ücret (TL). Kararda ücreti olmayan satırlarda `nil`.
    public let fee: Int?
    public let firstTime: Bool
    /// Hattın geçtiği ilçe(ler); birden çoksa " / " ile ayrılır.
    public let ilce: String?

    public init(
        id: String,
        groupID: String,
        groupName: String,
        name: String,
        stops: [String],
        stopsNorm: [String],
        distanceKm: Double? = nil,
        fee: Int?,
        firstTime: Bool = false,
        ilce: String? = nil
    ) {
        self.id = id
        self.groupID = groupID
        self.groupName = groupName
        self.name = name
        self.stops = stops
        self.stopsNorm = stopsNorm
        self.distanceKm = distanceKm
        self.fee = fee
        self.firstTime = firstTime
        self.ilce = ilce
    }

    // Dosyadaki adlar snake_case; Swift tarafındaki adlarla burada eşlenir.
    // `init(from:)`'u derleyici bu anahtarlardan kendisi üretir.
    enum CodingKeys: String, CodingKey {
        case id, name, stops, fee, ilce
        case groupID = "group_id"
        case groupName = "group_name"
        case stopsNorm = "stops_norm"
        case distanceKm = "distance_km"
        case firstTime = "first_time"
    }

    public var fromLabel: String { stops.first ?? "" }
    public var toLabel: String { stops.last ?? "" }

    /// Aynı satırın başka bir hatta taşınmış kopyası (hat bölme).
    func reassigned(toGroup id: String, name: String) -> DolmusRoute {
        var copy = self
        copy.groupID = id
        copy.groupName = name
        return copy
    }
}
