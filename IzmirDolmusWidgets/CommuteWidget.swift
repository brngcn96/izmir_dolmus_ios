import AppIntents
import DolmusCore
import SwiftUI
import WidgetKit

// MARK: - Girdi

/// Zaman çizelgesindeki bir an: o anda hangi yön ve hangi özet gösterilecek.
struct CommuteEntry: TimelineEntry {
    let date: Date
    let direction: CommuteDirection
    /// `nil`: uygulama henüz özet yazmadı (hiç açılmadı ya da App Group yok).
    let snapshot: WidgetSnapshot?

    var commute: WidgetSnapshot.Commute? {
        snapshot?.commute(direction)
    }
}

// MARK: - Sağlayıcı (SW.5)

/// WidgetKit'in "ne zaman ne göstereyim?" sorularını yanıtlar. Uygulama o an
/// çalışmıyor olabilir; veri yalnızca ortak klasördeki özetten okunur.
struct CommuteProvider: TimelineProvider {
    /// İlk çizimde, veri gelmeden: sistem bunu gri çubuklarla (redacted) gösterir.
    func placeholder(in context: Context) -> CommuteEntry {
        CommuteEntry(date: .now, direction: .toHome, snapshot: .preview)
    }

    /// Widget galerisindeki önizleme ve geçici durumlar için tek bir girdi.
    func getSnapshot(in context: Context, completion: @escaping @Sendable (CommuteEntry) -> Void) {
        let snapshot = AppGroup.readSnapshot() ?? (context.isPreview ? .preview : nil)
        let direction = CommuteOverride.direction(at: .now, override: AppGroup.commuteOverride)
        completion(CommuteEntry(date: .now, direction: direction, snapshot: snapshot))
    }

