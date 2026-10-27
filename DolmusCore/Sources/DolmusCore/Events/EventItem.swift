import Foundation

/// Bir etkinlik: konser, tiyatro, sergi…
public struct EventItem: Sendable, Hashable, Identifiable {
    public let id: String
    /// `ticketmaster` ya da `ibb`.
    public let source: String
    public let title: String
    /// Kaynaktaki tür: "Music", "Arts & Theatre", "SERGİ"…
    public let category: String?
    /// Başlangıç; listede tarihi olmayan etkinlik de olabilir.
    public let start: Date?
    /// Bitiş; yalnızca bazı İBB sergilerinde var.
    public let end: Date?
    public let venue: String?
    /// Mekanın konumu; yoksa haritada gösterilemez.
    public let coordinate: Coordinate?
    public let imageURL: URL?
    /// Alt tür: "Rock", "Tiyatro"…
    public let genre: String?
    /// Kısa açıklama (çoğunda yok).
    public let details: String?
    public let priceMin: Double?
    public let priceMax: Double?
    public let currency: String?

    public init(
        id: String,
        source: String,
        title: String,
        category: String? = nil,
        start: Date? = nil,
        end: Date? = nil,
        venue: String? = nil,
        coordinate: Coordinate? = nil,
        imageURL: URL? = nil,
        genre: String? = nil,
        details: String? = nil,
        priceMin: Double? = nil,
        priceMax: Double? = nil,
        currency: String? = nil
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.category = category
        self.start = start
        self.end = end
        self.venue = venue
        self.coordinate = coordinate
        self.imageURL = imageURL
        self.genre = genre
        self.details = details
        self.priceMin = priceMin
        self.priceMax = priceMax
        self.currency = currency
    }

    /// Flutter'daki üç kaba türden biri (filtre ve simge için).
    public var kind: EventCategory { EventCategory(rawCategory: category) }
}

// Liste dışarıda üretiliyor: alanlar eksik ya da beklenmeyen tipte gelebilir.
// Başlığı olmayan etkinlik atlanır; diğer alanlar bozuksa yalnızca o alan boş sayılır.
extension EventItem: Codable {
    enum CodingKeys: String, CodingKey {
        case id, source, title, category, start, end, venue, lat, lng, image, genre, currency
        case details = "desc"
        case priceMin = "price_min"
        case priceMax = "price_max"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys) -> String? {
            let value = ((try? container.decodeIfPresent(String.self, forKey: key)) ?? nil)?.dartTrimmed()
            return value?.isEmpty == false ? value : nil
        }
        func number(_ key: CodingKeys) -> Double? {
            (try? container.decodeIfPresent(Double.self, forKey: key)) ?? nil
        }

        guard let title = text(.title) else {
            throw DecodingError.dataCorruptedError(forKey: .title, in: container, debugDescription: "Başlıksız etkinlik")
        }
        let source = text(.source) ?? ""
        let start = text(.start).flatMap(EventDate.parse)
        let coordinate: Coordinate? = if let lat = number(.lat), let lng = number(.lng) {
            Coordinate(latitude: lat, longitude: lng)
        } else {
            nil
        }
        self.init(
            // Kimliksiz gelirse listede çakışmasın diye kaynak, başlık ve tarihten üretilir.
            id: text(.id) ?? "\(source)|\(title)|\(start?.timeIntervalSince1970 ?? 0)",
            source: source,
            title: title,
            category: text(.category),
            start: start,
            end: text(.end).flatMap(EventDate.parse),
            venue: text(.venue),
            coordinate: coordinate,
            imageURL: text(.image).flatMap(URL.init(string:)),
            genre: text(.genre),
            details: text(.details),
            priceMin: number(.priceMin),
            priceMax: number(.priceMax),
            currency: text(.currency)
        )
    }

    /// Kaynaktaki biçimle yazar; önbellek aynı çözücüyle geri okunur.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source, forKey: .source)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(start.map(EventDate.format), forKey: .start)
        try container.encodeIfPresent(end.map(EventDate.format), forKey: .end)
        try container.encodeIfPresent(venue, forKey: .venue)
        try container.encodeIfPresent(coordinate?.latitude, forKey: .lat)
        try container.encodeIfPresent(coordinate?.longitude, forKey: .lng)
        try container.encodeIfPresent(imageURL?.absoluteString, forKey: .image)
        try container.encodeIfPresent(genre, forKey: .genre)
        try container.encodeIfPresent(details, forKey: .details)
        try container.encodeIfPresent(priceMin, forKey: .priceMin)
        try container.encodeIfPresent(priceMax, forKey: .priceMax)
        try container.encodeIfPresent(currency, forKey: .currency)
    }
}

/// `events_izmir.json`'un içeriği.
///
/// Dosya `{"updated": …, "events": [ … ]}` biçiminde; düz bir dizi de kabul
/// edilir. Çözülemeyen etkinlik listeyi bozmaz, atlanır.
public struct EventFeed: Sendable, Codable {
    public var events: [EventItem]

    public init(events: [EventItem]) {
        self.events = events
    }

    enum CodingKeys: String, CodingKey {
        case events
    }

    public init(from decoder: any Decoder) throws {
        var list = if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            try container.nestedUnkeyedContainer(forKey: .events)
        } else {
            try decoder.unkeyedContainer()
        }
        var events: [EventItem] = []
        while !list.isAtEnd {
            if let event = try? list.decode(EventItem.self) {
                events.append(event)
            } else {
                // Çözülemeyen eleman atlanır. Başarısız `decode` imleci ilerletmez;
                // boş bir tiple okunmazsa döngü aynı elemanda takılı kalır.
                _ = try? list.decode(Skipped.self)
            }
        }
        self.events = events
    }

    /// Hiçbir şey okumayan tip: yalnızca imleci bir eleman ilerletmek için.
    /// `init(from:)` derleyiciye bırakılsaydı nesne beklerdi ve dizideki bir
    /// sayıda ya da metinde o da başarısız olurdu.
    private struct Skipped: Decodable {
        init(from decoder: any Decoder) {}
    }
}
