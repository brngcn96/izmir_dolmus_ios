import DolmusCore
import SwiftUI

/// "Önemli Noktalar": tür seç, harita merkezine yakın yerleri gör, birini seçince
/// yakınından geçen hatlar açılır (Flutter'daki kategori sayfası).
struct CategorySheet: View {
    let center: Coordinate
    let onPick: (PlacePoint) -> Void

    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    struct Category: Hashable {
        let title: String
        let symbol: String
        let types: Set<String>
    }

    static let categories: [Category] = [
        Category(title: "Hastaneler", symbol: "cross.case.fill", types: ["hastane"]),
        Category(title: "Üniversiteler", symbol: "graduationcap.fill", types: ["universite"]),
        Category(title: "AVM'ler", symbol: "bag.fill", types: ["avm"]),
        Category(title: "Metro · İZBAN · Tramvay", symbol: "tram.fill", types: ["metro", "izban", "tramvay"]),
        Category(title: "Terminaller", symbol: "bus.fill", types: ["otogar"]),
        Category(title: "İskeleler", symbol: "ferry.fill", types: ["iskele"]),
        Category(title: "Okullar", symbol: "book.fill", types: ["okul"]),
        Category(title: "Parklar", symbol: "tree.fill", types: ["park"]),
        Category(title: "Müzeler", symbol: "building.columns", types: ["muze", "turistik"]),
        Category(title: "Stadyum & Spor", symbol: "sportscourt.fill", types: ["stadyum", "spor"]),
        Category(title: "Pazarlar", symbol: "basket.fill", types: ["pazar"]),
        Category(title: "Eczaneler", symbol: "pills.fill", types: ["eczane"]),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                // Erişilebilirlik boyutlarında kutular genişler, adlar kesilmez.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 160 : 104), spacing: 12)], spacing: 12) {
                    ForEach(Self.categories, id: \.self) { category in
                        NavigationLink(value: category) {
                            VStack(spacing: 8) {
                                Image(systemName: category.symbol)
                                    .font(.title2)
                                    .foregroundStyle(.accent)
                                Text(category.title)
                                    .font(.figtree(.footnote, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(typeSize.isAccessibilitySize ? nil : 3)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.surface, in: .rect(cornerRadius: Theme.Radius.card))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color.canvas)
            .navigationTitle("Önemli Noktalar")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Category.self) { category in
                CategoryPlacesView(category: category, center: center, data: store.data) { place in
                    onPick(place)
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    /// Flutter'daki gibi: 1 km altı metre, üstü bir ondalıklı km.
    static func distanceLabel(_ meters: Double) -> String {
        meters >= 1000
            ? "\((meters / 1000).formatted(.number.precision(.fractionLength(1)).locale(.turkish))) km"
            : "\(Int(meters.rounded())) m"
    }
}

/// Bir türün yerleri, merkeze yakından uzağa. Liste bir kez ve ana aktörün dışında
/// hesaplanır: 34 bin yerde tarama (release'de 5–15 ms) önceden her çizimde ana
/// thread'de, açılışta birkaç kez yapılıyordu.
private struct CategoryPlacesView: View {
    let category: CategorySheet.Category
    let center: Coordinate
    let data: DolmusData
    let onPick: (PlacePoint) -> Void

    @State private var places: [PlacePoint]?

    var body: some View {
        List(places ?? [], id: \.self) { place in
            let distance = CategorySheet.distanceLabel(center.meters(to: place.coordinate))
            Button {
                onPick(place)
            } label: {
                HStack {
                    Label(place.label, systemImage: category.symbol)
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Text(distance)
                        .font(.figtree(.footnote))
                        .foregroundStyle(.textSecondary)
                        .monospacedDigit()
                }
            }
            .accessibilityLabel("\(place.label), \(distance.spokenDistance)")
        }
        .overlay {
            if places == nil {
                ProgressView()
            } else if places?.isEmpty == true {
                ContentUnavailableView("Bu türde kayıtlı yer bulunamadı", systemImage: category.symbol)
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            places = await Self.places(category.types, near: center, in: data)
        }
    }

    @concurrent
    private static func places(_ types: Set<String>, near center: Coordinate, in data: DolmusData) async -> [PlacePoint] {
        data.placesInCategory(types, near: center)
    }
}

/// "Haritada arayın": yer adı yaz, seç; son seçilenler en üstte.
struct MapSearchSheet: View {
    let near: Coordinate
    let onPick: (PlacePoint) -> Void

    @Environment(DataStore.self) private var store
    @Environment(UserStore.self) private var user
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        let results = query.count >= 2 ? store.data.placeMatches(query, limit: 25, near: near) : []
        NavigationStack {
            List {
                if query.count < 2 {
                    if !user.recentPlaces.isEmpty {
                        Section("Son aramalar") {
                            ForEach(user.recentPlaces, id: \.self) { place in
                                row(place, symbol: "clock.arrow.circlepath")
                            }
                        }
                    } else {
                        Text("Mahalle, cadde, durak ya da önemli bir yer adı yaz.")
                            .foregroundStyle(.textSecondary)
                    }
                } else {
                    ForEach(results, id: \.self) { place in
                        row(place, symbol: PoiStyle(type: DolmusData.placeKind(of: place.label)).symbol)
                    }
                }
            }
            .overlay {
                if query.count >= 2 && results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Haritada ara")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Mahalle, cadde, durak…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
    }

    private func row(_ place: PlacePoint, symbol: String) -> some View {
        Button {
            user.addRecent(place)
            onPick(place)
            dismiss()
        } label: {
            Label(place.label, systemImage: symbol)
                .foregroundStyle(Color.primary)
        }
    }
}
