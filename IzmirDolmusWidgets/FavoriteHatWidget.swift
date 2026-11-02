import AppIntents
import DolmusCore
import SwiftUI
import WidgetKit

// MARK: - Girdi ve sağlayıcı

struct FavoriteHatEntry: TimelineEntry {
    let date: Date
    /// Küçük boyda gösterilen: seçilen hat, seçim yoksa ilk favori.
    let selected: WidgetSnapshot.Hat?
    /// Orta boyda: seçilen hat başta, sonra öteki favoriler.
    let hats: [WidgetSnapshot.Hat]
    /// Uygulama hiç özet yazmadıysa `false`.
    let hasSnapshot: Bool
}

/// Yapılandırmalı sağlayıcı: her çağrıda kullanıcının seçtiği intent gelir.
/// Uygulama `AppIntentTimelineProvider`'ın async metotlarını kullanır.
struct FavoriteHatProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FavoriteHatEntry {
        .preview
    }

    func snapshot(for configuration: SelectHatIntent, in context: Context) async -> FavoriteHatEntry {
        let entry = entry(for: configuration)
        return entry.hasSnapshot || !context.isPreview ? entry : .preview
    }

    /// Tek girdi ve `.never`: hat bilgisi zamanla değişmez. Ücretler ya da
    /// favoriler değişince uygulama özeti yazıp widget'ları tazeler.
    func timeline(for configuration: SelectHatIntent, in context: Context) async -> Timeline<FavoriteHatEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .never)
    }

    private func entry(for configuration: SelectHatIntent) -> FavoriteHatEntry {
        let snapshot = AppGroup.readSnapshot()
        let favorites = snapshot?.favorites ?? []
        // Seçilen hattın bilgisi güncel özetten (ücreti değişmiş olabilir).
        let chosen = configuration.hat.flatMap { hat in snapshot?.catalog.first { $0.id == hat.id } }
        let selected = chosen ?? favorites.first
        let others = favorites.filter { $0.id != selected?.id }
        return FavoriteHatEntry(
            date: .now,
            selected: selected,
            hats: Array(((selected.map { [$0] } ?? []) + others).prefix(4)),
            hasSnapshot: snapshot != nil
        )
    }
}

// MARK: - Görünüm

struct FavoriteHatView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FavoriteHatEntry

    var body: some View {
        if family == .systemMedium {
            medium
        } else {
            small
        }
    }

    /// Küçük: tek dokunma alanı; dokununca hattın detayı.
    @ViewBuilder
    private var small: some View {
        if let hat = entry.selected {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "bus.fill")
                    .font(.headline)
                    .foregroundStyle(.tint)
                    .widgetAccentable()
                Spacer(minLength: 0)
                Text(hat.name)
                    .font(.headline)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                Text(hat.feeLabel)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color.fee(hat.feeMin))
                    .accessibilityLabel(hat.feeLabel.spokenFee)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .widgetURL(DeepLink.hat(id: hat.id).url)
        } else {
            empty
        }
    }

    /// Orta: en çok dört hat; her satır kendi hattını açar (`Link`).
    @ViewBuilder
    private var medium: some View {
        if entry.hats.isEmpty {
            empty
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("Favori hatlar", systemImage: "star.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tint)
                    .widgetAccentable()
                ForEach(entry.hats) { hat in
                    Link(destination: DeepLink.hat(id: hat.id).url) {
                        HStack(spacing: 8) {
                            Image(systemName: "bus.fill")
                                .font(.caption)
                                .foregroundStyle(.tint)
                            Text(hat.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(hat.feeLabel)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.fee(hat.feeMin))
                        }
                    }
                    .accessibilityLabel("\(hat.name), \(hat.feeLabel.spokenFee)")
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Favori hatlar", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(.tint)
                .widgetAccentable()
            Text(entry.hasSnapshot ? "Hat detayında ☆ ile favori ekle ya da widget'ı düzenleyip hat seç." : "Uygulamayı bir kez aç")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Widget

struct FavoriteHatWidget: Widget {
    static let kind = "FavoriteHatWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectHatIntent.self, provider: FavoriteHatProvider()) { entry in
            FavoriteHatView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Favori hatlar")
        .description("Seçtiğin hattın ücreti; orta boyda favori hatların.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Önizleme verisi

extension FavoriteHatEntry {
    static let preview: FavoriteHatEntry = {
        let hats = [
            WidgetSnapshot.Hat(id: "M19", name: "Buca - Bornova", feeLabel: "40–65 ₺", feeMin: 40),
            WidgetSnapshot.Hat(id: "M33", name: "Bornova - Altındağ", feeLabel: "40–60 ₺", feeMin: 40),
            WidgetSnapshot.Hat(id: "M5", name: "Pınarbaşı - Ambarlar - Eskiçamlık", feeLabel: "40–65 ₺", feeMin: 40),
        ]
        return FavoriteHatEntry(date: .now, selected: hats[0], hats: hats, hasSnapshot: true)
    }()
}

#Preview("Küçük", as: .systemSmall) {
    FavoriteHatWidget()
} timeline: {
    FavoriteHatEntry.preview
}

#Preview("Orta", as: .systemMedium) {
    FavoriteHatWidget()
} timeline: {
    FavoriteHatEntry.preview
}