    /// Zaman çizelgesi: şimdi ve sıradaki yön değişiminde (04:00 ya da 14:00) birer
    /// girdi. `.atEnd`: son girdinin saati gelince WidgetKit yeni çizelge ister.
    /// ⇄ ile elle seçilen yön varsa o, süresi dolana kadar saatin önüne geçer.
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<CommuteEntry>) -> Void) {
        let snapshot = AppGroup.readSnapshot()
        let override = AppGroup.commuteOverride
        let now = Date.now
        let next = CommuteDirection.nextSwitch(after: now)
        let entries = [now, next].map { date in
            CommuteEntry(date: date, direction: CommuteOverride.direction(at: date, override: override), snapshot: snapshot)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Görünüm (SW.6)

struct CommuteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CommuteEntry

    var body: some View {
        Group {
            if let commute = entry.commute {
                switch family {
                case .accessoryInline:
                    Text("\(title) ~\(commute.recommended.minutes) dk · \(commute.recommended.feeLabel)")
                        .accessibilityLabel("\(title) yaklaşık \(commute.recommended.minutes) dakika, \(commute.recommended.feeLabel.spokenFee)")
                case .accessoryRectangular:
                    rectangular(commute)
                case .systemMedium:
                    medium(commute)
                default:
                    small(commute)
                }
            } else {
                empty
            }
        }
        // Dokununca uygulama bu adresle açılır; RootView adresi Router'a çevirir.
        .widgetURL(link.url)
    }

    /// Dokununca açılacak yer: tarif varsa haritada tarif; Ev ya da İş eksikse
    /// Ayarlar; rota yoksa "Nereden → Nereye".
    private var link: DeepLink {
        guard let snapshot = entry.snapshot else { return .tripPlanner }
        if entry.commute != nil { return .commute(entry.direction) }
        return snapshot.hasHome && snapshot.hasWork ? .tripPlanner : .settings
    }

    private var title: String {
        entry.direction == .toWork ? "İşe" : "Eve"
    }

    private var symbol: String {
        entry.direction == .toWork ? "briefcase.fill" : "house.fill"
    }

    // Küçük: başlık, büyük süre, aktarma, ücret, adım simgeleri.
    private func small(_ commute: WidgetSnapshot.Commute) -> some View {
        let option = commute.recommended
        return VStack(alignment: .leading, spacing: 2) {
            header
            Spacer(minLength: 0)
            Text("~\(option.minutes) dk")
                .font(.system(.title, design: .rounded, weight: .heavy))
                .minimumScaleFactor(0.7)
                .accessibilityLabel("yaklaşık \(option.minutes) dakika")
            Text(transfersText(option))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(option.feeLabel)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.fee(option.feeMin))
                .accessibilityLabel(option.feeLabel.spokenFee)
            StepIcons(steps: option.steps)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // Orta: solda süre ve ücret, sağda adımlar ve başka seçenek.
    private func medium(_ commute: WidgetSnapshot.Commute) -> some View {
        let option = commute.recommended
        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                header
                Spacer(minLength: 0)
                Text("~\(option.minutes) dk")
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .accessibilityLabel("yaklaşık \(option.minutes) dakika")
                Text(transfersText(option))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(option.feeLabel)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.fee(option.feeMin))
                    .accessibilityLabel(option.feeLabel.spokenFee)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("\(commute.fromLabel) → \(commute.toLabel)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                ForEach(Array(option.steps.enumerated()), id: \.offset) { _, step in
                    StepRow(step: step)
                }
                Spacer(minLength: 0)
                if commute.options.count > 1 {
                    let other = commute.options[1]
                    Text("Başka: ~\(other.minutes) dk · \(transfersText(other))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Başka seçenek: yaklaşık \(other.minutes) dakika, \(transfersText(other))")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // Kilit ekranı: üç satır, sistemin tek renkli (vibrant) görünümünde.
    private func rectangular(_ commute: WidgetSnapshot.Commute) -> some View {
        let option = commute.recommended
        let rides = option.steps.compactMap { step -> String? in
            if case .ride(_, let name) = step { name } else { nil }
        }
        return VStack(alignment: .leading, spacing: 1) {
            Label("\(title) ~\(option.minutes) dk", systemImage: symbol)
                .font(.headline)
                .widgetAccentable()
                .accessibilityLabel("\(title) yaklaşık \(option.minutes) dakika")
            Text(rides.joined(separator: " › "))
                .font(.caption)
                .lineLimit(1)
            Text("\(transfersText(option)) · \(option.feeLabel)")
                .font(.caption)
                .accessibilityLabel("\(transfersText(option)), \(option.feeLabel.spokenFee)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Tarif yoksa neden yok ve ne yapılmalı.
    private var empty: some View {
        let message: String
        if let snapshot = entry.snapshot {
            message = snapshot.hasHome && snapshot.hasWork ? "Dolmuşla rota bulunamadı" : "Ev ve İş adresini ekle"
        } else {
            message = "Uygulamayı bir kez aç"
        }
        return VStack(alignment: .leading, spacing: 4) {
            header
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Başlık ve ⇄ düğmesi. Düğme uygulamayı açmaz: intent eklentide çalışır,
    /// ardından widget yeni yönle çizilir.
    private var header: some View {
        HStack(spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(.tint)
                .widgetAccentable()
            Spacer(minLength: 0)
            Button(intent: ToggleCommuteDirectionIntent()) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .background(.fill.secondary, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Yönü değiştir")
        }
    }

    private func transfersText(_ option: WidgetSnapshot.Option) -> String {
        option.transfers == 0 ? "aktarmasız" : "\(option.transfers) aktarma"
    }
}

/// Adımlar simge olarak: yürü › dolmuş › yürü.
private struct StepIcons: View {
    let steps: [WidgetSnapshot.Step]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                if index > 0 {
                    Image(systemName: "chevron.compact.right")
                        .foregroundStyle(.tertiary)
                }
                switch step {
                case .walk: Image(systemName: "figure.walk")
                case .ride: Image(systemName: "bus.fill").foregroundStyle(.tint)
                }
            }
        }
        .font(.caption)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
    }

    /// "yürü, Buca - Bornova dolmuşu, yürü".
    private var spokenLabel: String {
        steps.map { step in
            switch step {
            case .walk: "yürü"
            case .ride(_, let name): "\(name) dolmuşu"
            }
        }
        .joined(separator: ", ")
    }
}

/// Orta boyda bir adım satırı.
private struct StepRow: View {
    let step: WidgetSnapshot.Step

    var body: some View {
        switch step {
        case .walk(let meters):
            Label("\(meters) m yürü", systemImage: "figure.walk")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(meters) metre yürü")
        case .ride(_, let name):
            Label(name, systemImage: "bus.fill")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
    }
}

// MARK: - Widget (SW.7)

struct CommuteWidget: Widget {
    /// Widget'ın türü; uygulama `reloadTimelines(ofKind:)` ile bunu tazeleyebilir.
    static let kind = "CommuteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CommuteProvider()) { entry in
            CommuteWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Eve / İşe")
        .description("Ev ile İş arasındaki önerilen dolmuş tarifi; yön saate göre değişir.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Önizleme verisi

extension WidgetSnapshot {
    /// Önizleme ve yer tutucu için örnek özet.
    static let preview = WidgetSnapshot(
        createdAt: .now,
        toWork: Commute(fromLabel: "Bornova Metro", toLabel: "Şirinyer", options: [
            Option(minutes: 42, transfers: 0, feeLabel: "40–65 ₺", feeMin: 40,
                   steps: [.walk(meters: 90), .ride(hatID: "M19", hatName: "Buca - Bornova"), .walk(meters: 334)]),
            Option(minutes: 47, transfers: 1, feeLabel: "80–125 ₺", feeMin: 80,
                   steps: [.walk(meters: 52), .ride(hatID: "M33", hatName: "Bornova - Altındağ"), .walk(meters: 1),
                           .ride(hatID: "M5", hatName: "Pınarbaşı - Ambarlar"), .walk(meters: 56)]),
        ]),
        toHome: Commute(fromLabel: "Şirinyer", toLabel: "Bornova Metro", options: [
            Option(minutes: 40, transfers: 0, feeLabel: "40–65 ₺", feeMin: 40,
                   steps: [.walk(meters: 287), .ride(hatID: "M19", hatName: "Buca - Bornova"), .walk(meters: 16)]),
        ]),
        hasHome: true,
        hasWork: true,
        favorites: [],
        catalog: []
    )
}

#Preview("Küçük", as: .systemSmall) {
    CommuteWidget()
} timeline: {
    CommuteEntry(date: .now, direction: .toWork, snapshot: .preview)
    CommuteEntry(date: .now, direction: .toHome, snapshot: .preview)
    CommuteEntry(date: .now, direction: .toHome, snapshot: nil)
}

#Preview("Orta", as: .systemMedium) {
    CommuteWidget()
} timeline: {
    CommuteEntry(date: .now, direction: .toWork, snapshot: .preview)
}

#Preview("Kilit ekranı", as: .accessoryRectangular) {
    CommuteWidget()
} timeline: {
    CommuteEntry(date: .now, direction: .toHome, snapshot: .preview)
}
