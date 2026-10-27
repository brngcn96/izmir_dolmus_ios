/// Anlık hava durumu (Open-Meteo).
///
/// Cevap: `{"current": {"temperature_2m": 19.1, "weather_code": 1, …}, …}`.
public struct WeatherInfo: Sendable, Equatable, Decodable {
    /// °C.
    public let temperature: Double
    /// WMO hava kodu: 0 açık, 1-3 bulutlu, 61-67 yağmur…
    public let code: Int

    public init(temperature: Double, code: Int) {
        self.temperature = temperature
        self.code = code
    }

    private enum CodingKeys: String, CodingKey {
        case current
    }

    private enum CurrentKeys: String, CodingKey {
        case temperature = "temperature_2m"
        case code = "weather_code"
    }

    public init(from decoder: any Decoder) throws {
        let current = try decoder.container(keyedBy: CodingKeys.self)
            .nestedContainer(keyedBy: CurrentKeys.self, forKey: .current)
        temperature = try current.decode(Double.self, forKey: .temperature)
        code = try current.decode(Int.self, forKey: .code)
    }

    /// "19°": tam sayıya yuvarlanmış.
    public var temperatureLabel: String {
        "\(Int(temperature.rounded()))°"
    }

    /// Kısa durum adı ve SF Symbol adı (Flutter'daki `_weatherLook`).
    public var look: (title: String, symbol: String) {
        switch code {
        case 0: ("Açık", "sun.max.fill")
        case 1, 2: ("Az bulutlu", "cloud.sun.fill")
        case 3: ("Kapalı", "cloud.fill")
        case 45, 48: ("Sisli", "cloud.fog.fill")
        case 51...57: ("Çiseleme", "cloud.drizzle.fill")
        case 61...67: ("Yağmurlu", "cloud.rain.fill")
        case 71...77: ("Karlı", "cloud.snow.fill")
        case 80...82: ("Sağanak", "cloud.heavyrain.fill")
        case 85, 86: ("Kar", "cloud.snow.fill")
        case 95...: ("Gök gürültülü", "cloud.bolt.rain.fill")
        default: ("Hava", "thermometer.medium")
        }
    }
}
