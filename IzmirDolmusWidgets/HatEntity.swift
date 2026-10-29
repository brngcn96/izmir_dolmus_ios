import AppIntents
import DolmusCore

/// Widget'ın yapılandırmasında seçilebilen bir hat. Sistem seçimi `id` ile
/// saklar; widget her çizimde güncel bilgiyi özetten yeniden bulur.
struct HatEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Hat"
    static let defaultQuery = HatQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(_ hat: WidgetSnapshot.Hat) {
        id = hat.id
        name = hat.name
    }
}

/// Hat listesini uygulamanın yazdığı özetten verir: önerilerde favoriler,
/// aramada bütün hatlar (Türkçe harf duyarsız).
struct HatQuery: EntityStringQuery {
    /// Saklanan seçimleri kimlikle çözer.
    func entities(for identifiers: [String]) async throws -> [HatEntity] {
        let catalog = AppGroup.readSnapshot()?.catalog ?? []
        return identifiers.compactMap { id in catalog.first { $0.id == id }.map(HatEntity.init) }
    }

    /// Seçim listesi açılınca görünenler: favoriler; favori yoksa ilk hatlar.
    func suggestedEntities() async throws -> [HatEntity] {
        guard let snapshot = AppGroup.readSnapshot() else { return [] }
        let hats = snapshot.favorites.isEmpty ? Array(snapshot.catalog.prefix(30)) : snapshot.favorites
        return hats.map(HatEntity.init)
    }

    /// Arama kutusuna yazılınca.
    func entities(matching string: String) async throws -> [HatEntity] {
        let query = trNorm(string)
        return (AppGroup.readSnapshot()?.catalog ?? [])
            .filter { trNorm($0.name).contains(query) }
            .map(HatEntity.init)
    }
}

/// Favori hat widget'ının ayarı: hangi hat gösterilsin.
struct SelectHatIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Hat seç"
    static let description = IntentDescription("Widget'ta gösterilecek hattı seç.")

    @Parameter(title: "Hat")
    var hat: HatEntity?
}
