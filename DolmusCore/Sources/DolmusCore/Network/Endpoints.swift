import Foundation

/// İBB'nin dolmuş ücret servisi: bir hat kodunun güncel ücret satırları.
/// Bilinmeyen kod için de 200 ve boş dizi döner.
public struct FaresEndpoint: Endpoint {
    public typealias Response = [FareRow]

    public let code: String

    public init(code: String) {
        self.code = code
    }

    public var url: URL {
        // Kodlarda Türkçe harf var (ÖDM05, FOÇ01); `appending(path:)` yüzde kodlar.
        URL(string: "https://minibusguzergahlari.izmir.bel.tr/api/minibus/ucretler")!
            .appending(path: code)
    }
}

/// İzmir etkinlikleri: Ticketmaster (Biletix) ve İBB'den GitHub'da 6 saatte bir
/// üretilen hazır liste. Uygulama Ticketmaster'a doğrudan gitmez.
public struct EventsEndpoint: Endpoint {
    public typealias Response = EventFeed

    public init() {}

    public var url: URL {
        URL(string: "https://raw.githubusercontent.com/marfuj/izmir_dolmus_data/main/events_izmir.json")!
    }

    public var timeout: TimeInterval { 10 }
}

/// Open-Meteo'dan anlık sıcaklık ve hava kodu; API anahtarı gerekmez.
public struct WeatherEndpoint: Endpoint {
    public typealias Response = WeatherInfo

    public let coordinate: Coordinate

    public init(coordinate: Coordinate) {
        self.coordinate = coordinate
    }

    public var url: URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
        ]
        return components.url!
    }

    public var timeout: TimeInterval { 8 }
}

/// Geliştiricinin Google Form'una geri bildirim metni gönderir (tek "uzun
/// yanıt" alanı; yanıtlar Google Sheets'te görünür). Android uygulamasıyla aynı form.
public struct FeedbackEndpoint: Endpoint {
    public typealias Response = Void

    static let formID = "1FAIpQLSe_5UyuzJsh7cEkYc8-EgO29VoXCgzZ5U2smbp8n3u01_k9hg"
    static let entryID = "entry.66917862"

    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var url: URL {
        URL(string: "https://docs.google.com/forms/d/e/\(Self.formID)/formResponse")!
    }

    public var method: HTTPMethod { .post }

    public var headers: [String: String] {
        ["Content-Type": "application/x-www-form-urlencoded"]
    }

    public var body: Data? {
        Data("\(Self.entryID)=\(Self.formEncoded(text))".utf8)
    }

    /// Google Form başarıda bir onay sayfası (HTML) döner; içeriği önemli değil,
    /// 2xx olması yeter.
    public func decode(_ data: Data) throws {}

    /// Form gövdesi için yüzde kodlama. `URLComponents` "+" ve "&" gibi
    /// karakterleri bırakır; formda "+" boşluk okunur, "&" alanı böler.
    static func formEncoded(_ text: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._*")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}
