import AppIntents
import SwiftUI
import WidgetKit

/// Control Center, kilit ekranı ve Eylem düğmesi için "Yol tarifi" kontrolü.
/// Kontrol bir görüntü değil, bir eylemdir: dokununca intent çalışır.
struct TripPlannerControl: ControlWidget {
    static let kind = "com.izmirdolmus.app.TripPlannerControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenTripPlannerIntent()) {
                Label("Yol tarifi", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
            }
        }
        .displayName("Yol tarifi")
        .description("İzmir Dolmuş'ta Nereden → Nereye'yi açar.")
    }
}

/// "Eve git" kontrolü: varışı Ev olan yol tarifi.
struct GoHomeControl: ControlWidget {
    static let kind = "com.izmirdolmus.app.GoHomeControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenGoHomeIntent()) {
                Label("Eve git", systemImage: "house.fill")
            }
        }
        .displayName("Eve git")
        .description("Varışı Ev olan yol tarifini açar.")
    }
}
