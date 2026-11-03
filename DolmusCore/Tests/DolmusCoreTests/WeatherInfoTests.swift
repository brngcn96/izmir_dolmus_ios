import Testing
import WeatherKit
@testable import DolmusCore

/// Hava durumunun görünümü: WeatherKit'in durum adlarından Türkçe ad ve simge.
@Suite struct WeatherInfoTests {
    @Test("Sıcaklık tam sayıya yuvarlanır")
    func temperatureLabel() {
        #expect(WeatherInfo(temperature: 19.6, condition: "rain").temperatureLabel == "20°")
        #expect(WeatherInfo(temperature: -0.4, condition: "clear").temperatureLabel == "0°")
    }

    @Test("Durum adı ve simge; açık ve az bulutluda gece ay")
    func look() {
        #expect(WeatherInfo(temperature: 9, condition: "rain").look == ("Yağmurlu", "cloud.rain.fill"))
        #expect(WeatherInfo(temperature: 9, condition: "partlyCloudy").look.symbol == "cloud.sun.fill")
        #expect(WeatherInfo(temperature: 9, condition: "partlyCloudy", isDaylight: false).look.symbol == "cloud.moon.fill")
        #expect(WeatherInfo(temperature: 9, condition: "clear", isDaylight: false).look == ("Açık", "moon.stars.fill"))
        #expect(WeatherInfo(temperature: 9, condition: "scatteredThunderstorms").look.title == "Gök gürültülü")
        #expect(WeatherInfo(temperature: 9, condition: "bilinmeyen").look == ("Hava", "thermometer.medium"))
    }

    /// WeatherKit'e yeni bir durum eklenirse ya da biri unutulursa yakalanır.
    @Test("WeatherKit'in bütün durumlarının bir adı var", arguments: WeatherCondition.allCases)
    func everyConditionHasATitle(condition: WeatherCondition) {
        #expect(WeatherInfo(temperature: 20, condition: condition.rawValue).look.title != "Hava")
    }
}
