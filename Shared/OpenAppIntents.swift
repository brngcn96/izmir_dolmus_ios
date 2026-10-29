import AppIntents
import DolmusCore
import Observation

/// Uygulama dışından (Control Center kontrolleri) gelen ve uygulamada
/// gösterilecek adres. Intent uygulamanın sürecinde çalışınca buraya yazar;
/// `RootView` okuyup Router'a çevirir.
///
/// Bu klasör (`Shared/`) hem uygulamada hem widget eklentisinde derlenir:
/// kontrol eklentide tanımlı, intent'i ise uygulama açılınca uygulamada çalışır.
@MainActor
@Observable
final class PendingDeepLink {
    static let shared = PendingDeepLink()
    var link: DeepLink?
}

/// Control Center'daki "Yol tarifi": uygulamayı açar, "Nereden → Nereye"yi gösterir.
struct OpenTripPlannerIntent: AppIntent {
    static let title: LocalizedStringResource = "Yol tarifi"
    static let description = IntentDescription("İzmir Dolmuş'ta Nereden → Nereye sayfasını açar.")
    /// Önce uygulama öne gelir, sonra `perform` uygulamanın sürecinde çalışır.
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingDeepLink.shared.link = .tripPlanner
        return .result()
    }
}

/// Control Center'daki "Eve git": varışı Ev olan yol tarifini açar.
struct OpenGoHomeIntent: AppIntent {
    static let title: LocalizedStringResource = "Eve git"
    static let description = IntentDescription("İzmir Dolmuş'ta varışı Ev olan yol tarifini açar.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingDeepLink.shared.link = .goHome
        return .result()
    }
}
