import AppIntents
import DolmusCore
import WidgetKit

/// Widget'taki ⇄: uygulamayı açmadan yönü çevirir. Seçim sıradaki otomatik
/// değişime (04:00 ya da 14:00) kadar geçerli.
///
/// Widget'taki bir düğmenin intent'i widget eklentisinde çalışır; uygulama
/// açılmaz. Paylaşılan tek yer App Group olduğu için seçim oraya yazılır.
struct ToggleCommuteDirectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Yönü değiştir"
    static let description = IntentDescription("Eve / İşe widget'ında yönü çevirir.")
    /// Kısayollar'da ayrı bir eylem olarak görünmesin; yalnızca widget'ın düğmesi.
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        AppGroup.commuteOverride = CommuteOverride.toggled(from: AppGroup.commuteOverride, at: .now)
        return .result()
    }
}
