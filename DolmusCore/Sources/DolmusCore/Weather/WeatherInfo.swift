/// Anlık hava durumu: sıcaklık ve kısa durum. Uygulamada kaynağı WeatherKit;
/// durum, WeatherKit'in `WeatherCondition` adıyla gelir ("partlyCloudy").
public struct WeatherInfo: Sendable, Equatable {
    /// °C.
    public let temperature: Double
    /// WeatherKit'in durum adı (`WeatherCondition.rawValue`).
    public let condition: String
    /// Gündüz mü: açık ve az bulutlu havada güneş ya da ay simgesi için.
    public let isDaylight: Bool

    public init(temperature: Double, condition: String, isDaylight: Bool = true) {
        self.temperature = temperature
        self.condition = condition
        self.isDaylight = isDaylight
    }

    /// "19°": tam sayıya yuvarlanmış.
    public var temperatureLabel: String {
        "\(Int(temperature.rounded()))°"
    }

    /// Kısa durum adı ve SF Symbol adı. Başlıkta ilçe adının yanına tek satır sığmalı.
    public var look: (title: String, symbol: String) {
        switch condition {
        case "clear", "mostlyClear":
            ("Açık", isDaylight ? "sun.max.fill" : "moon.stars.fill")
        case "hot":
            ("Sıcak", "sun.max.fill")
        case "partlyCloudy":
            ("Az bulutlu", isDaylight ? "cloud.sun.fill" : "cloud.moon.fill")
        case "mostlyCloudy":
            ("Çok bulutlu", "cloud.fill")
        case "cloudy":
            ("Kapalı", "cloud.fill")
        case "foggy", "haze", "smoky", "blowingDust":
            ("Sisli", "cloud.fog.fill")
        case "drizzle", "freezingDrizzle":
            ("Çiseleme", "cloud.drizzle.fill")
        case "rain", "freezingRain", "sunShowers":
            ("Yağmurlu", "cloud.rain.fill")
        case "heavyRain":
            ("Sağanak", "cloud.heavyrain.fill")
        case "flurries", "sunFlurries", "snow":
            ("Karlı", "cloud.snow.fill")
        case "heavySnow", "blowingSnow", "blizzard":
            ("Yoğun kar", "cloud.snow.fill")
        case "sleet", "wintryMix":
            ("Karla karışık", "cloud.sleet.fill")
        case "hail":
            ("Dolu", "cloud.hail.fill")
        case "frigid":
            ("Dondurucu", "thermometer.snowflake")
        case "isolatedThunderstorms", "scatteredThunderstorms", "thunderstorms", "strongStorms", "tropicalStorm", "hurricane":
            ("Gök gürültülü", "cloud.bolt.rain.fill")
        case "breezy", "windy":
            ("Rüzgârlı", "wind")
        default:
            ("Hava", "thermometer.medium")
        }
    }
}
