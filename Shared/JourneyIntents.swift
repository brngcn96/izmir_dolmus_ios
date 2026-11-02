import AppIntents

/// Live Activity'deki düğmelerin uygulamadaki karşılığı. Düğmenin intent'i
/// (`LiveActivityIntent`) uygulamanın sürecinde çalışır; uygulama kapalıysa sistem
/// onu arka planda açar. Uygulama açılışta `JourneySession`'ı buraya bağlar. Widget
/// eklentisinde de derlenir (düğmeler orada çizilir) ama orada bağlanmaz.
@MainActor
final class JourneyActions {
    static let shared = JourneyActions()
    var advance: (() -> Void)?
    var end: (() -> Void)?
}

/// Karttaki "Sonraki adım": konum yetmediğinde elle ilerletme.
struct AdvanceJourneyIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Sonraki adım"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        JourneyActions.shared.advance?()
        return .result()
    }
}

/// Karttaki "Bitir": yolculuğu bitirir, konum takibi kapanır.
struct EndJourneyIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Yolculuğu bitir"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        JourneyActions.shared.end?()
        return .result()
    }
}
