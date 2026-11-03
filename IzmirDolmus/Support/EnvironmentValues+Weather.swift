import SwiftUI

extension EnvironmentValues {
    /// Anasayfa'daki hava durumunun ve künyesinin kaynağı (WeatherKit).
    /// Önizlemede ya da testte `.environment(\.weatherProvider, …)` ile sahtesi verilir.
    @Entry var weatherProvider: any WeatherProvider = AppEnvironment.weather
}
