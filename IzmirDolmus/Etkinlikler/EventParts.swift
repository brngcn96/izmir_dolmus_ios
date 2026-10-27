import DolmusCore
import SwiftUI

extension EventCategory {
    /// Kartta afiş yokken gösterilen simge.
    var symbol: String {
        switch self {
        case .music: "music.note"
        case .stage: "theatermasks"
        case .other: "sparkles"
        }
    }
}

/// Tazeleme başarısızken listenin tepesindeki not: liste önbellekten geliyor.
struct OfflineNotice: View {
    let error: APIError
    let updatedAt: Date?

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(error.message)
                    .font(.figtree(.subheadline, weight: .semibold))
                if let updatedAt {
                    Text("Kaydedilmiş liste gösteriliyor (\(updatedAt.turkishRelative)).")
                        .font(.figtree(.footnote))
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.secondary)
        }
    }
}

/// Filtreye uyan etkinlik yokken.
struct EmptyEventsView: View {
    let isFiltered: Bool

    var body: some View {
        if isFiltered {
            ContentUnavailableView(
                "Bu filtreye uyan etkinlik yok",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("Filtreleri değiştirmeyi dene.")
            )
        } else {
            ContentUnavailableView(
                "Şu an gösterilecek etkinlik yok",
                systemImage: "calendar",
                description: Text("Aşağı çekerek yenileyebilirsin.")
            )
        }
    }
}

/// Arama alanının altındaki filtre düğmeleri: tür, tarih, mekan.
struct EventFilterBar: View {
    @Environment(EventsStore.self) private var store
    @State private var isPickingVenues = false

    var body: some View {
        @Bindable var store = store
        ScrollView(.horizontal) {
            // Düğmeler içeriğin üstündeki bar'da duruyor: cam (Liquid Glass) katmanı.
            GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(EventCategory.allCases, id: \.self) { kind in
                        Toggle(kind.title, systemImage: kind.symbol, isOn: $store.filter.kinds[contains: kind])
                    }
                    if !store.filter.kinds.isEmpty {
                        Button("Temizle", role: .destructive) { store.filter.kinds = [] }
                    }
                } label: {
                    FilterChip(title: kindsTitle, isActive: !store.filter.kinds.isEmpty)
                }
                Menu {
                    Picker("Tarih", selection: $store.filter.dates) {
                        ForEach(EventFilter.Dates.allCases, id: \.self) { range in
                            Text(range.title).tag(range)
                        }
                    }
                } label: {
                    FilterChip(
                        title: store.filter.dates == .all ? "Tarih" : store.filter.dates.title,
                        isActive: store.filter.dates != .all
                    )
                }
                Button {
                    isPickingVenues = true
                } label: {
                    FilterChip(title: venuesTitle, isActive: !store.filter.venues.isEmpty)
                }
            }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $isPickingVenues) {
            VenuePickerView(venues: store.venues, selection: $store.filter.venues)
                .presentationDetents([.medium, .large])
        }
    }

    private var kindsTitle: String {
        switch store.filter.kinds.count {
        case 0: "Etkinlik"
        case 1: store.filter.kinds.first!.title
        case let count: "Etkinlik (\(count))"
        }
    }

    private var venuesTitle: String {
        store.filter.venues.isEmpty ? "Mekan" : "Mekan (\(store.filter.venues.count))"
    }
}

/// Filtre düğmesinin görünümü; seçim varsa dolu.
private struct FilterChip: View {
    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
        }
        .font(.figtree(.subheadline, weight: .semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundStyle(isActive ? Color.white : Color.primary)
        .glassEffect(isActive ? .regular.tint(.accent).interactive() : .regular.interactive(), in: .capsule)
    }
}

/// Mekan seçimi: çoklu, aranabilir; mekanlar etkinlik sayısına göre sıralı.
struct VenuePickerView: View {
    let venues: [String]
    @Binding var selection: Set<String>

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(filtered, id: \.self) { venue in
                Button {
                    if selection.contains(venue) {
                        selection.remove(venue)
                    } else {
                        selection.insert(venue)
                    }
                } label: {
                    HStack {
                        Text(venue)
                            .foregroundStyle(Color.primary)
                        Spacer()
                        if selection.contains(venue) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.accent)
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Mekan ara")
            .navigationTitle("Mekan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Temizle") { selection = [] }
                        .disabled(selection.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { dismiss() }
                }
            }
        }
    }

    private var filtered: [String] {
        let needle = trNorm(query)
        return needle.isEmpty ? venues : venues.filter { trNorm($0).contains(needle) }
    }
}

extension Set {
    /// Bir elemanın kümede olup olmamasını `Toggle`'a bağlamak için:
    /// `$filter.kinds[contains: .music]`.
    subscript(contains element: Element) -> Bool {
        get { contains(element) }
        set {
            if newValue { insert(element) } else { remove(element) }
        }
    }
}
